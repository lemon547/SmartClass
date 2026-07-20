import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_class/services/ai_class_context.dart';
import 'package:smart_class/theme/mascot_assets.dart';

/// DeepSeek Chat Completions（OpenAI 兼容）。
class DeepSeekAiService {
  DeepSeekAiService({
    required this.apiKey,
    this.model = modelFlash,
    this.thinkingEnabled = false,
    this.maxTokens = 900,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const baseUrl = 'https://api.deepseek.com';
  static const modelFlash = 'deepseek-v4-flash';
  static const modelPro = 'deepseek-v4-pro';

  final String apiKey;
  final String model;
  /// 思考模式会多扣大量输出 token；体验档默认关闭。
  final bool thinkingEnabled;
  final int maxTokens;
  final http.Client _client;

  bool get hasKey => apiKey.trim().isNotEmpty;

  Future<String> chat({
    required String system,
    required String user,
    double temperature = 0.6,
    bool jsonObject = false,
  }) async {
    return chatMessages(
      messages: [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      temperature: temperature,
      jsonObject: jsonObject,
    );
  }

  /// 多轮对话（含 system / user / assistant）。
  Future<String> chatMessages({
    required List<Map<String, String>> messages,
    double temperature = 0.6,
    bool jsonObject = false,
  }) async {
    if (!hasKey) {
      throw const DeepSeekAiException('尚未配置 DeepSeek API Key');
    }

    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'max_tokens': maxTokens,
      'thinking': {
        'type': thinkingEnabled ? 'enabled' : 'disabled',
      },
    };
    // 思考模式下 temperature 无效；非思考时才传，便于稳定短答。
    if (!thinkingEnabled) {
      body['temperature'] = temperature;
    }
    // DeepSeek JSON Output：保证返回合法 JSON（仍须在 prompt 里写 json + 示例）。
    if (jsonObject) {
      body['response_format'] = {'type': 'json_object'};
    }

    final res = await _client.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${apiKey.trim()}',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DeepSeekAiException(_friendlyError(res.statusCode, res.body));
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw const DeepSeekAiException('AI 返回格式异常');
    }
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const DeepSeekAiException('AI 未返回内容');
    }
    final message = choices.first['message'];
    final content = message is Map ? message['content']?.toString() : null;
    final text = content?.trim() ?? '';
    if (text.isEmpty) {
      throw const DeepSeekAiException('AI 返回为空');
    }
    return text;
  }

  /// 是否像在问本班数据（成绩/课表/学生等）——是则走「目录选型→按需加载」。
  static bool looksLikeClassDataQuestion(String question) {
    final q = question.trim();
    if (q.isEmpty) return false;
    const keys = [
      '课表',
      '课程',
      '有哪些课',
      '今天有',
      '这周',
      '本周',
      '成绩',
      '分数',
      '考试',
      '月考',
      '期中',
      '期末',
      '总分',
      '进步',
      '退步',
      '排名',
      '积分',
      '考勤',
      '请假',
      '迟到',
      '缺勤',
      '学生',
      '谁',
      '哪位',
      '哪个同学',
      '本班',
      '班级',
      '花名册',
      '学号',
      '语文',
      '数学',
      '英语',
      '物理',
      '化学',
      '生物',
      '历史',
      '地理',
      '政治',
      '待办',
      '要做',
      '提醒',
      '加减分',
      '积分规则',
      '加分规则',
      '扣分规则',
      '今天要干',
      '留痕',
      '家访',
      '家长',
      '家长会',
      '班会',
      '主题班会',
      '班会课',
      '解读',
      '分析这次',
      '分析最近',
    ];
    for (final k in keys) {
      if (q.contains(k)) return true;
    }
    return false;
  }

  /// 轻量选型：只看数据包目录，输出 JSON（类似 Skill 先读 description 再决定加载）。
  Future<AiPackSelectResult> selectClassDataPacks({
    required String question,
    required String catalog,
  }) async {
    const system = '''
你是班主任助手的数据路由。根据用户问题，从「可用数据包」目录中选择最少必要的包。
规则：
1. 只输出一行 JSON，不要解释、不要 markdown。
2. 格式：{"packs":["exam_brief","work_logs"],"examId":"..."}
3. packs 取值只能是目录里的 id；最多 6 个；不需要班级数据时必须输出 {"packs":[]}。
4. 选了 exam_brief 时必须填目录里的精确 examId；不确定就不要选 exam_brief，改选 grades_overview。
5. 家长会/班会：优先 exam_brief + work_logs；普通成绩问答用 grades_overview。
6. 整理/记下待办：选 todos；设计加减分规则：选 points；请假选 leave；座位选 seating；班费选 funds。
7. 闲聊或与本班无关：{"packs":[]}
''';
    final user = '''
===== 数据包目录 =====
$catalog
===== 目录结束 =====

用户问题：$question
''';
    final raw = await chat(
      system: system,
      user: user,
      temperature: 0.1,
    );
    return parsePackSelectionJson(raw);
  }

  /// 解析选型 JSON。解析失败返回 [AiPackSelectResult.invalid]，勿与空 packs 混淆。
  static AiPackSelectResult parsePackSelectionJson(String raw) {
    try {
      final t = raw.trim();
      final start = t.indexOf('{');
      final end = t.lastIndexOf('}');
      if (start < 0 || end <= start) return AiPackSelectResult.invalid();
      final decoded = jsonDecode(t.substring(start, end + 1));
      if (decoded is! Map) return AiPackSelectResult.invalid();
      if (!decoded.containsKey('packs')) return AiPackSelectResult.invalid();

      final packs = <AiDataPackId>[];
      final rawPacks = decoded['packs'];
      if (rawPacks is! List) return AiPackSelectResult.invalid();
      for (final item in rawPacks) {
        final id = AiDataPackIdX.tryParse(item.toString());
        if (id != null && !packs.contains(id)) packs.add(id);
      }
      final examId = decoded['examId']?.toString().trim();
      return AiPackSelectResult.ok(
        AiPackSelection(
          packs: packs.take(AiClassContext.maxPacks).toList(),
          examId: (examId == null || examId.isEmpty) ? null : examId,
        ),
      );
    } catch (_) {
      return AiPackSelectResult.invalid();
    }
  }

  /// 智能问答：需要本班数据才塞快照，闲聊走短提示。
  Future<String> askSmart({
    required String question,
    required List<Map<String, String>> history,
    String? classDataSnapshot,
    bool forceClassData = false,
    String assistantName = MascotAssets.assistantName,
    String assistantPersona = MascotAssets.assistantPersona,
  }) {
    final useClass = forceClassData ||
        (classDataSnapshot != null &&
            classDataSnapshot.isNotEmpty &&
            looksLikeClassDataQuestion(question));
    if (useClass) {
      return askClassAssistant(
        classDataSnapshot: classDataSnapshot ?? '',
        history: history,
        question: question,
        assistantName: assistantName,
        assistantPersona: assistantPersona,
      );
    }
    return askGeneralChat(
      history: history,
      question: question,
      assistantName: assistantName,
      assistantPersona: assistantPersona,
    );
  }

  /// 班主任数据助手：结合本机班级快照回答（会消耗较多 token）。
  Future<String> askClassAssistant({
    required String classDataSnapshot,
    required List<Map<String, String>> history,
    required String question,
    String assistantName = MascotAssets.assistantName,
    String assistantPersona = MascotAssets.assistantPersona,
  }) {
    final system = '''
你是「Smart Class」里的班级助手「$assistantName」。性格：$assistantPersona。
用亲切、简洁的中文回答班主任的问题；自称用「$assistantName」或「我」，不要自称其他固定动漫角色名。
你只能根据下方「本机班级数据快照」作答，不要编造快照中没有的学生、分数或课程。
若数据不足，明确说缺什么（例如尚未录入某次考试或缺少各科分数）。
可以做汇总、对比、进步分析、本周课表查询、积分/考勤提醒等。
一般回答尽量短小好读，必要时用 Markdown 分点（标题、加粗、列表均可）；不要用大段代码块包住整篇回复。
若用户要求生成「家长会/班会」稿，可分点写完整提纲（主题、学情、典型、建议、流程），仍严禁编造快照没有的数据；缺数据处写「待补充」即可。

$_actionProposalInstructions

===== 本机班级数据快照 =====
$classDataSnapshot
===== 快照结束 =====
''';
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
      ...history,
      {'role': 'user', 'content': question},
    ];
    return chatMessages(messages: messages, temperature: 0.35);
  }

  /// 普通闲聊：不带班级数据，系统提示很短，省 token。
  Future<String> askGeneralChat({
    required List<Map<String, String>> history,
    required String question,
    String assistantName = MascotAssets.assistantName,
    String assistantPersona = MascotAssets.assistantPersona,
  }) {
    final system = '''
你是「Smart Class」里的班级助手「$assistantName」。性格：$assistantPersona。
用亲切、简洁的中文闲聊或答疑；自称「$assistantName」或「我」，不要自称其他固定动漫角色名。
当前看不到本班学生/成绩/课表；若对方在问具体学生数据，请温柔提示可以说「课表/成绩/积分/谁」等关键词，我会自动查本班。
回答尽量短、好读；可用简单 Markdown（加粗、列表），不要把整段包进代码块。

$_actionProposalInstructions
''';
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
      ...history,
      {'role': 'user', 'content': question},
    ];
    return chatMessages(messages: messages, temperature: 0.55);
  }

  /// 提案协议：只产出草稿 JSON，由 App 让用户确认后写入。
  static const _actionProposalInstructions = '''
【可写动作·仅草稿】当用户明确要「记下/整理今天待办」或「设计/导入加减分规则」时：
1. 先用简短中文说明你拟了什么（不要说已经写入）。
2. 在回复最末尾单独追加一个 JSON（不要 markdown 代码块），二选一：
   {"type":"todo_draft","items":[{"title":"催交数学作业"},{"title":"家访小明"}]}
   {"type":"point_preset_draft","items":[{"reason":"迟到","delta":-2},{"reason":"发言积极","delta":2}]}
4. 严禁声称已写入 App；严禁给学生直接加减分；delta 为整数且非 0。
5. 普通问答不要附加上述 JSON。
6. 正文里不要粘贴 JSON；JSON 只放在最末尾单独一行。
''';

  /// 润色工作留痕正文：更规范、可归档，不编造事实。
  Future<String> polishWorkLog({
    required String categoryLabel,
    required String title,
    required String content,
  }) {
    return chat(
      system: '''
你是中国中小学班主任的文书助手。请润色「工作留痕」正文。
要求：
1. 保留原意与事实，不编造未提及的人名、时间、结果
2. 语气客观、简洁、适合存档与迎检
3. 适当分点或分段，突出过程、要点、结果、后续跟进
4. 只输出润色后的正文，不要标题、不要解释、不要 markdown 代码块
''',
      user: '''
类别：$categoryLabel
标题：${title.trim().isEmpty ? '（无）' : title.trim()}
原文：
${content.trim()}
''',
      temperature: 0.4,
    );
  }

  /// 根据标题/要点扩写成可用留痕草稿。
  Future<String> expandWorkLog({
    required String categoryLabel,
    required String title,
    required String content,
  }) {
    return chat(
      system: '''
你是中国中小学班主任助手。根据类别、标题与已有要点，写一段「工作留痕」草稿。
要求：
1. 只基于给定信息合理补全表述，不虚构具体学生隐私细节
2. 包含：背景/目的、过程要点、结果、后续跟进（如信息不足可写「待补充」）
3. 语气正式、可归档；150～400 字为宜
4. 只输出正文，不要标题与解释
''',
      user: '''
类别：$categoryLabel
标题：${title.trim().isEmpty ? '（无）' : title.trim()}
已有要点：
${content.trim().isEmpty ? '（无，请按标题写通用框架，用【】标出需填写处）' : content.trim()}
''',
      temperature: 0.55,
    );
  }

  /// AI 成绩解读：给班主任看的可落地分析（基于本场考试数据）。
  Future<String> analyzeExamReport({required String examBrief}) {
    return chat(
      system: '''
你是中国中小学班主任的成绩分析助手。根据用户提供的「本场考试数据」，写一份简洁可读的成绩解读。
要求：
1. 只依据给定数据，不编造未出现的分数或学生
2. 结构建议：总体印象 → 各科亮点/薄弱 → 需关注的学生类型（可用「偏后几名」概括，语气鼓励、勿羞辱）→ 下周可执行的跟进建议（3～5 条）
3. 用中文分点，控制在约 400～700 字；不要 markdown 代码块
4. 适合直接复制到家长会/班会备课笔记
''',
      user: '本场考试数据：\n$examBrief',
      temperature: 0.4,
    );
  }

  /// 根据某次考试数据生成主题班会内容（议程+话术提纲）。
  Future<String> generateClassMeetingFromExam({
    required String examBrief,
    String? themeHint,
  }) {
    final hint = (themeHint ?? '').trim();
    return chat(
      system: '''
你是中国中小学班主任助手。根据「本场考试数据」生成一节 35～40 分钟「主题班会」可用稿。
要求：
1. 只依据给定数据，不编造事实；需点名表扬时仅用数据中的前几名；帮扶对象用「需关注同学」概括，避免当众羞辱
2. 输出结构：
   - 班会主题（一句话）
   - 目标（2～3 条）
   - 流程时间表（导入→数据反馈→小组讨论→榜样/方法→承诺与作业）
   - 教师主持要点（可直接念的短句）
   - 可选：家校沟通一句
3. 语气积极、务实；400～800 字；不要 markdown 代码块
4. 末尾加一小段「工作留痕摘要」（80～120 字），方便粘贴进台账
''',
      user: '''
${hint.isEmpty ? '' : '主题倾向（可参考）：$hint\n'}
本场考试数据：
$examBrief
''',
      temperature: 0.5,
    );
  }

  Future<bool> testConnection() async {
    final reply = await chat(
      system: '你只回复两个字：成功',
      user: '连通性测试',
      temperature: 0,
    );
    return reply.contains('成功');
  }

  /// 成绩表列映射：构建多轮对话的初始 messages（含 JSON 示例，配合 response_format）。
  List<Map<String, String>> gradeTableMappingSeedMessages({
    required String tsv,
    required String sheetName,
    List<String> knownStudentNames = const [],
    List<String> preferredSubjects = const [],
  }) {
    final namesHint = knownStudentNames.isEmpty
        ? '（未提供）'
        : knownStudentNames.take(80).join('、');
    final subjectsHint = preferredSubjects.isEmpty
        ? '（未指定，请用表头常见中文科目名，如语文、数学、英语）'
        : preferredSubjects.join('、');

    return [
      {
        'role': 'system',
        'content': '''
你是中小学成绩表结构识别器。用户给你带行号的 TSV（列从 0 起算；行号 R0、R1…）。
你必须只输出一个合法 json 对象（不要 markdown），字段如下：

EXAMPLE JSON OUTPUT:
{
  "examTitle": "",
  "examDate": "",
  "category": "",
  "headerRowIndex": 0,
  "nameColumn": 0,
  "studentNoColumn": null,
  "remarkColumn": null,
  "subjectColumns": { "语文": 2, "数学": 3 },
  "nameSamples": ["张三", "李四", "王五"],
  "sourceLabels": { "name": "姓名", "语文": "语文" },
  "notes": ""
}

规则：
1. 按表头文字 + 下方数据样例推断列含义；列名不必标准
2. subjectColumns 的 key 用规范科目名；有 preferredSubjects 时尽量对齐
3. 忽略总分、合计、平均分、班级、等第；班级排名可忽略（App 会重算）
3b. 若表头有「折算排名/赋分排名」「年级排名/校级排名/位次」或「语文排名」等列，不要放进 subjectColumns（本地会单独读取这些排名列）
4. 不要编造不存在的列
5. nameColumn 必须指向学生姓名列（每人不同的人名）。场次/类别/考试类型列只能用于推断 category，严禁作为 nameColumn
6. 若提供了本班已知学生名单，nameColumn 必须选与名单重合最多的那一列
7. nameSamples 必须从 nameColumn 原样抄写 3~5 个单元格，禁止编造
''',
      },
      {
        'role': 'user',
        'content': '''
工作表名：$sheetName
本班已知学生（供参考）：$namesHint
希望对齐的科目：$subjectsHint
请输出成绩表列映射 json。

表格 TSV：
$tsv
''',
      },
    ];
  }

  /// 识别任意成绩表的列结构（单轮；多轮纠错请用 [chatMessages] + [gradeTableMappingSeedMessages]）。
  Future<Map<String, dynamic>> inferGradeTableMappingJson({
    required String tsv,
    required String sheetName,
    List<String> knownStudentNames = const [],
    List<String> preferredSubjects = const [],
  }) async {
    final messages = gradeTableMappingSeedMessages(
      tsv: tsv,
      sheetName: sheetName,
      knownStudentNames: knownStudentNames,
      preferredSubjects: preferredSubjects,
    );
    final raw = await chatMessages(
      messages: messages,
      temperature: 0.1,
      jsonObject: true,
    );
    return decodeJsonObjectMap(raw, label: '成绩表结构');
  }

  /// 解析模型返回的 JSON 对象；失败抛 [DeepSeekAiException]。
  Map<String, dynamic> decodeJsonObjectMap(String raw, {String label = '结构'}) {
    final jsonStr = _extractJsonObject(raw);
    try {
      final data = jsonDecode(jsonStr);
      if (data is! Map<String, dynamic>) {
        throw DeepSeekAiException('AI 返回的$label不是对象');
      }
      return data;
    } catch (e) {
      if (e is DeepSeekAiException) rethrow;
      throw DeepSeekAiException('无法解析 AI $label：$e\n原文：$raw');
    }
  }

  /// 课表结构识别：初始多轮 messages（配合 json_object）。
  List<Map<String, String>> timetableMappingSeedMessages({
    required String tsv,
    required String sheetName,
    List<String> knownClassTitles = const [],
  }) {
    final classHint = knownClassTitles.isEmpty
        ? '（未提供）'
        : knownClassTitles.take(40).join('、');
    return [
      {
        'role': 'system',
        'content': '''
你是中小学课表结构识别器。用户提供带行号 TSV（列从 0 起算；行号 R0、R1…）。
你必须只输出一个合法 json 对象（不要 markdown）。

EXAMPLE JSON OUTPUT（长表 list）:
{
  "layout": "list",
  "headerRowIndex": 0,
  "weekdayColumn": 0,
  "periodColumn": 1,
  "subjectColumn": 2,
  "classColumn": 3,
  "className": "",
  "sourceLabels": { "weekday": "星期", "period": "节次", "subject": "科目" },
  "notes": ""
}

EXAMPLE JSON OUTPUT（矩阵 matrix）:
{
  "layout": "matrix",
  "headerRowIndex": 0,
  "periodColumn": 0,
  "weekdayColumns": { "1": 1, "2": 2, "3": 3, "4": 4, "5": 5 },
  "className": "高一（1）班",
  "sourceLabels": { "period": "节次", "1": "周一" },
  "notes": ""
}

规则：
1. 中国中小学最常见是 matrix；表头为星期、行为节次
2. weekdayColumns 的 key 必须是 "1"-"7"（周一=1 … 周日=7）
3. 不要编造不存在的列；拿不准的填 null / 省略
4. 忽略备课/教研等非上课内容时可在 notes 说明
''',
      },
      {
        'role': 'user',
        'content': '''
工作表名：$sheetName
本 App 已有班级（供参考）：$classHint
请输出课表列映射 json。

表格 TSV：
$tsv
''',
      },
    ];
  }

  /// 识别任意课表（长表或矩阵）的列/格结构。
  Future<Map<String, dynamic>> inferTimetableMappingJson({
    required String tsv,
    required String sheetName,
    List<String> knownClassTitles = const [],
  }) async {
    final messages = timetableMappingSeedMessages(
      tsv: tsv,
      sheetName: sheetName,
      knownClassTitles: knownClassTitles,
    );
    final raw = await chatMessages(
      messages: messages,
      temperature: 0.1,
      jsonObject: true,
    );
    return decodeJsonObjectMap(raw, label: '课表结构');
  }

  /// 学生花名册结构识别：初始多轮 messages。
  List<Map<String, String>> studentRosterMappingSeedMessages({
    required String tsv,
    required String sheetName,
  }) {
    return [
      {
        'role': 'system',
        'content': '''
你是中小学学生花名册结构识别器。用户提供带行号 TSV（列从 0 起算；行号 R0、R1…）。
你必须只输出一个合法 json 对象（不要 markdown）。

EXAMPLE JSON OUTPUT:
{
  "headerRowIndex": 0,
  "nameColumn": 0,
  "studentNoColumn": 1,
  "genderColumn": null,
  "phoneColumn": null,
  "addressColumn": null,
  "noteColumn": null,
  "groupColumn": null,
  "roleColumn": null,
  "birthdayColumn": null,
  "nameSamples": ["张三", "李四", "王五"],
  "sourceLabels": { "name": "姓名", "studentNo": "学号" },
  "notes": ""
}

规则：
1. nameColumn 必填，必须指向学生姓名列（每人不同的人名），禁止把序号/班级/组别当姓名
2. 没有的列填 null；不要编造不存在的列
3. nameSamples 必须从 nameColumn 原样抄写 3~5 个单元格
4. 忽略序号、班级、排名等无关列
''',
      },
      {
        'role': 'user',
        'content': '''
工作表名：$sheetName
请输出花名册列映射 json。

表格 TSV：
$tsv
''',
      },
    ];
  }

  /// 识别任意学生花名册 / 档案表的列结构。
  Future<Map<String, dynamic>> inferStudentRosterMappingJson({
    required String tsv,
    required String sheetName,
  }) async {
    final messages = studentRosterMappingSeedMessages(
      tsv: tsv,
      sheetName: sheetName,
    );
    final raw = await chatMessages(
      messages: messages,
      temperature: 0.1,
      jsonObject: true,
    );
    return decodeJsonObjectMap(raw, label: '花名册结构');
  }

  static String _extractJsonObject(String text) {
    var s = text.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
      s = s.replaceFirst(RegExp(r'\s*```$'), '');
      s = s.trim();
    }
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return s.substring(start, end + 1);
    }
    return s;
  }

  String _friendlyError(int code, String body) {
    String detail = body;
    try {
      final data = jsonDecode(body);
      if (data is Map && data['error'] is Map) {
        detail = data['error']['message']?.toString() ?? body;
      }
    } catch (_) {}
    if (code == 401) return 'API Key 无效或已失效，请到「我的 → AI 助手」重新填写';
    if (code == 402 || detail.contains('Insufficient')) {
      return 'DeepSeek 余额不足，请到开放平台充值';
    }
    if (code == 429) return '请求过于频繁，请稍后再试';
    return 'AI 请求失败（$code）：$detail';
  }
}

class DeepSeekAiException implements Exception {
  const DeepSeekAiException(this.message);
  final String message;

  @override
  String toString() => message;
}

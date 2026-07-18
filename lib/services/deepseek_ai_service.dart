import 'dart:convert';

import 'package:http/http.dart' as http;

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
  }) async {
    return chatMessages(
      messages: [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      temperature: temperature,
    );
  }

  /// 多轮对话（含 system / user / assistant）。
  Future<String> chatMessages({
    required List<Map<String, String>> messages,
    double temperature = 0.6,
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

  /// 是否像在问本班数据（成绩/课表/学生等）——是则带快照，否省 token。
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
      '留痕',
      '家访',
      '家长',
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

  /// 智能问答：需要本班数据才塞快照，闲聊走短提示。
  Future<String> askSmart({
    required String question,
    required List<Map<String, String>> history,
    String? classDataSnapshot,
    bool forceClassData = false,
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
      );
    }
    return askGeneralChat(history: history, question: question);
  }

  /// 班主任数据助手：结合本机班级快照回答（会消耗较多 token）。
  Future<String> askClassAssistant({
    required String classDataSnapshot,
    required List<Map<String, String>> history,
    required String question,
  }) {
    final system = '''
你是「班主任助手」里的懒羊羊机器人，用亲切、简洁的中文回答班主任的问题。
你只能根据下方「本机班级数据快照」作答，不要编造快照中没有的学生、分数或课程。
若数据不足，明确说缺什么（例如尚未录入某次考试）。
可以做汇总、对比、进步分析、本周课表查询、积分/考勤提醒等。
回答尽量短小好读，必要时用分点；一般不超过 8 行。

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
  }) {
    const system = '''
你是「班主任助手」里的懒羊羊，用亲切、简洁的中文闲聊或答疑。
当前看不到本班学生/成绩/课表；若对方在问具体学生数据，请温柔提示可以说「课表/成绩/积分/谁」等关键词，我会自动查本班。
回答尽量短、好读。
''';
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
      ...history,
      {'role': 'user', 'content': question},
    ];
    return chatMessages(messages: messages, temperature: 0.55);
  }

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

  /// 识别任意成绩表的列结构，返回可解析为映射的 JSON Map。
  Future<Map<String, dynamic>> inferGradeTableMappingJson({
    required String tsv,
    required String sheetName,
    List<String> knownStudentNames = const [],
    List<String> preferredSubjects = const [],
  }) async {
    final namesHint = knownStudentNames.isEmpty
        ? '（未提供）'
        : knownStudentNames.take(80).join('、');
    final subjectsHint = preferredSubjects.isEmpty
        ? '（未指定，请用表头常见中文科目名，如语文、数学、英语）'
        : preferredSubjects.join('、');

    final raw = await chat(
      system: '''
你是中小学成绩表结构识别器。用户给你带行号的 TSV（列从 0 起算；行号 R0、R1…）。
表头列名不固定：可能是「姓名/名字/学生姓名/学员」「学号/学籍号/考号/编号」「语/语文/Chinese」等，也可能带空格、序号前缀。
你的任务是根据表头文字 + 下方数据样例，推断每列含义。只输出一个 JSON，不要 markdown。

{
  "examTitle": "能读到则填，否则空字符串",
  "examDate": "yyyy-MM-dd 或空字符串",
  "category": "期末考/半期考/月考/周测/其他 或空字符串",
  "headerRowIndex": 表头行号 n,
  "nameColumn": 姓名列索引,
  "studentNoColumn": 学号列索引或 null,
  "remarkColumn": 备注列索引或 null,
  "subjectColumns": { "语文": 2, "数学": 3 },
  "sourceLabels": { "name": "原表头文字", "studentNo": "原表头", "语文": "原科目表头" },
  "notes": "一句说明（含你做了哪些列名映射）"
}

规则：
1. 列名不要求与标准名一致；按语义识别即可
2. subjectColumns 的 key 用规范科目名（语文/数学/英语/物理/化学/生物/政治/历史/地理/体育等）；有 preferredSubjects 时尽量对齐
3. 忽略总分、合计、平均分、排名、班级、等第、位次等非单科分列
4. 不要编造不存在的列；拿不准的列不要硬映射
5. sourceLabels 记录「标准字段/科目 → 原表头原文」，便于人工核对
''',
      user: '''
工作表名：$sheetName
本班已知学生（供参考）：$namesHint
希望对齐的科目：$subjectsHint
说明：表头列名可能完全不标准，请按语义识别。

表格 TSV：
$tsv
''',
      temperature: 0.1,
    );

    final jsonStr = _extractJsonObject(raw);
    try {
      final data = jsonDecode(jsonStr);
      if (data is! Map<String, dynamic>) {
        throw const DeepSeekAiException('AI 返回的成绩表结构不是对象');
      }
      return data;
    } catch (e) {
      if (e is DeepSeekAiException) rethrow;
      throw DeepSeekAiException('无法解析 AI 成绩表结构：$e\n原文：$raw');
    }
  }

  /// 识别任意课表（长表或矩阵）的列/格结构。
  Future<Map<String, dynamic>> inferTimetableMappingJson({
    required String tsv,
    required String sheetName,
    List<String> knownClassTitles = const [],
  }) async {
    final classHint = knownClassTitles.isEmpty
        ? '（未提供）'
        : knownClassTitles.take(40).join('、');

    final raw = await chat(
      system: '''
你是中小学课表结构识别器。用户提供带行号 TSV（列从 0 起算；行号 R0、R1…）。
表头列名不固定：可能是「星期一/周一/Mon」「第1节/一节/Period1」「课程/科目」「班级名称」等。
只输出一个 JSON，不要 markdown。

支持两种 layout：

1) "list"（长表：每行一节课）
{
  "layout": "list",
  "headerRowIndex": 0,
  "weekdayColumn": 0,
  "periodColumn": 1,
  "subjectColumn": 2,
  "classColumn": 3,
  "className": "",
  "sourceLabels": { "weekday": "原表头", "period": "原表头", "subject": "原表头", "class": "原表头" },
  "notes": ""
}

2) "matrix"（矩阵：表头为星期，行为节次，单元格为科目）
{
  "layout": "matrix",
  "headerRowIndex": 0,
  "periodColumn": 0,
  "weekdayColumns": { "1": 1, "2": 2, "3": 3, "4": 4, "5": 5 },
  "className": "高一（1）班",
  "sourceLabels": { "period": "节次原表头", "1": "周一原表头" },
  "notes": ""
}
weekdayColumns 的 key 必须是 "1"-"7"（周一=1 … 周日=7）。

规则：
1. 列名不要求标准，按语义识别；中国中小学最常见是 matrix
2. 忽略备课/教研等非上课内容时可在 notes 说明
3. 不要编造不存在的列
''',
      user: '''
工作表名：$sheetName
本 App 已有班级（供参考）：$classHint
说明：表头列名可能完全不标准，请按语义识别。

表格 TSV：
$tsv
''',
      temperature: 0.1,
    );

    final jsonStr = _extractJsonObject(raw);
    try {
      final data = jsonDecode(jsonStr);
      if (data is! Map<String, dynamic>) {
        throw const DeepSeekAiException('AI 返回的课表结构不是对象');
      }
      return data;
    } catch (e) {
      if (e is DeepSeekAiException) rethrow;
      throw DeepSeekAiException('无法解析 AI 课表结构：$e\n原文：$raw');
    }
  }

  /// 识别任意学生花名册 / 档案表的列结构。
  Future<Map<String, dynamic>> inferStudentRosterMappingJson({
    required String tsv,
    required String sheetName,
  }) async {
    final raw = await chat(
      system: '''
你是中小学学生花名册结构识别器。用户提供带行号 TSV（列从 0 起算；行号 R0、R1…）。
表头列名不固定：可能是「姓名/名字/学生姓名/学员」「学号/学籍号/考号/编号」「家长电话/手机号」「住址/家庭地址」「组别/小组」「班干部/职务」「出生日期/生日」等。
只输出一个 JSON，不要 markdown。

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
  "sourceLabels": { "name": "原表头", "studentNo": "原表头", "phone": "原表头" },
  "notes": "一句说明（含列名映射）"
}

规则：
1. 列名不必标准，按语义识别；nameColumn 必填
2. 没有的列填 null
3. 忽略序号、班级、排名等无关列
4. 不要编造不存在的列
''',
      user: '''
工作表名：$sheetName
说明：表头列名可能完全不标准，请按语义识别。

表格 TSV：
$tsv
''',
      temperature: 0.1,
    );

    final jsonStr = _extractJsonObject(raw);
    try {
      final data = jsonDecode(jsonStr);
      if (data is! Map<String, dynamic>) {
        throw const DeepSeekAiException('AI 返回的花名册结构不是对象');
      }
      return data;
    } catch (e) {
      if (e is DeepSeekAiException) rethrow;
      throw DeepSeekAiException('无法解析 AI 花名册结构：$e\n原文：$raw');
    }
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

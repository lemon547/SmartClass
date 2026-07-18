import 'package:smart_class/services/ai_action_proposal.dart';

void main() {
  final a = ParsedAiReply.parse(
    '好的，拟了2条\n'
    '{"type":"todo_draft","items":[{"title":"催作业"},{"title":"家访"}]}',
  );
  assert(a.displayText.contains('拟了'));
  assert(a.proposal is AiTodoDraftProposal);
  assert((a.proposal! as AiTodoDraftProposal).titles.length == 2);

  final b = ParsedAiReply.parse(
    '规则如下\n'
    '{"type":"point_preset_draft","items":[{"reason":"迟到","delta":-2}]}',
  );
  assert(b.proposal is AiPointPresetDraftProposal);

  final c = ParsedAiReply.parse('普通问答无提案');
  assert(c.proposal == null);

  // ignore: avoid_print
  print('ai_action_proposal ok');
}

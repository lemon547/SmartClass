import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/app.dart';
import 'package:smart_class/data/class_repository.dart';
import 'package:smart_class/providers/class_controller.dart';

void main() {
  testWidgets('SmartClass app builds', (tester) async {
    final repository = ClassRepository();
    // Skip full DB init in unit widget smoke; controller loads async.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ClassController(repository),
        child: const SmartClassApp(),
      ),
    );
    await tester.pump();
    expect(find.textContaining('班主任助手'), findsOneWidget);
  });
}

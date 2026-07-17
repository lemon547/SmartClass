import 'package:flutter/material.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 协议 / 政策阅读页
class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(title: Text(title)),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Text(
            body,
            style: TextStyle(
              fontSize: 15,
              height: 1.65,
              color: AppTheme.label,
            ),
          ),
        ),
      ),
    );
  }
}

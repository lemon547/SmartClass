import 'dart:async';

import 'package:flutter/services.dart';

class SharedFileItem {
  const SharedFileItem({required this.path, required this.name});
  final String path;
  final String name;
}

/// 接收从微信等 App「分享 / 用其他应用打开」进来的文件。
abstract final class ShareInbox {
  static const _method = MethodChannel('smart_class/share_receive');
  static const _events = EventChannel('smart_class/share_receive_events');

  static final _controller = StreamController<SharedFileItem>.broadcast();
  static final List<SharedFileItem> _unclaimed = [];
  // ignore: unused_field
  static StreamSubscription<dynamic>? _nativeSub;
  static bool _started = false;

  static Stream<SharedFileItem> get stream => _controller.stream;

  static void _emit(SharedFileItem item) {
    if (_controller.hasListener) {
      _controller.add(item);
    } else {
      _unclaimed.add(item);
    }
  }

  static StreamSubscription<SharedFileItem> subscribe(
    void Function(SharedFileItem item) onData,
  ) {
    final pending = List<SharedFileItem>.from(_unclaimed);
    _unclaimed.clear();
    for (final item in pending) {
      onData(item);
    }
    return _controller.stream.listen(onData);
  }

  static Future<void> ensureStarted() async {
    if (_started) return;
    _started = true;
    _nativeSub = _events.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final path = event['path']?.toString() ?? '';
        final name = event['name']?.toString() ?? '';
        if (path.isEmpty) return;
        _emit(
          SharedFileItem(
            path: path,
            name: name.isEmpty ? path.split('/').last : name,
          ),
        );
      }
    });
    try {
      final pending = await _method.invokeMethod<List<dynamic>>('takePending');
      for (final raw in pending ?? const []) {
        if (raw is Map) {
          final path = raw['path']?.toString() ?? '';
          final name = raw['name']?.toString() ?? '';
          if (path.isEmpty) continue;
          _emit(
            SharedFileItem(
              path: path,
              name: name.isEmpty ? path.split('/').last : name,
            ),
          );
        }
      }
    } catch (_) {}
  }

  static Future<bool> openWeChat() async {
    try {
      final ok = await _method.invokeMethod<bool>('openWeChat');
      return ok == true;
    } catch (_) {
      return false;
    }
  }
}

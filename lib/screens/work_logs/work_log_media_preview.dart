import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:smart_class/models/models.dart';
import 'package:smart_class/services/media_open.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:video_player/video_player.dart';

/// App 内预览照片 / 播放语音 / 播放视频，避免被 QQ 等劫持成「仅转发」。
class WorkLogMediaPreviewPage extends StatefulWidget {
  const WorkLogMediaPreviewPage({
    super.key,
    required this.path,
    required this.kind,
    required this.title,
  });

  final String path;
  final WorkLogMediaKind kind;
  final String title;

  static Future<void> open(
    BuildContext context, {
    required String path,
    required WorkLogMediaKind kind,
    required String title,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkLogMediaPreviewPage(
          path: path,
          kind: kind,
          title: title,
        ),
      ),
    );
  }

  @override
  State<WorkLogMediaPreviewPage> createState() =>
      _WorkLogMediaPreviewPageState();
}

class _WorkLogMediaPreviewPageState extends State<WorkLogMediaPreviewPage> {
  VideoPlayerController? _video;
  AudioPlayer? _audio;
  bool _ready = false;
  String? _error;
  bool _audioPlaying = false;
  Duration _audioPos = Duration.zero;
  Duration _audioDur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final file = File(widget.path);
    if (!await file.exists()) {
      setState(() => _error = '文件不存在');
      return;
    }
    try {
      if (widget.kind == WorkLogMediaKind.photo ||
          widget.kind == WorkLogMediaKind.file) {
        setState(() => _ready = true);
        return;
      }
      if (widget.kind == WorkLogMediaKind.video) {
        final c = VideoPlayerController.file(file);
        _video = c;
        await c.initialize();
        await c.setLooping(true);
        c.addListener(() {
          if (mounted) setState(() {});
        });
        if (!mounted) return;
        setState(() => _ready = true);
        return;
      }
      final a = AudioPlayer();
      _audio = a;
      a.onPositionChanged.listen((d) {
        if (mounted) setState(() => _audioPos = d);
      });
      a.onDurationChanged.listen((d) {
        if (mounted) setState(() => _audioDur = d);
      });
      a.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _audioPlaying = false);
      });
      await a.setSourceDeviceFile(widget.path);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '无法预览：$e');
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    _audio?.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final a = _audio;
    if (a == null) return;
    if (_audioPlaying) {
      await a.pause();
      setState(() => _audioPlaying = false);
    } else {
      await a.resume();
      setState(() => _audioPlaying = true);
    }
  }

  Future<void> _openExternal() async {
    try {
      // 走系统分享（ACTION_SEND），微信会出现；VIEW 打开通常没有微信。
      await MediaOpen.share(
        widget.path,
        subject: widget.title,
        text: '工作留痕附件：${widget.title}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法分享：$e')),
      );
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.kind == WorkLogMediaKind.photo
          ? Colors.black
          : AppTheme.bg,
      appBar: PageAppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _openExternal,
            child: const Text('微信等'),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _openExternal,
                      child: const Text('分享到微信等'),
                    ),
                  ],
                ),
              ),
            )
          : !_ready
              ? const Center(child: CircularProgressIndicator())
              : switch (widget.kind) {
                  WorkLogMediaKind.photo => Center(
                      child: InteractiveViewer(
                        child: Image.file(
                          File(widget.path),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text(
                            '图片无法显示',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  WorkLogMediaKind.video => _buildVideo(),
                  WorkLogMediaKind.audio => _buildAudio(),
                  WorkLogMediaKind.file => _buildFile(),
                },
    );
  }

  Widget _buildFile() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.file, size: 64, color: AppTheme.blue),
            const SizedBox(height: 12),
            Text(
              p.basename(widget.path),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openExternal,
              icon: const Icon(Icons.share),
              label: const Text('分享到微信等'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                try {
                  await MediaOpen.open(widget.path);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('无法打开：$e')),
                  );
                }
              },
              child: const Text('用阅读器打开'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final c = _video!;
    final ratio = c.value.aspectRatio;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: ratio <= 0 ? 16 / 9 : ratio,
              child: VideoPlayer(c),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    c.value.isPlaying ? c.pause() : c.play();
                  },
                  icon: Icon(
                    c.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 40,
                    color: AppTheme.blue,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: AppTheme.blue,
                      bufferedColor: AppTheme.separator,
                      backgroundColor: AppTheme.fill,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudio() {
    final totalMs = _audioDur.inMilliseconds <= 0 ? 1 : _audioDur.inMilliseconds;
    final posMs = _audioPos.inMilliseconds.clamp(0, totalMs);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.mic, size: 64, color: AppTheme.blue),
            const SizedBox(height: 12),
            Text(
              p.basename(widget.path),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Slider(
              value: posMs.toDouble(),
              max: totalMs.toDouble(),
              onChanged: (v) async {
                await _audio?.seek(Duration(milliseconds: v.round()));
              },
            ),
            Text('${_fmt(_audioPos)} / ${_fmt(_audioDur)}'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _toggleAudio,
              icon: Icon(_audioPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_audioPlaying ? '暂停' : '播放'),
            ),
          ],
        ),
      ),
    );
  }
}

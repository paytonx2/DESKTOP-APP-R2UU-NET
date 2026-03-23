import 'dart:async';
import 'dart:convert';
import 'dart:developer' as log;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════
//  VideoScreen
//  - Video file  → media_kit (แสดงผล) + /predict (AI)
//  - Camera      → Python/OpenCV /camera/* endpoints
// ═══════════════════════════════════════════════════════════════════
class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  // ── media_kit (video file playback) ──────────────────────
  late final Player          _player;
  late final VideoController _videoCtrl;

  // ── Mode flags ────────────────────────────────────────────
  _Mode _mode       = _Mode.none;
  String _srcLabel  = 'No source selected';

  // ── Camera (Python-side) ──────────────────────────────────
  List<_CamInfo> _cameras    = [];
  bool           _camOpen    = false;
  Uint8List?     _camFrame;          // latest raw frame from /camera/frame
  Timer?         _frameTimer;        // poll timer for raw preview

  // ── AI ────────────────────────────────────────────────────
  bool       _aiRunning   = false;
  Timer?     _aiTimer;
  Uint8List? _resultFrame;
  String     _aiStatus    = 'IDLE';
  int        _pixelCount  = 0;

  // ── Camera selector dialog state ──────────────────────────
  bool _loadingCams = false;

  @override
  void initState() {
    super.initState();
    _player    = Player();
    _videoCtrl = VideoController(_player);
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _aiTimer?.cancel();
    _closeCamSilent();
    _player.dispose();
    super.dispose();
  }

  String get _baseUrl => context.read<AppState>().serverUrl;

  // ══════════════════════════════════════════════════════════
  //  Video file
  // ══════════════════════════════════════════════════════════
  // ── video file path ที่ Flutter เปิดอยู่ (ใช้ส่งให้ Python seek frame) ──
  String _videoPath = '';

  Future<void> _openVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.first.path == null) return;

    _stopAll();
    await _closeCamSilent();

    _videoPath = result.files.first.path!;
    await _player.open(Media(_videoPath));

    setState(() {
      _mode     = _Mode.video;
      _srcLabel = result.files.first.name;
    });
  }

  // ══════════════════════════════════════════════════════════
  //  Camera  (Python/OpenCV)
  // ══════════════════════════════════════════════════════════
  Future<void> _showCameraDialog() async {
    setState(() => _loadingCams = true);

    // ดึงรายชื่อกล้องจาก Python
    List<_CamInfo> cams = [];
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/camera/list'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        cams = (json['cameras'] as List)
            .map((c) => _CamInfo(
                  index: c['index'] as int,
                  name:  c['name']  as String,
                  w:     c['width'] as int,
                  h:     c['height'] as int,
                ))
            .toList();
      }
    } catch (_) {}

    setState(() {
      _cameras    = cams;
      _loadingCams = false;
    });

    if (!mounted) return;

    if (cams.isEmpty) {
      _snack('No cameras found. Make sure your camera is connected.');
      return;
    }

    // แสดง dialog เลือกกล้อง
    final chosen = await showDialog<_CamInfo>(
      context: context,
      builder: (_) => _CamDialog(cameras: cams),
    );
    if (chosen == null) return;
    await _openCam(chosen.index);
  }

  Future<void> _openCam(int index) async {
    _stopAll();
    await _player.stop();

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/camera/open'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'index': index}),
          )
          .timeout(const Duration(seconds: 8));

      final json = jsonDecode(res.body);
      if (json['success'] != true) {
        _snack('Cannot open camera: ${json['error']}');
        return;
      }
    } catch (e) {
      _snack('Cannot connect to server: $e');
      return;
    }

    setState(() {
      _mode      = _Mode.camera;
      _srcLabel  = 'Camera $index (Python/OpenCV)';
      _camOpen   = true;
      _camFrame  = null;
    });

    // เริ่ม poll frame preview ทุก 100ms (~10fps)
    _startFramePolling();
  }

  void _startFramePolling() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!_camOpen || !mounted) return;
      try {
        final res = await http
            .get(Uri.parse('$_baseUrl/camera/frame?quality=70'))
            .timeout(const Duration(milliseconds: 500));
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body);
          if (json['success'] == true && mounted) {
            setState(() {
              _camFrame = base64Decode(json['image'] as String);
            });
          }
        }
      } catch (_) {}
    });
  }

  // ── ปิดกล้อง (เรียกจากปุ่ม) ──────────────────────────────
  Future<void> _closeCamera() async {
    _stopAll();
    await _closeCamSilent();
    setState(() {
      _mode        = _Mode.none;
      _srcLabel    = 'No source selected';
      _resultFrame = null;
      _aiStatus    = 'IDLE';
    });
  }

  Future<void> _closeCamSilent() async {
    _frameTimer?.cancel();
    _frameTimer = null;
    if (!_camOpen) return;
    try {
      await http
          .post(Uri.parse('$_baseUrl/camera/close'))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    _camOpen  = false;
    _camFrame = null;
  }

  // ══════════════════════════════════════════════════════════
  //  AI inference loop
  // ══════════════════════════════════════════════════════════
  void _toggleAI() {
    if (_mode == _Mode.none) return;
    _aiRunning ? _stopAI() : _startAI();
  }

  void _startAI() {
    if (_mode == _Mode.video) _player.play();
    setState(() => _aiRunning = true);
    _scheduleAI();
  }

  void _stopAI() {
    _aiTimer?.cancel();
    if (_mode == _Mode.video) _player.pause();
    setState(() { _aiRunning = false; _aiStatus = 'IDLE'; });
  }

  void _scheduleAI() {
    _aiTimer = Timer(const Duration(milliseconds: 900), () async {
      await _runAI();
      if (_aiRunning && mounted) _scheduleAI();
    });
  }

  Future<void> _runAI() async {
    if (!mounted) return;
    final s = context.read<AppState>();

    if (_mode == _Mode.camera) {
      // ── Camera: Python จับ frame + inference ในคราวเดียว ──
      try {
        final res = await http.post(
          Uri.parse('$_baseUrl/camera/predict'),
          body: {
            'model_type':     s.modelType,
            'conf_threshold': s.confThreshold.toStringAsFixed(2),
            'px_threshold':   s.pxThreshold.toString(),
          },
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;
        final json = jsonDecode(res.body);
        if (json['success'] == true) {
          _handleResult(
            status:     json['status'] as String,
            pixelCount: json['pixel_count'] as int,
            imgB64:     json['image'] as String,
            source:     _srcLabel,
            modelType:  s.modelType,
          );
        }
      } catch (_) {}

    } else if (_mode == _Mode.video) {
      // ── Video: ส่ง path + position ให้ Python ดึง frame + inference ──
      try {
        // ดึง position ปัจจุบันจาก media_kit player
        final posMs = _player.state.position.inMilliseconds;

        final res = await http.post(
          Uri.parse('$_baseUrl/video/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'path':           _videoPath,
            'position_ms':    posMs,
            'model_type':     s.modelType,
            'conf_threshold': s.confThreshold,
            'px_threshold':   s.pxThreshold,
          }),
        ).timeout(const Duration(seconds: 30));

        if (!mounted) return;
        final json = jsonDecode(res.body);
        if (json['success'] == true) {
          _handleResult(
            status:     json['status']      as String,
            pixelCount: json['pixel_count'] as int,
            imgB64:     json['image']       as String,
            source:     _srcLabel,
            modelType:  s.modelType,
          );
        } else {
          log.log('video/predict error: ${json['error']}');
        }
      } catch (e) {
        log.log('video/predict exception: $e');
      }
    }
  }

  void _handleResult({
    required String status,
    required int    pixelCount,
    required String imgB64,
    required String source,
    required String modelType,
  }) {
    setState(() {
      _resultFrame = base64Decode(imgB64);
      _aiStatus    = status;
      _pixelCount  = pixelCount;
    });
    if (status == 'MISSING') {
      context.read<AppState>().addLog(InspectionLog(
        time:       DateTime.now(),
        source:     source,
        status:     status,
        pixelCount: pixelCount,
        modelType:  modelType,
      ));
    }
  }

  void _stopAll() {
    _stopAI();
    _frameTimer?.cancel();
    _frameTimer = null;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));

  // ══════════════════════════════════════════════════════════
  //  Build
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final hasSource = _mode != _Mode.none;
    return Column(children: [
      _buildHeader(hasSource),
      _buildStatusBar(),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _panel('SOURCE FEED',   _sourceWidget())),
            const SizedBox(width: 14),
            Expanded(child: _panel('AI PREDICTION', _resultWidget())),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildHeader(bool hasSource) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LIVE VIDEO', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 20,
              fontWeight: FontWeight.w700, letterSpacing: 2)),
          Text('Camera (Python/OpenCV) or video file',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
        const Spacer(),
        // Camera button — สลับระหว่าง Open/Close ตาม state
        _loadingCams
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent))
            : _mode == _Mode.camera
                // กล้องเปิดอยู่ → แสดงปุ่มปิด
                ? _HBtn(
                    icon:  Icons.videocam_off,
                    label: 'Close Camera',
                    color: AppTheme.danger,
                    onTap: _closeCamera,
                  )
                // กล้องปิดอยู่ → แสดงปุ่มเปิด
                : _HBtn(
                    icon:  Icons.videocam,
                    label: 'Open Camera',
                    color: AppTheme.accent,
                    onTap: _showCameraDialog,
                  ),
        const SizedBox(width: 8),
        _HBtn(icon: Icons.video_file, label: 'Open Video',
              color: _mode == _Mode.video ? AppTheme.success : AppTheme.accent,
              onTap: _openVideo),
        const SizedBox(width: 8),
        _HBtn(
          icon:  _aiRunning ? Icons.stop : Icons.play_arrow,
          label: _aiRunning ? 'Stop AI' : 'Run AI',
          color: _aiRunning ? AppTheme.danger : AppTheme.success,
          onTap: hasSource ? _toggleAI : null,
        ),
      ]),
    );
  }

  Widget _buildStatusBar() {
    final color = switch (_aiStatus) {
      'MISSING' => AppTheme.danger,
      'GOOD'    => AppTheme.success,
      _         => AppTheme.textMuted,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
      color: color.withOpacity(0.07),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _aiRunning ? color : AppTheme.textMuted,
            boxShadow: _aiRunning
                ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)] : [],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _aiRunning
              ? (_aiStatus == 'MISSING'
                  ? '⚠ DEFECT DETECTED: $_pixelCount px' : '✓ SYSTEM NORMAL')
              : 'STANDBY — Select source and press Run AI',
          style: TextStyle(color: _aiRunning ? color : AppTheme.textMuted,
              fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        const Spacer(),
        Text(_srcLabel,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ]),
    );
  }

  Widget _panel(String label, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border))),
          child: Row(children: [
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: AppTheme.accent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 2)),
          ]),
        ),
        Expanded(child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft:  Radius.circular(AppTheme.rMd),
            bottomRight: Radius.circular(AppTheme.rMd),
          ),
          child: child,
        )),
      ]),
    );
  }

  Widget _sourceWidget() {
    // ── Camera: แสดง frame ที่ poll มาจาก Python ─────────────
    if (_mode == _Mode.camera) {
      if (_camFrame != null) {
        return Image.memory(_camFrame!, fit: BoxFit.contain,
            gaplessPlayback: true);  // gaplessPlayback = ไม่กระพริบระหว่างเปลี่ยน frame
      }
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2),
        SizedBox(height: 12),
        Text('Connecting to camera…',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ]));
    }

    // ── Video file: media_kit player ──────────────────────────
    if (_mode == _Mode.video) {
      return Video(controller: _videoCtrl, controls: AdaptiveVideoControls);
    }

    return const _Empty(icon: Icons.videocam_off, label: 'No source selected');
  }

  Widget _resultWidget() {
    if (_resultFrame != null) {
      return Image.memory(_resultFrame!, fit: BoxFit.contain,
          gaplessPlayback: true);
    }
    return _Empty(
      icon:  Icons.psychology_outlined,
      label: _aiRunning ? 'Processing…' : 'Waiting for AI output',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Camera selector dialog
// ─────────────────────────────────────────────────────────────────────────────
class _CamDialog extends StatelessWidget {
  final List<_CamInfo> cameras;
  const _CamDialog({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.rMd),
          side: const BorderSide(color: AppTheme.border)),
      title: const Text('Select Camera',
          style: TextStyle(color: AppTheme.textPrimary,
              fontSize: 14, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: cameras.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: AppTheme.border),
          itemBuilder: (_, i) {
            final cam = cameras[i];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.videocam_outlined,
                  color: AppTheme.accent, size: 18),
              title: Text(cam.name,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 12)),
              subtitle: Text('${cam.w}×${cam.h}',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 10)),
              onTap: () => Navigator.pop(context, cam),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Models / Helpers
// ─────────────────────────────────────────────────────────────────────────────
enum _Mode { none, video, camera }

class _CamInfo {
  final int    index;
  final String name;
  final int    w, h;
  const _CamInfo({required this.index, required this.name,
                  required this.w, required this.h});
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _Empty({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 38, color: AppTheme.textMuted),
      const SizedBox(height: 10),
      Text(label, style: const TextStyle(
          color: AppTheme.textMuted, fontSize: 11)),
    ]),
  );
}

class _HBtn extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final Color         color;
  final VoidCallback? onTap;
  const _HBtn({required this.icon, required this.label,
               required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon:  Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor:         color.withOpacity(0.1),
        foregroundColor:         color,
        disabledBackgroundColor: AppTheme.bgCard,
        disabledForegroundColor: AppTheme.textMuted,
        side: BorderSide(color: color.withOpacity(onTap != null ? 0.35 : 0.12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.rSm)),
      ),
    );
  }
}
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../services/log_service.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════
class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key});
  @override
  State<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen> {
  final List<_Job> _jobs = [];

  // ── Pick files via dialog ──────────────────────────────────
  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result == null) return;
    for (final f in result.files) {
      if (f.path != null) _enqueue(f.path!, f.name);
    }
  }

  // ── Enqueue + run inference ────────────────────────────────
  void _enqueue(String path, String name) {
    final job = _Job(path: path, name: name);
    setState(() => _jobs.insert(0, job));
    _run(job);
  }

  Future<void> _run(_Job job) async {
    final s = context.read<AppState>();
    setState(() => job.state = _S.loading);

    final bytes = await File(job.path).readAsBytes();
    final result = await ApiService.predict(
      imageBytes:    bytes,
      filename:      job.name,
      modelType:     s.modelType,
      confThreshold: s.confThreshold,
      pxThreshold:   s.pxThreshold,
    );

    if (!mounted) return;
    if (result.ok) {
      setState(() {
        job.resultBytes = result.imageBytes;
        job.pixelCount  = result.pixelCount;
        job.state       = result.isMissing ? _S.missing : _S.good;
      });
      s.addLog(InspectionLog(
        time:       DateTime.now(),
        source:     job.name,
        status:     result.status,
        pixelCount: result.pixelCount,
        modelType:  s.modelType,
      ));
    } else {
      setState(() => job.state = _S.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _header(),
      Expanded(child: _jobs.isEmpty ? _dropZone() : _list()),
    ]);
  }

  // ── Header bar ────────────────────────────────────────────
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('IMAGE BATCH', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2)),
          Text('Drag & drop or select images for analysis', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
        const Spacer(),
        if (_jobs.isNotEmpty)
          TextButton.icon(
            onPressed: () => setState(() => _jobs.clear()),
            icon: const Icon(Icons.clear_all, size: 14),
            label: const Text('Clear', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
          ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _pick,
          icon:  const Icon(Icons.add_photo_alternate, size: 15),
          label: const Text('Select Images', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.bgDeep,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rSm)),
          ),
        ),
      ]),
    );
  }

  // ── Empty drop zone ───────────────────────────────────────
  Widget _dropZone() {
    return GestureDetector(
      onTap: _pick,
      child: Container(
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.rLg),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_upload_outlined, size: 60, color: AppTheme.textMuted),
            SizedBox(height: 14),
            Text('DROP IMAGES HERE', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 3)),
            SizedBox(height: 6),
            Text('or click to browse', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            SizedBox(height: 4),
            Text('JPG, PNG', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ]),
        ),
      ),
    );
  }

  // ── Job list ──────────────────────────────────────────────
  Widget _list() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _jobs.length,
      itemBuilder: (_, i) => _JobCard(job: _jobs[i]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Job model
// ═══════════════════════════════════════════════════════════════════
enum _S { waiting, loading, good, missing, error }

class _Job {
  final String path;
  final String name;
  _S       state      = _S.waiting;
  Uint8List? resultBytes;
  int        pixelCount = 0;
  _Job({required this.path, required this.name});
}

// ═══════════════════════════════════════════════════════════════════
//  Job card
// ═══════════════════════════════════════════════════════════════════
class _JobCard extends StatefulWidget {
  final _Job job;
  const _JobCard({super.key, required this.job});
  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _open = true;

  Color _border(_S s) => switch (s) {
    _S.good    => AppTheme.success.withOpacity(0.3),
    _S.missing => AppTheme.danger.withOpacity(0.4),
    _S.error   => AppTheme.warning.withOpacity(0.3),
    _          => AppTheme.border,
  };

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: Border.all(color: _border(job.state)),
      ),
      child: Column(children: [
        // Header row
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(AppTheme.rMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              _stateIcon(job.state),
              const SizedBox(width: 12),
              Expanded(child: Text(job.name,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              )),
              const SizedBox(width: 10),
              _Badge(state: job.state, px: job.pixelCount),
              const SizedBox(width: 8),
              Icon(_open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.textMuted, size: 16),
            ]),
          ),
        ),
        // Image comparison
        if (_open && (job.state == _S.good || job.state == _S.missing))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(child: _ImgPanel(label: 'ORIGINAL', child: Image.file(File(job.path), height: 220, fit: BoxFit.contain))),
              const SizedBox(width: 12),
              Expanded(child: _ImgPanel(label: 'AI RESULT',
                child: job.resultBytes != null
                    ? Image.memory(job.resultBytes!, height: 220, fit: BoxFit.contain)
                    : const SizedBox(),
              )),
            ]),
          ),
      ]),
    );
  }

  Widget _stateIcon(_S s) {
    if (s == _S.loading) {
      return const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accent));
    }
    return Icon(
      switch (s) {
        _S.good    => Icons.check_circle,
        _S.missing => Icons.warning_rounded,
        _S.error   => Icons.error_outline,
        _          => Icons.hourglass_empty,
      },
      size: 16,
      color: switch (s) {
        _S.good    => AppTheme.success,
        _S.missing => AppTheme.danger,
        _S.error   => AppTheme.warning,
        _          => AppTheme.textMuted,
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final _S state;
  final int px;
  const _Badge({required this.state, required this.px});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      _S.good    => ('✓ GOOD',              AppTheme.success),
      _S.missing => ('⚠ MISSING  $px px',  AppTheme.danger),
      _S.loading => ('Analyzing…',          AppTheme.accent),
      _S.error   => ('ERROR',               AppTheme.warning),
      _          => ('Waiting',             AppTheme.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }
}

class _ImgPanel extends StatelessWidget {
  final String label;
  final Widget child;
  const _ImgPanel({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.rSm),
        child: Container(color: AppTheme.bgDeep, child: child),
      ),
    ]);
  }
}

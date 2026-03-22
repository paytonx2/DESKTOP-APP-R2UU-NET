import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/log_service.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (_, s, __) {
      final sum  = s.summary;
      final logs = s.logs;
      return Column(children: [
        _header(context, s),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _kpiRow(sum),
            const SizedBox(height: 22),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _logTable(logs)),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: _donut(sum)),
            ]),
          ]),
        )),
      ]);
    });
  }

  // ── Header ────────────────────────────────────────────────
  Widget _header(BuildContext ctx, AppState s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DASHBOARD', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2)),
          Text('Inspection summary & analytics', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
        const Spacer(),
        TextButton.icon(
          onPressed: s.logs.isNotEmpty ? s.clearLogs : null,
          icon: const Icon(Icons.delete_outline, size: 13),
          label: const Text('Clear', style: TextStyle(fontSize: 11)),
          style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: s.logs.isNotEmpty ? () async {
            final path = await LogService.exportCSV();
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text(path != null ? '📄 Saved: $path' : '❌ Export failed'),
              backgroundColor: path != null ? AppTheme.success.withOpacity(0.85) : AppTheme.danger.withOpacity(0.85),
            ));
          } : null,
          icon:  const Icon(Icons.download_rounded, size: 14),
          label: const Text('Export CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success.withOpacity(0.12),
            foregroundColor: AppTheme.success,
            disabledBackgroundColor: AppTheme.bgCard,
            disabledForegroundColor: AppTheme.textMuted,
            side: BorderSide(color: AppTheme.success.withOpacity(s.logs.isNotEmpty ? 0.4 : 0.15)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rSm)),
          ),
        ),
      ]),
    );
  }

  // ── KPI row ───────────────────────────────────────────────
  Widget _kpiRow(Map<String, dynamic> s) {
    return Row(children: [
      Expanded(child: _KPI(label: 'TOTAL INSPECTED', value: '${s['total']}',   icon: Icons.analytics_outlined,    color: AppTheme.accent)),
      const SizedBox(width: 14),
      Expanded(child: _KPI(label: 'PASSED (GOOD)',   value: '${s['good']}',    icon: Icons.check_circle_outline,  color: AppTheme.success)),
      const SizedBox(width: 14),
      Expanded(child: _KPI(label: 'FAILED (MISSING)',value: '${s['missing']}', icon: Icons.warning_amber_outlined, color: AppTheme.danger)),
      const SizedBox(width: 14),
      Expanded(child: _KPI(label: 'PASS RATE',       value: "${s['passRate']}%", icon: Icons.percent,              color: AppTheme.warning)),
    ]);
  }

  // ── Log table ─────────────────────────────────────────────
  Widget _logTable(List<InspectionLog> logs) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        // Table header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            const Text('INSPECTION LOG', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const Spacer(),
            Text('${logs.length} records', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ]),
        ),
        Divider(height: 1, color: AppTheme.border),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.bgPanel,
          child: const Row(children: [
            Expanded(flex: 2, child: _TH('TIME')),
            Expanded(flex: 3, child: _TH('SOURCE')),
            Expanded(child: _TH('STATUS')),
            Expanded(child: _TH('PIXELS')),
            Expanded(child: _TH('MODEL')),
          ]),
        ),
        if (logs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('No inspection data yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
          )
        else
          SizedBox(
            height: 340,
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (_, i) {
                final l   = logs[logs.length - 1 - i];
                final bad = l.isMissing;
                final ts  = '${_p(l.time.hour)}:${_p(l.time.minute)}:${_p(l.time.second)}';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: bad ? AppTheme.danger.withOpacity(0.04) : Colors.transparent,
                    border: Border(bottom: BorderSide(color: AppTheme.border.withOpacity(0.4))),
                  ),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text(ts, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))),
                    Expanded(flex: 3, child: Text(l.source, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10), overflow: TextOverflow.ellipsis)),
                    Expanded(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (bad ? AppTheme.danger : AppTheme.success).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(l.status,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: bad ? AppTheme.danger : AppTheme.success, fontSize: 9, fontWeight: FontWeight.w700)),
                    )),
                    Expanded(child: Text('${l.pixelCount}', textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))),
                    Expanded(child: Text(l.modelType, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9), overflow: TextOverflow.ellipsis)),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  // ── Donut chart ───────────────────────────────────────────
  Widget _donut(Map<String, dynamic> s) {
    final total   = (s['total']   as int).toDouble();
    final good    = (s['good']    as int).toDouble();
    final missing = (s['missing'] as int).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PASS / FAIL RATIO', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 22),
        if (total == 0)
          const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('No data', style: TextStyle(color: AppTheme.textMuted)),
          ))
        else ...[
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _DonutPainter(good: good, missing: missing, total: total),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text("${s['passRate']}%",
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                const Text('PASS', style: TextStyle(color: AppTheme.textMuted, fontSize: 9, letterSpacing: 2)),
              ])),
            ),
          ),
          const SizedBox(height: 20),
          _Legend(color: AppTheme.success, label: 'Good',    value: s['good']    as int),
          const SizedBox(height: 8),
          _Legend(color: AppTheme.danger,  label: 'Missing', value: s['missing'] as int),
        ],
      ]),
    );
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

// ── KPI card ──────────────────────────────────────────────────────
class _KPI extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KPI({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Table header cell ─────────────────────────────────────────────
class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1));
}

// ── Legend row ────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  const _Legend({required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
      const Spacer(),
      Text('$value', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── Donut painter ─────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final double good, missing, total;
  const _DonutPainter({required this.good, required this.missing, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final c    = Offset(size.width / 2, size.height / 2);
    final r    = size.shortestSide / 2 - 10;
    final rect = Rect.fromCircle(center: c, radius: r);
    const sw   = 18.0;
    const pi2  = 6.283185307;
    const half = -1.5707963; // -π/2

    // Background track
    canvas.drawCircle(c, r, Paint()
      ..color     = AppTheme.border
      ..style     = PaintingStyle.stroke
      ..strokeWidth = sw);

    if (total <= 0) return;

    // Good arc
    final gAng = (good / total) * pi2;
    canvas.drawArc(rect, half, gAng, false, Paint()
      ..color       = AppTheme.success
      ..style       = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap   = StrokeCap.round);

    // Missing arc
    if (missing > 0) {
      final mAng = (missing / total) * pi2;
      canvas.drawArc(rect, half + gAng + 0.08, mAng - 0.08, false, Paint()
        ..color       = AppTheme.danger
        ..style       = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap   = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.good != good || o.missing != missing;
}

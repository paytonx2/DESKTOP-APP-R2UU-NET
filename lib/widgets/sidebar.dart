import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/log_service.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════
//  AppSidebar  (root widget)
// ═══════════════════════════════════════════════════════════════════
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 258,
      color: AppTheme.bgPanel,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SecLabel('NAVIGATION'),
                  SizedBox(height: 6),
                  _NavItem(index: 0, icon: Icons.image_outlined,   label: 'Image Batch'),
                  _NavItem(index: 1, icon: Icons.videocam_outlined, label: 'Live Video'),
                  _NavItem(index: 2, icon: Icons.bar_chart_rounded, label: 'Dashboard'),
                  SizedBox(height: 20),
                  _SecLabel('AI MODEL'),
                  SizedBox(height: 6),
                  _ModelSelector(),
                  SizedBox(height: 20),
                  _SecLabel('PARAMETERS'),
                  SizedBox(height: 10),
                  _ConfSlider(),
                  SizedBox(height: 14),
                  _PxField(),
                  SizedBox(height: 20),
                  _SecLabel('SERVER URL'),
                  SizedBox(height: 6),
                  _ServerField(),
                  SizedBox(height: 20),
                  _SecLabel('SYSTEM LOG'),
                  SizedBox(height: 6),
                  _SysLog(),
                  SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const _BottomBar(),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────
class _SecLabel extends StatelessWidget {
  final String text;
  const _SecLabel(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelSmall);
}

// ── Navigation item ───────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final int index;
  final IconData icon;
  final String label;
  const _NavItem({required this.index, required this.icon, required this.label});
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (_, s, __) {
      final active = s.tab == widget.index;
      return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit:  (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => s.setTab(widget.index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.accent.withOpacity(0.1)
                  : (_hover ? AppTheme.bgHover : Colors.transparent),
              borderRadius: BorderRadius.circular(AppTheme.rSm),
              border: Border.all(
                color: active ? AppTheme.accent.withOpacity(0.35) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 15,
                    color: active ? AppTheme.accent : AppTheme.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.label,
                    style: TextStyle(
                      color:      active ? AppTheme.accent : AppTheme.textSecond,
                      fontSize:   12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (active)
                  Container(width: 5, height: 5,
                      decoration: const BoxDecoration(
                          color: AppTheme.accent, shape: BoxShape.circle)),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ── Model selector ────────────────────────────────────────────────
class _ModelSelector extends StatelessWidget {
  const _ModelSelector();
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (_, s, __) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.rSm),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(children: [
          _ModelOpt(value: 'defect',     label: 'Pipe Staple',    sub: 'Pipe staple detection',    cur: s.modelType, onTap: () => s.setModel('defect')),
          Divider(height: 1, color: AppTheme.border),
          _ModelOpt(value: 'tank_screw', label: 'Underbody Screw', sub: 'Underbody screw detection', cur: s.modelType, onTap: () => s.setModel('tank_screw')),
        ]),
      );
    });
  }
}

class _ModelOpt extends StatefulWidget {
  final String value, label, sub, cur;
  final VoidCallback onTap;
  const _ModelOpt({required this.value, required this.label, required this.sub, required this.cur, required this.onTap});
  @override
  State<_ModelOpt> createState() => _ModelOptState();
}

class _ModelOptState extends State<_ModelOpt> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.value == widget.cur;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppTheme.accent.withOpacity(0.07) : (_h ? AppTheme.bgHover : Colors.transparent),
            borderRadius: BorderRadius.circular(AppTheme.rSm),
          ),
          child: Row(children: [
            // Radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: active ? AppTheme.accent : AppTheme.textMuted, width: 1.5),
              ),
              child: active
                  ? Center(child: Container(width: 6, height: 6,
                      decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: TextStyle(
                    color: active ? AppTheme.accent : AppTheme.textPrimary,
                    fontSize: 11, fontWeight: FontWeight.w700)),
                Text(widget.sub, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}

// ── Confidence slider ─────────────────────────────────────────────
class _ConfSlider extends StatelessWidget {
  const _ConfSlider();
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (_, s, __) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Confidence', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(s.confThreshold.toStringAsFixed(2),
                style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor:   AppTheme.accent,
            inactiveTrackColor: AppTheme.border,
            thumbColor:         AppTheme.accent,
            overlayColor:       AppTheme.accent.withOpacity(0.15),
            trackHeight:        3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(value: s.confThreshold, min: 0.10, max: 0.95, divisions: 17, onChanged: s.setConf),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
          Text('0.10', style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
          Text('0.95', style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
        ]),
      ]);
    });
  }
}

// ── Pixel threshold field ─────────────────────────────────────────
class _PxField extends StatefulWidget {
  const _PxField();
  @override
  State<_PxField> createState() => _PxFieldState();
}

class _PxFieldState extends State<_PxField> {
  final _ctrl = TextEditingController(text: '500');
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Pixel Threshold', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
      const SizedBox(height: 6),
      TextField(
        controller:  _ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true, fillColor: AppTheme.bgCard,
          suffixText: 'px',
          suffixStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.rSm), borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.rSm), borderSide: const BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.rSm), borderSide: const BorderSide(color: AppTheme.accent)),
        ),
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null && n > 0) context.read<AppState>().setPx(n);
        },
      ),
    ]);
  }
}

// ── Server URL field ──────────────────────────────────────────────
class _ServerField extends StatefulWidget {
  const _ServerField();
  @override
  State<_ServerField> createState() => _ServerFieldState();
}

class _ServerFieldState extends State<_ServerField> {
  late final TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: context.read<AppState>().serverUrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _save() {
    context.read<AppState>().setUrl(_ctrl.text);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return GestureDetector(
        onTap: () => setState(() => _editing = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.rSm),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            const Icon(Icons.dns_outlined, color: AppTheme.textMuted, size: 12),
            const SizedBox(width: 8),
            Expanded(child: Text(
              context.watch<AppState>().serverUrl,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            )),
            const Icon(Icons.edit_outlined, color: AppTheme.textMuted, size: 10),
          ]),
        ),
      );
    }
    return TextField(
      controller: _ctrl, autofocus: true,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
      onSubmitted: (_) => _save(),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true, fillColor: AppTheme.bgCard,
        hintText: 'http://127.0.0.1:7860',
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.rSm), borderSide: const BorderSide(color: AppTheme.accent)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.rSm), borderSide: const BorderSide(color: AppTheme.accent)),
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.close, size: 13, color: AppTheme.textMuted), onPressed: () => setState(() => _editing = false)),
          IconButton(icon: const Icon(Icons.check, size: 13, color: AppTheme.success),  onPressed: _save),
        ]),
      ),
    );
  }
}

// ── System log terminal ───────────────────────────────────────────
class _SysLog extends StatefulWidget {
  const _SysLog();
  @override
  State<_SysLog> createState() => _SysLogState();
}

class _SysLogState extends State<_SysLog> {
  final _scroll = ScrollController();

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (_, s, __) {
      _toBottom();
      return Container(
        height: 108,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF020810),
          borderRadius: BorderRadius.circular(AppTheme.rSm),
          border: Border.all(color: AppTheme.border),
        ),
        child: ListView.builder(
          controller: _scroll,
          itemCount: s.sysLog.length,
          itemBuilder: (_, i) {
            final line = s.sysLog[i];
            Color c = AppTheme.textMuted;
            if (line.contains('MISSING') || line.contains('❌') || line.contains('OFFLINE')) {
              c = AppTheme.danger.withOpacity(0.8);
            } else if (line.contains('✅') || line.contains('GOOD') || line.contains('ONLINE')) {
              c = AppTheme.success.withOpacity(0.75);
            } else if (line.contains('Model →') || line.contains('Server →')) {
              c = AppTheme.accent.withOpacity(0.7);
            }
            return Text(line,
              style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace', height: 1.55),
            );
          },
        ),
      );
    });
  }
}

// ── Bottom export bar ─────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
      child: Consumer<AppState>(builder: (_, s, __) {
        final count = s.logs.length;
        return Column(children: [
          Row(children: [
            const Icon(Icons.storage_outlined, color: AppTheme.textMuted, size: 11),
            const SizedBox(width: 6),
            const Text('Inspection logs', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: count > 0 ? () async {
                final path = await LogService.exportCSV();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(path != null ? '📄 Saved: $path' : '❌ Export failed'),
                    backgroundColor: path != null
                        ? AppTheme.success.withOpacity(0.85)
                        : AppTheme.danger.withOpacity(0.85),
                  ));
                }
              } : null,
              icon:  const Icon(Icons.download_rounded, size: 14),
              label: const Text('Export CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success.withOpacity(0.12),
                foregroundColor: AppTheme.success,
                disabledBackgroundColor: AppTheme.bgCard,
                disabledForegroundColor: AppTheme.textMuted,
                side: BorderSide(color: AppTheme.success.withOpacity(count > 0 ? 0.4 : 0.15)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rSm)),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

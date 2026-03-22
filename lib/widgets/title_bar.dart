import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 46,
        color: AppTheme.bgPanel,
        child: Row(
          children: [
            const SizedBox(width: 14),
            // Logo icon
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color:        AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border:       Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.radar, color: AppTheme.accent, size: 14),
            ),
            const SizedBox(width: 10),
            // Title
            RichText(
              text: const TextSpan(
                style: TextStyle(fontFamily: 'SpaceMono', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2.5),
                children: [
                  TextSpan(text: 'R2U-NET  ', style: TextStyle(color: AppTheme.accent)),
                  TextSpan(text: 'INSPECTION PRO', style: TextStyle(color: AppTheme.textSecond)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Server pill
            const _ServerPill(),
            const Spacer(),
            // Window buttons
            _WinBtn(icon: Icons.minimize_rounded, onTap: () => windowManager.minimize()),
            _WinBtn(
              icon: Icons.crop_square_rounded,
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            _WinBtn(icon: Icons.close_rounded, onTap: () => windowManager.close(), isClose: true),
          ],
        ),
      ),
    );
  }
}

// ── Server online/offline pill ────────────────────────────────────────────────
class _ServerPill extends StatelessWidget {
  const _ServerPill();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (_, s, __) {
      final color = s.isOnline ? AppTheme.success : AppTheme.danger;
      return Tooltip(
        message: s.isOnline ? 'Flask API Online' : 'Offline — tap to retry',
        child: GestureDetector(
          onTap: () => s.checkServer(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color:        color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.isChecking)
                  SizedBox(
                    width: 7, height: 7,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
                  )
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: color,
                      boxShadow: s.isOnline ? [BoxShadow(color: color.withOpacity(0.7), blurRadius: 6)] : [],
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  s.isChecking ? 'Checking…' : (s.isOnline ? 'Online' : 'Offline'),
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ── Window control button ─────────────────────────────────────────────────────
class _WinBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;
  const _WinBtn({required this.icon, required this.onTap, this.isClose = false});

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 44, height: 46,
          color: _hover
              ? (widget.isClose ? const Color(0xFFE81123) : AppTheme.bgHover)
              : Colors.transparent,
          child: Icon(
            widget.icon, size: 13,
            color: _hover && widget.isClose ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';

class AppState extends ChangeNotifier {
  // ── Settings ─────────────────────────────────────────────
  String modelType     = 'defect';
  double confThreshold = 0.35;
  int    pxThreshold   = 500;
  String serverUrl     = 'http://127.0.0.1:7860';

  // ── Server ────────────────────────────────────────────────
  bool isOnline         = false;
  bool isChecking       = false;

  // ── Navigation ────────────────────────────────────────────
  int tab = 0;   // 0=Image  1=Video  2=Dashboard

  // ── System log ────────────────────────────────────────────
  final List<String> sysLog = ['[SYSTEM] Ready.'];

  Timer? _ping;

  AppState() {
    _startPing();
  }

  void _startPing() {
    checkServer();
    _ping = Timer.periodic(const Duration(seconds: 12), (_) => checkServer(silent: true));
  }

  @override
  void dispose() {
    _ping?.cancel();
    super.dispose();
  }

  // ── Setters ───────────────────────────────────────────────
  void setTab(int v)   { tab = v; notifyListeners(); }

  void setModel(String v) {
    modelType = v;
    _log('Model → $v');
    notifyListeners();
  }

  void setConf(double v)  { confThreshold = v; notifyListeners(); }
  void setPx(int v)       { pxThreshold   = v; notifyListeners(); }

  void setUrl(String v) {
    serverUrl = v.trim();
    ApiService.baseUrl = serverUrl;
    _log('Server → $serverUrl');
    notifyListeners();
    checkServer();
  }

  // ── Server health ─────────────────────────────────────────
  Future<void> checkServer({bool silent = false}) async {
    if (!silent) { isChecking = true; notifyListeners(); }
    final online = await ApiService.healthCheck();
    if (online != isOnline) {
      isOnline = online;
      _log(online ? '✅ Server ONLINE' : '❌ Server OFFLINE');
    } else {
      isOnline = online;
    }
    isChecking = false;
    notifyListeners();
  }

  // ── Logs ──────────────────────────────────────────────────
  List<InspectionLog> get logs    => LogService.logs;
  Map<String, dynamic> get summary => LogService.summary();

  void addLog(InspectionLog l) {
    LogService.add(l);
    _log('[${l.modelType}] ${l.source} → ${l.status} (${l.pixelCount}px)');
    notifyListeners();
  }

  void clearLogs() {
    LogService.clear();
    _log('Logs cleared');
    notifyListeners();
  }

  // ── System log ────────────────────────────────────────────
  void _log(String msg) {
    final t = DateTime.now();
    final ts = '${_p(t.hour)}:${_p(t.minute)}:${_p(t.second)}';
    sysLog.add('[$ts] $msg');
    if (sysLog.length > 200) sysLog.removeAt(0);
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

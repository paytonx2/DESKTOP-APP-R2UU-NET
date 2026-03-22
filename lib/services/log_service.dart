import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class InspectionLog {
  final DateTime time;
  final String   source;
  final String   status;
  final int      pixelCount;
  final String   modelType;

  const InspectionLog({
    required this.time,
    required this.source,
    required this.status,
    required this.pixelCount,
    required this.modelType,
  });

  bool get isMissing => status == 'MISSING';
}

class LogService {
  LogService._();

  static final List<InspectionLog> _logs = [];

  static List<InspectionLog> get logs => List.unmodifiable(_logs);

  static void add(InspectionLog log) => _logs.add(log);

  static void clear() => _logs.clear();

  static Map<String, dynamic> summary() {
    final total   = _logs.length;
    final missing = _logs.where((l) => l.isMissing).length;
    final good    = total - missing;
    return {
      'total':    total,
      'missing':  missing,
      'good':     good,
      'passRate': total > 0 ? ((good / total) * 100).toStringAsFixed(1) : '0.0',
    };
  }

  /// Export logs as CSV with UTF-8 BOM (Excel-safe).
  /// Returns the saved file path, or null on failure.
  static Future<String?> exportCSV() async {
    if (_logs.isEmpty) return null;

    final buf = StringBuffer()
      ..write('\uFEFF') // BOM
      ..writeln('Timestamp,Source,Status,Pixels,Model');

    for (final l in _logs) {
      final ts =
          '${l.time.year}-${_p(l.time.month)}-${_p(l.time.day)} '
          '${_p(l.time.hour)}:${_p(l.time.minute)}:${_p(l.time.second)}';
      buf.writeln('$ts,"${l.source}",${l.status},${l.pixelCount},${l.modelType}');
    }

    try {
      Directory? dir;
      try { dir = await getDownloadsDirectory(); } catch (_) {}
      dir ??= await getApplicationDocumentsDirectory();

      final file = File(
        '${dir.path}/Inspection_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsBytes(utf8.encode(buf.toString()));
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

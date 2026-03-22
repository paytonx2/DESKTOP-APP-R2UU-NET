import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  static String baseUrl = 'http://127.0.0.1:7860';

  /// POST image to /predict. Returns [PredictResult] always (check [PredictResult.ok]).
  static Future<PredictResult> predict({
    required Uint8List imageBytes,
    required String    filename,
    required String    modelType,
    required double    confThreshold,
    required int       pxThreshold,
  }) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/predict'))
        ..files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: filename))
        ..fields['model_type']      = modelType
        ..fields['conf_threshold']  = confThreshold.toStringAsFixed(2)
        ..fields['px_threshold']    = pxThreshold.toString();

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final res      = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (json['success'] == true) {
          return PredictResult(
            ok:          true,
            status:      json['status']      as String,
            pixelCount:  json['pixel_count'] as int,
            imageBase64: json['image']       as String,
          );
        }
        return PredictResult.fail(json['error'] as String? ?? 'API error');
      }
      return PredictResult.fail('HTTP ${res.statusCode}');
    } catch (e) {
      return PredictResult.fail(e.toString());
    }
  }

  /// Returns true if the Flask server is reachable.
  /// Flask returns 405 on GET /predict (method not allowed) — server is still UP.
  static Future<bool> healthCheck() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/predict'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200 || res.statusCode == 405;
    } catch (_) {
      return false;
    }
  }
}

class PredictResult {
  final bool   ok;
  final String status;
  final int    pixelCount;
  final String imageBase64;
  final String error;

  const PredictResult({
    required this.ok,
    this.status      = '',
    this.pixelCount  = 0,
    this.imageBase64 = '',
    this.error       = '',
  });

  factory PredictResult.fail(String msg) =>
      PredictResult(ok: false, status: 'ERROR', error: msg);

  bool get isMissing => status == 'MISSING';

  Uint8List get imageBytes => base64Decode(imageBase64);
}

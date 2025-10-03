import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';

import 'provider.dart';

class OpenAIImageClient implements ImageProviderClient {
  OpenAIImageClient({required this.apiKey});

  final String apiKey;

  // curl https://api.openai.com/v1/images/generations \
  // -H "Content-Type: application/json" \
  // -H "Authorization: Bearer $OPENAI_API_KEY" \
  // -d '{
  //   "model": "gpt-image-1",
  //   "prompt": "A cute baby sea otter",
  //   "n": 1,
  //   "size": "1024x1024"
  // }'

  @override
  Future<Uint8List> generateImage({
    required String model,
    required String prompt,
    String? size,
    bool transparent = false,
    String format = 'png',
    int? seed,
    int? timeoutMs,
    Map<String, Object?> extra = const {},
  }) async {
    // OpenAI Images API v1
    final uri = Uri.parse('https://api.openai.com/v1/images/generations');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      if ((extra['openai_project'] as String?)?.isNotEmpty == true)
        'OpenAI-Project': (extra['openai_project'] as String?)!,
      if ((extra['openai_organization'] as String?)?.isNotEmpty == true)
        'OpenAI-Organization': (extra['openai_organization'] as String?)!,
    };

    final body = <String, Object?>{
      'model': model,
      'prompt': prompt,
      'size': size ?? '1024x1024',
      'n': 1,
      // Background transparency is not a direct parameter; rely on prompt text
      if (seed != null) 'seed': seed,
      if (transparent) 'background': 'transparent',
    };

    print(jsonEncode(headers));
    print(jsonEncode(body));
    final r = RetryOptions(maxAttempts: 4);
    final response = await r.retry(() async {
      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(Duration(milliseconds: timeoutMs ?? 60000));
      if (res.statusCode == 429 || res.statusCode >= 500) {
        throw http.ClientException(
          'Retryable ${res.statusCode}: ${res.body}',
          uri,
        );
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final err = _extractOpenAIError(res.body);
        throw ProviderApiException(
          provider: 'OpenAI',
          statusCode: res.statusCode,
          message: err,
          rawBody: res.body,
          url: uri,
        );
      }
      return res;
    });

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>;
    if (data.isEmpty) {
      throw StateError('OpenAI returned no image data');
    }
    // Prefer b64_json if available, else fetch via URL
    final first = data.first as Map<String, dynamic>;
    final b64 = first['b64_json'] as String?;
    if (b64 != null) {
      return base64Decode(b64);
    }
    final url = first['url'] as String?;
    if (url == null) {
      throw StateError('OpenAI response missing image bytes and url');
    }
    final imgRes = await http
        .get(Uri.parse(url))
        .timeout(Duration(milliseconds: timeoutMs ?? 60000));
    if (imgRes.statusCode < 200 || imgRes.statusCode >= 300) {
      throw ProviderApiException(
        provider: 'OpenAI',
        statusCode: imgRes.statusCode,
        message: 'Image fetch failed',
        rawBody: imgRes.body,
        url: Uri.parse(url),
      );
    }
    return imgRes.bodyBytes;
  }
}

String _extractOpenAIError(String body) {
  try {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final error = decoded['error'] as Map<String, dynamic>?;
    if (error == null) return body;
    final message = error['message'];
    final code = error['code'];
    final param = error['param'];
    return '[code=$code param=$param] $message';
  } catch (_) {
    return body;
  }
}

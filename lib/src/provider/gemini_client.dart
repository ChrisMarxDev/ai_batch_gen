import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';

import 'provider.dart';

class GeminiImageClient implements ImageProviderClient {
  GeminiImageClient({required this.apiKey});

  final String apiKey;

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
    // Gemini API for image generation
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
    final headers = {
      'Content-Type': 'application/json',
    };

    final body = <String, Object?>{
      'contents': [
        {
          'parts': [
            {
              'text': prompt,
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.4,
        'topK': 32,
        'topP': 1,
        'maxOutputTokens': 4096,
        if (seed != null) 'seed': seed,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
      ],
    };

    final r = RetryOptions(maxAttempts: 4);
    final response = await r.retry(() async {
      final res = await http
          .post(
            Uri.parse('$uri?key=$apiKey'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(Duration(milliseconds: timeoutMs ?? 60000));
      if (res.statusCode == 429 || res.statusCode >= 500) {
        throw http.ClientException(
          'Retryable ${res.statusCode}: ${res.body}',
          uri,
        );
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Gemini error ${res.statusCode}: ${res.body}');
      }
      return res;
    });

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw StateError('Gemini returned no candidates');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    if (content == null) {
      throw StateError('Gemini response missing content');
    }

    final parts = content['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw StateError('Gemini response missing parts');
    }

    final part = parts.first as Map<String, dynamic>;
    final inlineData = part['inlineData'] as Map<String, dynamic>?;
    if (inlineData == null) {
      throw StateError('Gemini response missing inlineData');
    }

    final data = inlineData['data'] as String?;
    if (data == null) {
      throw StateError('Gemini response missing data');
    }

    return base64Decode(data);
  }
}

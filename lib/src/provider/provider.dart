import 'dart:typed_data';

abstract class ImageProviderClient {
  Future<Uint8List> generateImage({
    required String model,
    required String prompt,
    String? size,
    bool transparent = false,
    String format = 'png',
    int? seed,
    int? timeoutMs,
    Map<String, Object?> extra,
  });
}

class ProviderApiException implements Exception {
  ProviderApiException({
    required this.provider,
    required this.statusCode,
    required this.message,
    required this.rawBody,
    this.url,
  });

  final String provider;
  final int statusCode;
  final String message;
  final String rawBody;
  final Uri? url;

  @override
  String toString() => '$provider error $statusCode: $message';
}

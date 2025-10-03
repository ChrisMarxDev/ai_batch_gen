import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

import '../config/config.dart';
import '../config/prompt_composer.dart';
import '../provider/gemini_client.dart';
import '../provider/openai_client.dart';
import '../provider/provider.dart';

class GenerationEngine {
  GenerationEngine({required this.logger});

  final Logger logger;

  Future<int> run(AppConfig config) async {
    final dir = Directory(config.output);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final provider = _selectProvider(config);
    logger.detail('Provider selected: ${config.model.split(':').first}');

    final pool = Pool(config.concurrency);
    final tasks = <Future<_Result>>[];

    for (final entry in config.images.entries) {
      if (config.cli.onlyKeys != null && !config.cli.onlyKeys!.contains(entry.key)) {
        continue;
      }
      if (!config.regenerateAll &&
          config.regenerateKeys.isNotEmpty &&
          !config.regenerateKeys.contains(entry.key)) {
        // Regenerate subset was requested; skip others
        continue;
      }

      tasks.add(pool.withResource(() async {
        logger.detail('Queueing generation for key=${entry.key}');
        return _generateForKey(provider, config, entry.key, entry.value);
      }));
    }

    final results = await Future.wait(tasks);
    await pool.close();

    final failed = results.where((r) => !r.ok).length;
    if (failed > 0 && !config.ignoreFailures) return ExitCode.software.code;
    return ExitCode.success.code;
  }

  ImageProviderClient _selectProvider(AppConfig config) {
    final providerName = config.model.split(':').first;
    switch (providerName) {
      case 'openai':
        return OpenAIImageClient(apiKey: config.providerKeys['openai']!);
      case 'gemini':
        return GeminiImageClient(apiKey: config.providerKeys['gemini']!);
      default:
        throw StateError('Unknown provider: $providerName');
    }
  }

  Future<_Result> _generateForKey(
    ImageProviderClient client,
    AppConfig config,
    String key,
    String imagePrompt,
  ) async {
    final prompt = PromptComposer.compose(
      textPrompt: config.textPrompt,
      jsonPrompt: config.jsonPrompt,
      imagePrompt: imagePrompt,
      transparent: config.transparent,
      negativePrompt: config.negativePrompt,
    );
    logger.detail('Composed prompt for $key (len=${prompt.length})');

    final count = config.count;
    final targetFormat = config.format;
    final basePath = p.join(config.output, key);

    // Determine indices to generate
    final bool isRegenerating =
        config.regenerateAll || config.regenerateKeys.contains(key);
    final indices = <int>[];
    if (isRegenerating || config.force) {
      for (var i = 0; i < count; i++) {
        indices.add(i);
      }
    } else {
      for (var i = 0; i < count; i++) {
        final path = _filePathForIndex(basePath, targetFormat, i);
        if (!File(path).existsSync()) {
          indices.add(i);
        }
      }
      if (indices.isEmpty) {
        logger.info(
          '${lightGreen.wrap('Skipping $key')} (all $count image(s) already exist)',
        );
        return _Result(ok: true);
      }
    }

    int saved = 0;
    final seen = <int>{};
    for (final idx in indices) {
      var attempts = 0;
      const maxAttemptsPerIndex = 4;
      while (attempts < maxAttemptsPerIndex) {
        attempts++;
        try {
          logger.detail(
            'Requesting image for $key idx=$idx size=${config.size ?? 'default'} format=$targetFormat',
          );
          final bytes = await client.generateImage(
            model: config.model.split(':').last,
            prompt: prompt,
            size: config.size,
            transparent: config.transparent,
            format: targetFormat,
            seed: config.seed,
            timeoutMs: config.timeoutMs,
            extra: {
              if (config.openaiProject != null)
                'openai_project': config.openaiProject,
              if (config.openaiOrganization != null)
                'openai_organization': config.openaiOrganization,
            },
          );
          logger.detail('Received ${bytes.length} bytes for $key idx=$idx');
          final hash = bytes.hashCode;
          if (seen.contains(hash)) {
            logger.warn(
              '${yellow.wrap('Duplicate image detected for $key, retrying...')}',
            );
            continue;
          }
          seen.add(hash);

          final filePath = _filePathForIndex(basePath, targetFormat, idx);
          await File(filePath).writeAsBytes(bytes);
          logger.info('${green.wrap('Saved')} ${lightCyan.wrap(filePath)}');
          saved++;
          break;
        } on ProviderApiException catch (e) {
          // Always surface full API error regardless of verbosity
          logger
            ..err(
              'Failed to generate $key: ${e.provider} error ${e.statusCode}: ${e.message}',
            )
            ..detail('Request URL: ${e.url}')
            ..detail('Raw body: ${e.rawBody}');
          if (!config.ignoreFailures) {
            // continue others but mark failure
          }
          break;
        } catch (e) {
          logger.err('Failed to generate $key: $e');
          final msg = e.toString();
          if (msg.contains('OpenAI error 403')) {
            logger
              ..info('')
              ..warn(
                yellow.wrap('OpenAI returned 403 (forbidden). Common causes:')!,
              )
              ..info(
                '  - API key invalid or not authorized for this endpoint/model',
              )
              ..info('  - Billing/credit issue or account restricted')
              ..info(
                '  - Model access not enabled (try model: openai:gpt-image-1)',
              )
              ..info(
                '  - If using project-scoped keys (sk-proj-...), set openai_project or OPENAI_PROJECT',
              )
              ..info(
                '  - If your org is required, set openai_organization or OPENAI_ORGANIZATION',
              )
              ..info('');
          }
          if (!config.ignoreFailures) {
            // continue others but mark failure
          }
          break;
        }
      }
    }

    final ok = saved == indices.length;
    if (!ok) {
      logger.warn(
        '${yellow.wrap('Generated $saved/${indices.length} needed image(s) for $key')}',
      );
    }
    return _Result(ok: ok);
  }

  String _filePathForIndex(String basePath, String format, int index) {
    final ext = '.$format';
    if (index == 0) return '$basePath$ext';
    final suffix = index.toString().padLeft(3, '0');
    return '${basePath}_$suffix$ext';
  }
}

class _Result {
  _Result({required this.ok});
  final bool ok;
}



import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class CliOverrides {
  CliOverrides({
    this.output,
    this.model,
    this.transparent,
    this.onlyKeys,
    this.dryRun,
    this.concurrency,
    this.timeoutMs,
    this.format,
    this.size,
    this.count,
    this.seed,
    this.force,
    this.ignoreFailures,
    this.regenerate,
    this.regenerateKeys,
  });

  final String? output;
  final String? model;
  final bool? transparent;
  final List<String>? onlyKeys;
  final bool? dryRun;
  final int? concurrency;
  final int? timeoutMs;
  final String? format;
  final String? size;
  final int? count;
  final int? seed;
  final bool? force;
  final bool? ignoreFailures;
  final bool? regenerate;
  final List<String>? regenerateKeys;
}

class AppConfig {
  AppConfig({
    required this.output,
    required this.transparent,
    required this.textPrompt,
    required this.jsonPrompt,
    required this.images,
    required this.model,
    required this.format,
    required this.count,
    required this.concurrency,
    this.size,
    this.seed,
    this.timeoutMs,
    this.negativePrompt,
    required this.providerKeys,
    this.openaiProject,
    this.openaiOrganization,
    required this.cli,
    required this.force,
    required this.ignoreFailures,
    required this.regenerateAll,
    required this.regenerateKeys,
  });

  final String output;
  final bool transparent;
  final String? textPrompt;
  final String? jsonPrompt;
  final Map<String, String> images;
  final String model; // <provider>:<model>
  final String format; // default png
  final String? size; // e.g., 1024x1024
  final int count;
  final int? seed;
  final int concurrency;
  final int? timeoutMs;
  final String? negativePrompt;
  final Map<String, String> providerKeys;
  final String? openaiProject;
  final String? openaiOrganization;
  final CliEffective cli;
  final bool force;
  final bool ignoreFailures;
  final bool regenerateAll;
  final List<String> regenerateKeys;
}

class CliEffective {
  CliEffective({
    required this.dryRun,
    this.onlyKeys,
  });

  final bool dryRun;
  final List<String>? onlyKeys;
}

class AppConfigLoader {
  static Future<AppConfig> load(File yamlFile, {CliOverrides? cliOverrides}) async {
    if (!yamlFile.existsSync()) {
      throw StateError('Config file not found: ${yamlFile.path}');
    }

    // Load env from .env if present (avoid noisy failure logs)
    final env = dotenv.DotEnv(includePlatformEnvironment: true);
    final envFile = File('.env');
    if (envFile.existsSync()) {
      env.load();
    }

    final yamlContent = yamlFile.readAsStringSync();
    final map = loadYaml(yamlContent) as YamlMap;

    String? _readString(YamlMap m, String key) => m.containsKey(key) ? (m[key] as dynamic)?.toString() : null;
    bool? _readBool(YamlMap m, String key) => m.containsKey(key) ? (m[key] as dynamic) == true : null;
    int? _readInt(YamlMap m, String key) {
      if (!m.containsKey(key)) return null;
      final v = m[key];
      if (v is int) return v;
      return int.tryParse('$v');
    }

    final output =
        cliOverrides?.output ?? _readString(map, 'output') ?? 'assets/';
    final transparent = cliOverrides?.transparent ?? (_readBool(map, 'transparent') ?? false);
    final textPrompt = _readString(map, 'text_prompt');
    final jsonPrompt = _readString(map, 'json_prompt');
    final size = cliOverrides?.size ?? _readString(map, 'size');
    final format = (cliOverrides?.format ?? _readString(map, 'format') ?? 'png').toLowerCase();
    final count = cliOverrides?.count ?? _readInt(map, 'count') ?? 1;
    final seed = cliOverrides?.seed ?? _readInt(map, 'seed');
    final timeoutMs = cliOverrides?.timeoutMs ?? _readInt(map, 'timeout_ms');
    final concurrency = cliOverrides?.concurrency ?? _readInt(map, 'concurrency') ?? 2;
    final negativePrompt = _readString(map, 'negative_prompt');

    final model = cliOverrides?.model ?? _readString(map, 'model') ?? (throw StateError('Missing required field: model'));
    final imagesRaw = map['images'];
    if (imagesRaw is! YamlMap || imagesRaw.isEmpty) {
      throw StateError('Missing or empty images map');
    }
    final images = <String, String>{for (final e in imagesRaw.entries) '${e.key}': '${e.value}'};

    final provider = model.split(':').firstOrNull ?? model;
    final keys = <String, String>{
      'openai': _readString(map, 'openai_api_key') ?? env['OPENAI_API_KEY'] ?? '',
      'gemini': _readString(map, 'gemini_api_key') ?? env['GEMINI_API_KEY'] ?? '',
    };
    
    // Check for missing API keys with better error messages
    final keyForProvider = keys[provider] ?? '';
    if (keyForProvider.isEmpty) {
      final yamlKey = '${provider}_api_key';
      final envKey = '${provider.toUpperCase()}_API_KEY';
      throw StateError(
        'Missing API key for provider "$provider".\n'
        'Set one of:\n'
        '  - YAML: $yamlKey: your-key-here\n'
        '  - Environment: $envKey=your-key-here\n'
        '  - .env file: $envKey=your-key-here'
      );
    }

    // Optional OpenAI organization/project headers (sent only if present)
    final openaiProject = _readString(map, 'openai_project') ?? env['OPENAI_PROJECT'];
    final openaiOrganization = _readString(map, 'openai_organization') ?? env['OPENAI_ORGANIZATION'] ?? env['OPENAI_ORG'];

    final cli = CliEffective(
      dryRun: cliOverrides?.dryRun ?? false,
      onlyKeys: cliOverrides?.onlyKeys,
    );

    // sanitize output path
    final resolvedOutput = p.normalize(output);
    return AppConfig(
      output: resolvedOutput,
      transparent: transparent,
      textPrompt: textPrompt,
      jsonPrompt: jsonPrompt,
      images: images,
      model: model,
      format: format,
      size: size,
      count: count,
      seed: seed,
      concurrency: concurrency,
      timeoutMs: timeoutMs,
      negativePrompt: negativePrompt,
      providerKeys: keys,
      openaiProject: openaiProject,
      openaiOrganization: openaiOrganization,
      cli: cli,
      force: cliOverrides?.force ?? false,
      ignoreFailures: cliOverrides?.ignoreFailures ?? false,
      regenerateAll:
          (cliOverrides?.regenerate == true) &&
          ((cliOverrides?.regenerateKeys?.isEmpty ?? true)),
      regenerateKeys: List<String>.from(
        cliOverrides?.regenerateKeys ?? const <String>[],
      ),
    );
  }
}

extension FirstOrNull on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}



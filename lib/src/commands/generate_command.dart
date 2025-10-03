import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'package:ai_batch_gen/src/config/config.dart';
import 'package:ai_batch_gen/src/engine/engine.dart';

class GenerateCommand extends Command<int> {
  GenerateCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption('config', help: 'Path to YAML config (default ai_batch_gen.yaml)')
      ..addOption('output', help: 'Output directory override')
      ..addOption('model', help: 'Model override in the form <provider>:<model>')
      ..addFlag('transparent', help: 'Request transparent background (best-effort)')
      ..addOption('only', help: 'Comma-separated list of image keys to run')
      ..addFlag(
        'regenerate',
        abbr: 'r',
        help:
            'Regenerate specified keys (positional args) or all if none given',
        negatable: false,
      )
      ..addFlag('dry-run', help: 'Print plan without generating', negatable: false)
      ..addOption('concurrency', help: 'Concurrency (default from config or 2)')
      ..addOption('timeout', help: 'Per-request timeout in ms')
      ..addOption('format', help: 'Target format (png default)')
      ..addOption('size', help: 'Image size, e.g., 1024x1024')
      ..addOption('count', help: 'Images per entry (default from config or 1)')
      ..addOption('seed', help: 'Seed value if supported')
      ..addFlag('force', abbr: 'f', help: 'Overwrite existing files', negatable: false)
      ..addFlag('ignore-failures', help: 'Exit 0 even if some images fail', negatable: false);
  }

  @override
  String get description => 'Generate images in batch from YAML config';

  @override
  String get name => 'generate';

  final Logger _logger;

  @override
  Future<int> run() async {
    final configPath = (argResults?['config'] as String?) ?? 'ai_batch_gen.yaml';
    final loadProgress = _logger.progress('Loading config ${cyan.wrap(configPath)}');
    late final AppConfig config;
    try {
      config = await AppConfigLoader.load(
        File(configPath),
        cliOverrides: CliOverrides(
          output: argResults?['output'] as String?,
          model: argResults?['model'] as String?,
          transparent: argResults?['transparent'] == true,
          onlyKeys: (argResults?['only'] as String?)?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          regenerate: argResults?['regenerate'] == true,
          regenerateKeys: argResults?.rest.isEmpty == true
              ? null
              : argResults?.rest,
          dryRun: argResults?['dry-run'] == true,
          concurrency: _tryParseInt(argResults?['concurrency'] as String?),
          timeoutMs: _tryParseInt(argResults?['timeout'] as String?),
          format: argResults?['format'] as String?,
          size: argResults?['size'] as String?,
          count: _tryParseInt(argResults?['count'] as String?),
          seed: _tryParseInt(argResults?['seed'] as String?),
          force: argResults?['force'] == true,
          ignoreFailures: argResults?['ignore-failures'] == true,
        ),
      );
    } on StateError catch (e) {
      loadProgress.fail('${red.wrap('Configuration Error')}');
      _logger
        ..err('')
        ..err('${red.wrap('❌ Configuration Error:')}')
        ..err('${yellow.wrap(e.message)}')
        ..err('')
        ..info('${lightCyan.wrap('💡 Quick Fix:')}')
        ..info('Create a ${cyan.wrap('.env')} file with your API keys:')
        ..info('  ${lightGreen.wrap('OPENAI_API_KEY=your-key-here')}')
        ..info('  ${lightGreen.wrap('GEMINI_API_KEY=your-key-here')}')
        ..info('')
        ..info('Or add them to your YAML config:')
        ..info('  ${lightGreen.wrap('openai_api_key: your-key-here')}')
        ..info('  ${lightGreen.wrap('gemini_api_key: your-key-here')}');
      return ExitCode.usage.code;
    } on Exception catch (e) {
      loadProgress.fail('${red.wrap('Failed')}');
      _logger.err('$e');
      return ExitCode.usage.code;
    }
    loadProgress.complete('Config loaded');

    _logger.info(green.wrap('Dry-run: ${config.cli.dryRun}')!);
    if (config.cli.dryRun) {
      _printPlan(config);
      return ExitCode.success.code;
    }

    final engineStart = _logger.progress('Generating images');
    try {
      final exit = await GenerationEngine(logger: _logger).run(config);
      if (exit == ExitCode.success.code) {
        engineStart.complete('Generation completed');
      } else {
        engineStart.fail();
      }
      return exit;
    } catch (e) {
      engineStart.fail();
      _logger.err('$e');
      return ExitCode.software.code;
    }
  }

  void _printPlan(AppConfig config) {
    final planHeader = styleBold.wrap('Resolved Plan')!;
    _logger
      ..info('')
      ..info('${lightCyan.wrap('=== $planHeader ===')}')
      ..info('Output: ${cyan.wrap(config.output)}')
      ..info('Model: ${cyan.wrap(config.model)}')
      ..info('Format: ${cyan.wrap(config.format)}  Size: ${cyan.wrap(config.size ?? 'default')}  Transparent: ${cyan.wrap(config.transparent.toString())}')
      ..info('Concurrency: ${cyan.wrap('${config.concurrency}')}  Timeout: ${cyan.wrap('${config.timeoutMs ?? 'default'} ms')}  Count: ${cyan.wrap('${config.count}')}')
      ..info('Images: ${cyan.wrap('${config.images.length} entries')}');
    for (final entry in config.images.entries) {
      if (config.cli.onlyKeys != null && !config.cli.onlyKeys!.contains(entry.key)) {
        continue;
      }
      _logger.info('  - ${lightGreen.wrap(entry.key)}: ${entry.value}');
    }
  }

  int? _tryParseInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value);
  }
}



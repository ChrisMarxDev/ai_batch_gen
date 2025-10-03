# Changelog

All notable changes to this project will be documented in this file.

The format follows Keep a Changelog and the project aims to follow Semantic Versioning.

## [0.0.1] - 2025-10-06

### Added
- Initial release of AI Batch Gen CLI.
- YAML-driven batch image generation (`ai_batch_gen.yaml`).
- Providers: OpenAI (`openai:gpt-image-1`) and Google Gemini.
- Prompt composition: combines `text_prompt`, `json_prompt` (as text), per-image prompt, optional `negative_prompt`, and final transparency line when enabled.
- Transparency handling: best-effort via prompt guidance.
- Output handling: default `assets/`, smart filenames with numeric suffixes (`_001`, `_002`, …) for multiple images.
- Skipping behavior: existing images are skipped by default; only missing indices are generated.
- Regeneration: `--regenerate` / `-r` to overwrite specified keys or all when no keys given.
- Flags: `--config`, `--output`, `--model`, `--transparent`, `--only`, `--dry-run`, `--concurrency`, `--timeout`, `--format`, `--size`, `--count`, `--seed`, `--force`, `--ignore-failures`, `--regenerate`.
- Verbose logging: `--verbose` / `-v` with detailed debug traces.
- Error handling: provider API errors surfaced verbatim (status code, message); helpful 403 guidance.
- .env support with precedence: YAML > env (.env/system) > error.
- VSCode launch configuration with sample args.

[0.0.1]: https://pub.dev/packages/ai_batch_gen

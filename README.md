# AI Batch Gen

![coverage][coverage_badge]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

A powerful command-line tool for batch AI image generation using OpenAI and Google Gemini APIs. Generate multiple images from YAML configuration with support for custom prompts, transparency, and intelligent duplicate detection.

## Features ✨

- 🎨 **Multi-Provider Support**: OpenAI (gpt-image-1) and Google Gemini
- 📝 **Flexible Prompting**: Combine text, JSON, and per-image prompts
- 🖼️ **Batch Processing**: Generate multiple images with concurrency control
- 🎯 **Smart Naming**: Automatic filename generation with numeric suffixes
- 🔄 **Duplicate Detection**: Ensures unique images with retry logic
- 🌈 **Transparent Backgrounds**: Best-effort transparency support
- ⚡ **Performance**: Configurable concurrency with exponential backoff
- 🎨 **Beautiful CLI**: Colorful output with progress indicators
- 🔧 **Dry Run Mode**: Preview generation plan before execution
- 📁 **Format Support**: PNG by default; other formats when providers return them

## Installation 🚀

```sh
# Install globally
dart pub global activate ai_batch_gen

# Or install locally
dart pub global activate --source=path <path to this package>
```

## Quick Start

1. **Create a configuration file** (`ai_batch_gen.yaml` in your project root):

```yaml
output: assets/images/          # Optional; defaults to assets/
transparent: true               # Optional; default false
format: png                     # Optional; default png
size: 1024x1024                 # Optional
count: 3                        # Optional; default 1

text_prompt: |
  Handdrawn illustration with water colors and minimal line strength.

images:
  fridge: a retro style fridge with a neon sign
  cup: a cup with a logo
  book: a book with a logo

model: openai:gpt-image-1
```

2. **Set up API keys** (create `.env` file):

```bash
OPENAI_API_KEY=your-openai-api-key
GEMINI_API_KEY=your-gemini-api-key
```

3. **Generate images**:

```sh
# Dry run to preview
ai_batch_gen generate --dry-run

# Generate all images
ai_batch_gen generate

# Generate specific images only
ai_batch_gen generate --only "fridge,cup"

# Force overwrite existing files
ai_batch_gen generate --force
```

## Configuration

### YAML Configuration Schema

```yaml
# Output directory (optional, defaults to assets/)
output: assets/images/

# Image settings
transparent: true                    # Request transparent background
format: png                         # Output format (png, webp, jpg)
size: 1024x1024                    # Image dimensions
count: 3                           # Number of images per entry

# Prompt composition
text_prompt: |                     # Global text prompt
  Handdrawn illustration with water colors and minimal line strength.

json_prompt: |                     # Global JSON prompt (included as text)
  {
    "type": "image",
    "image": "assets/images/image.png"
  }

negative_prompt: |                 # What to avoid
  Photorealism, harsh shadows

# Image definitions (required)
images:
  fridge: a retro style fridge with a neon sign
  cup: a cup with a logo
  book: a book with a logo

# Model configuration (required)
model: openai:gpt-image-1          # Format: <provider>:<model>
# Alternative: gemini:gemini-1.5-pro

# API keys (optional - prefer .env)
openai_api_key: sk-proj-...
gemini_api_key: your-gemini-key...

# Performance settings
concurrency: 2                     # Concurrent requests
timeout_ms: 60000                  # Per-request timeout
```

### Environment Variables (.env supported)

Create a `.env` file in your project root:

```bash
# OpenAI API Key
OPENAI_API_KEY=sk-proj-your-key-here

# Google Gemini API Key  
GEMINI_API_KEY=your-gemini-key-here
```

**Precedence**: YAML keys > Environment variables (.env or system) > Error if missing

## Command Line Usage

### Basic Commands

```sh
# Show help
ai_batch_gen --help
ai_batch_gen generate --help

# Show version
ai_batch_gen --version

# Dry run (preview plan)
ai_batch_gen generate --dry-run

# Use alternate config file
ai_batch_gen generate --config ai_batch_gen.yaml
```

### Generation Options

```sh
# Basic generation
ai_batch_gen generate

# Custom config file
ai_batch_gen generate --config my-config.yaml

# Override settings
ai_batch_gen generate \
  --output ./output \
  --model openai:gpt-image-1 \
  --size 1024x1024 \
  --format png \
  --transparent \
  --count 5

# Generate specific images only
ai_batch_gen generate --only "fridge,cup,book"

# Force overwrite existing files
ai_batch_gen generate --force

# Ignore failures and continue
ai_batch_gen generate --ignore-failures
```

### Performance Options

```sh
# Control concurrency
ai_batch_gen generate --concurrency 4

# Set timeout per request
ai_batch_gen generate --timeout 30000

# Use specific seed for reproducibility
ai_batch_gen generate --seed 42
```

## Prompt Composition

The tool intelligently combines multiple prompt sources:

1. **Text Prompt**: Global text instructions
2. **JSON Prompt**: Structured prompt (included as text)
3. **Image Prompt**: Per-image specific prompt
4. **Transparency**: Automatic transparency directive
5. **Negative Prompt**: What to avoid

**Example composition**:
```
Handdrawn illustration with water colors and minimal line strength.

{
  "type": "image",
  "image": "assets/images/image.png"
}

a cup with a logo

Avoid: Photorealism, harsh shadows

Background must be transparent (PNG with alpha).
```

## File Naming

- **Default**: `fridge.png`, `cup.png`, `book.png`
- **Multiple images**: `fridge_001.png`, `fridge_002.png`, `fridge_003.png`
- **Collision handling**: Automatic numeric suffixes
- **Force mode**: Overwrites existing files

## Supported Providers

### OpenAI
- **Models**: `gpt-image-1`
- **Formats**: PNG (provider default)
- **Features**: Transparency (via prompt), size control, seed support
- **Example**: `model: openai:gpt-image-1`

### Google Gemini
- **Models**: `gemini-1.5-pro`, `gemini-1.5-flash`
- **Formats**: PNG, WebP, JPG
- **Features**: Safety settings, temperature control
- **Example**: `model: gemini:gemini-1.5-pro`

## Advanced Features

### Duplicate Detection
- Automatic detection of identical images
- Limited retry attempts for uniqueness
- Hash-based comparison for efficiency

### Concurrency Control
- Configurable concurrent requests (default: 2)
- Exponential backoff for rate limiting
- Per-request timeout handling

### Error Handling
- Retry logic for transient failures
- Graceful degradation on provider errors
- Detailed error reporting with context

### Dry Run Mode
```sh
ai_batch_gen generate --dry-run
```
Shows:
- Resolved configuration
- Output file paths
- Prompt composition preview
- Provider and model details

## Examples

### E-commerce Product Images
```yaml
output: products/
transparent: true
format: png
size: 1024x1024

text_prompt: |
  Professional product photography, clean white background, studio lighting

images:
  laptop: a sleek silver laptop on a white desk
  phone: a modern smartphone with a minimalist design
  headphones: premium wireless headphones in black

model: openai:gpt-image-1
```

### Art Collection
```yaml
output: gallery/
format: png
size: 1024x1024
count: 5

text_prompt: |
  Digital art, vibrant colors, abstract composition

negative_prompt: |
  Photorealistic, dark colors, cluttered

images:
  sunset: a digital painting of a vibrant sunset over mountains
  ocean: abstract waves in blue and turquoise
  forest: mystical forest with glowing trees

model: gemini:gemini-1.5-pro
```

## Troubleshooting

### Common Issues

**Missing API Key**:
```
Error: Missing API key for provider "openai"
```
Solution: Set `OPENAI_API_KEY` in `.env` or YAML config

**Invalid Model**:
```
Error: Unknown provider: "invalid"
```
Solution: Use `openai:` or `gemini:` prefix

**File Permission Error**:
```
Error: Failed to write file
```
Solution: Check output directory permissions

### Debug Mode
```sh
# Enable verbose logging
ai_batch_gen generate --verbose

# Check configuration
ai_batch_gen generate --dry-run
```

## Development

### Running Tests
```sh
dart test
```

### Building
```sh
dart compile exe bin/ai_batch_gen.dart -o ai_batch_gen
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Running Tests with Coverage 🧪

To run all unit tests with coverage:

```sh
dart pub global activate coverage 1.15.0
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
```

To view the generated coverage report:

```sh
# Generate Coverage Report
genhtml coverage/lcov.info -o coverage/

# Open Coverage Report
open coverage/index.html
```

---

[coverage_badge]: coverage_badge.svg
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_cli_link]: https://github.com/VeryGoodOpenSource/very_good_cli
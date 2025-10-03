class PromptComposer {
  static String compose({
    String? textPrompt,
    String? jsonPrompt,
    required String imagePrompt,
    bool transparent = false,
    String? negativePrompt,
  }) {
    final parts = <String>[];
    if (textPrompt != null && textPrompt.trim().isNotEmpty) {
      parts.add(textPrompt.trim());
    }
    if (jsonPrompt != null && jsonPrompt.trim().isNotEmpty) {
      parts.add(jsonPrompt.trim());
    }
    parts.add(imagePrompt.trim());
    if (negativePrompt != null && negativePrompt.trim().isNotEmpty) {
      parts.add('Avoid: ${negativePrompt.trim()}');
    }
    if (transparent) {
      // Ensure the transparency directive is the final sentence when enabled
      parts.add('Background must be transparent (PNG with alpha).');
    }
    return parts.join('\n\n');
  }
}

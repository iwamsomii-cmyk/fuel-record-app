import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

/// A signature pad the officer draws on with a finger/mouse, matching
/// the paper book's handwritten signature. Wrap this around a
/// [SignatureController] the parent screen owns and disposes.
class SignatureField extends StatelessWidget {
  final String label;
  final SignatureController controller;
  final bool enabled;

  const SignatureField({
    super.key,
    required this.label,
    required this.controller,
    this.enabled = true,
  });

  /// Exports the current drawing as a base64-encoded PNG string,
  /// or null if nothing has been drawn yet.
  static Future<String?> exportBase64(SignatureController controller) async {
    if (controller.isEmpty) return null;
    final bytes = await controller.toPngBytes();
    if (bytes == null) return null;
    return base64Encode(bytes);
  }

  /// Renders a previously-saved base64 PNG signature as a small image.
  static Widget thumbnail(String base64Data, {double height = 40}) {
    try {
      return Image.memory(base64Decode(base64Data), height: height, fit: BoxFit.contain);
    } catch (_) {
      return const Icon(Icons.error_outline, size: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: IgnorePointer(
            ignoring: !enabled,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Signature(
                  controller: controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ),
        if (enabled)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: controller.clear,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Clear'),
            ),
          ),
      ],
    );
  }
}

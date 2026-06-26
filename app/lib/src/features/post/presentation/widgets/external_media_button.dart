import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_spacing.dart';

/// Opens a URL in an external app/browser. Used for media we don't play inline
/// (Vimeo, unrecognized video hosts, and "other" file downloads).
class ExternalMediaButton extends StatelessWidget {
  const ExternalMediaButton({
    super.key,
    required this.url,
    required this.label,
    this.icon = Icons.open_in_new_rounded,
  });

  final String url;
  final String label;
  final IconData icon;

  Future<void> _open(BuildContext context) async {
    final Uri? uri = Uri.tryParse(url);
    final bool ok = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح الرابط')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: FilledButton.tonalIcon(
          onPressed: () => _open(context),
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

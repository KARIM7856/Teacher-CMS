import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/external_link.dart';

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

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: FilledButton.tonalIcon(
          onPressed: () => openExternalUrl(context, url),
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

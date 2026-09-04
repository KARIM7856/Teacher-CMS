import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the browser or the handling app (mail client for `mailto:`),
/// telling the user if nothing can handle it rather than failing silently.
///
/// Callers pass their own [BuildContext] so the message lands on the right
/// Scaffold; the context is re-checked after the await.
Future<void> openExternalUrl(
  BuildContext context,
  String url, {
  String failureMessage = 'تعذّر فتح الرابط',
}) async {
  final Uri? uri = Uri.tryParse(url);
  final bool opened = uri != null &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failureMessage)),
    );
  }
}

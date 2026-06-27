import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../models/media_item.dart';
import '../../../content/application/content_providers.dart';

/// A downloadable "other" attachment: a tile with an open/download action.
/// Stored files are resolved to a signed URL on demand; external files open
/// directly. Either way the file opens in an external app/browser.
class FileAttachmentView extends ConsumerWidget {
  const FileAttachmentView({super.key, required this.item});

  final MediaItem item;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    try {
      final String url = item.storagePath != null && item.storagePath!.isNotEmpty
          ? await ref.read(contentRepositoryProvider).signedUrlForPath(item.storagePath!)
          : item.externalUrl!;
      final Uri? uri = Uri.tryParse(url);
      final bool ok = uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر فتح الملف')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر فتح الملف')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file_rounded),
        title: Text(item.displayName ?? 'ملف مرفق'),
        trailing: const Icon(Icons.download_rounded),
        onTap: () => _open(context, ref),
      ),
    );
  }
}

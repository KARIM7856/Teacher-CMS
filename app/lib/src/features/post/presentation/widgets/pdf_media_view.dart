import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../models/media_item.dart';
import '../../../content/application/content_providers.dart';
import 'external_media_button.dart';

/// Renders a PDF attachment inline (pinch-to-zoom, page scroll). Bytes come from
/// the private storage bucket (via the repository) or from an external URL.
class PdfMediaView extends ConsumerStatefulWidget {
  const PdfMediaView({super.key, required this.item});

  final MediaItem item;

  @override
  ConsumerState<PdfMediaView> createState() => _PdfMediaViewState();
}

class _PdfMediaViewState extends ConsumerState<PdfMediaView> {
  PdfControllerPinch? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Uint8List> _loadBytes() async {
    final MediaItem item = widget.item;
    if (item.storagePath != null && item.storagePath!.isNotEmpty) {
      return ref.read(contentRepositoryProvider).downloadBytes(item.storagePath!);
    }
    final http.Response response = await http.get(Uri.parse(item.externalUrl!));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  Future<void> _load() async {
    try {
      final Uint8List bytes = await _loadBytes();
      final PdfControllerPinch controller =
          PdfControllerPinch(document: PdfDocument.openData(bytes));
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      final String? url = widget.item.externalUrl;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تعذّر عرض ملف PDF هنا.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (url != null && url.isNotEmpty)
            ExternalMediaButton(
              url: url,
              label: 'افتح الملف',
              icon: Icons.picture_as_pdf_rounded,
            ),
        ],
      );
    }

    return Container(
      height: 480,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: _controller == null
          ? const Center(child: CircularProgressIndicator())
          : PdfViewPinch(controller: _controller!),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../models/media_item.dart';
import '../../../content/application/content_providers.dart';
import 'external_media_button.dart';

/// Renders a PDF attachment inline as a vertically-scrollable list of pages.
///
/// Each page is rasterized to an image lazily (only as it scrolls into view) so
/// large PDFs stay light on memory. The list is its own scrollable, so dragging
/// inside the frame pages through the document rather than scrolling the post.
/// Bytes come from the private storage bucket (via the repository) or an
/// external URL.
class PdfMediaView extends ConsumerStatefulWidget {
  const PdfMediaView({super.key, required this.item});

  final MediaItem item;

  @override
  ConsumerState<PdfMediaView> createState() => _PdfMediaViewState();
}

class _PdfMediaViewState extends ConsumerState<PdfMediaView> {
  PdfDocument? _document;
  int _pageCount = 0;
  bool _failed = false;

  // Rendered pages, memoized so a page scrolled off and back doesn't re-render.
  final Map<int, Future<_RenderedPage>> _pages = {};

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
      final PdfDocument document = await PdfDocument.openData(bytes);
      if (!mounted) {
        await document.close();
        return;
      }
      setState(() {
        _document = document;
        _pageCount = document.pagesCount;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<_RenderedPage> _pageFuture(int pageNumber, double targetWidthPx) {
    return _pages.putIfAbsent(
      pageNumber,
      () => _renderPage(pageNumber, targetWidthPx),
    );
  }

  Future<_RenderedPage> _renderPage(int pageNumber, double targetWidthPx) async {
    final PdfPage page = await _document!.getPage(pageNumber);
    try {
      final double aspectRatio = page.width / page.height;
      final PdfPageImage? image = await page.render(
        width: targetWidthPx,
        height: targetWidthPx / aspectRatio,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      if (image == null) throw StateError('render returned null');
      return _RenderedPage(bytes: image.bytes, aspectRatio: aspectRatio);
    } finally {
      await page.close();
    }
  }

  @override
  void dispose() {
    _document?.close();
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

    final BorderRadius radius = BorderRadius.circular(AppSpacing.radiusMd);
    final BoxDecoration frame = BoxDecoration(
      borderRadius: radius,
      border: Border.all(color: Theme.of(context).dividerColor),
      color: Colors.grey.shade200, // gutter behind the white pages
    );

    if (_document == null) {
      return Container(
        height: 200,
        decoration: frame,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final MediaQueryData media = MediaQuery.of(context);
    final double targetWidthPx =
        (media.size.width * media.devicePixelRatio).clamp(400, 2000).toDouble();
    final double frameHeight = (media.size.height * 0.8).clamp(360, 900).toDouble();

    return Container(
      height: frameHeight,
      clipBehavior: Clip.antiAlias,
      decoration: frame,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _pageCount,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => _PdfPageView(
          key: ValueKey<int>(index),
          page: _pageFuture(index + 1, targetWidthPx),
        ),
      ),
    );
  }
}

/// One rasterized PDF page, sized to its aspect ratio and filling the width.
class _PdfPageView extends StatelessWidget {
  const _PdfPageView({super.key, required this.page});

  final Future<_RenderedPage> page;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RenderedPage>(
      future: page,
      builder: (context, snapshot) {
        // A4-ish placeholder keeps the scroll position stable before render.
        if (snapshot.connectionState != ConnectionState.done) {
          return const AspectRatio(
            aspectRatio: 1 / 1.414,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final _RenderedPage? rendered = snapshot.data;
        if (rendered == null) {
          return const AspectRatio(
            aspectRatio: 1 / 1.414,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          );
        }
        return AspectRatio(
          aspectRatio: rendered.aspectRatio,
          child: Image.memory(
            rendered.bytes,
            fit: BoxFit.fitWidth,
            width: double.infinity,
          ),
        );
      },
    );
  }
}

class _RenderedPage {
  const _RenderedPage({required this.bytes, required this.aspectRatio});

  final Uint8List bytes;
  final double aspectRatio;
}

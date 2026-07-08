import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/theme/app_spacing.dart';

/// Plays a Google Drive video inline by embedding Drive's own `/preview` player
/// in a WebView. The file must be shared as "anyone with the link" for the
/// embed to load.
///
/// Unlike the stored/YouTube players, Drive's iframe gives us no playback
/// position, so this carries no resume/progress/complete hooks.
class GoogleDriveVideoPlayer extends StatefulWidget {
  const GoogleDriveVideoPlayer({super.key, required this.fileId});

  final String fileId;

  @override
  State<GoogleDriveVideoPlayer> createState() => _GoogleDriveVideoPlayerState();
}

class _GoogleDriveVideoPlayerState extends State<GoogleDriveVideoPlayer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(
        Uri.parse('https://drive.google.com/file/d/${widget.fileId}/preview'),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

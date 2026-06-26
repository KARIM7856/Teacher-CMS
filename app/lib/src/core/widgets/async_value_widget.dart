import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_view.dart';

/// Renders an [AsyncValue] with consistent loading / error / data handling so
/// every screen treats these states the same way. Pass [onRetry] to show a
/// retry button on error (typically `ref.invalidate(theProvider)`).
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      // Keep showing the last good data while a refresh is in flight.
      skipLoadingOnRefresh: true,
      loading: () =>
          loading ?? const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(onRetry: onRetry),
    );
  }
}

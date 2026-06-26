import 'package:flutter/widgets.dart';

/// Whether the OS "reduce / remove animations" accessibility setting is on.
/// Animation-heavy UI should fall back to a simpler, near-static presentation
/// when this is true.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

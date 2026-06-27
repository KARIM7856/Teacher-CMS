import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/supabase/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase only when credentials are provided (via --dart-define).
  // supabase_flutter restores any persisted session here, before the first frame.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // The legacy "anon" key is Supabase's "publishable" key — same value.
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  runApp(const ProviderScope(child: TeacherCmsApp()));
}

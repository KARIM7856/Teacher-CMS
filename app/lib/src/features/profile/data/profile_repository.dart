import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  /// The signed-in user's profile row, or null if not signed in / not found.
  Future<Profile?> fetchCurrent() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final Map<String, dynamic>? data =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return Profile.fromMap(data);
  }
}

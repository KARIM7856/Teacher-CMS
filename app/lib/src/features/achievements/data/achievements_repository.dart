import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/achievement.dart';
import '../../../models/celebration_data.dart';

/// Reads achievement definitions and the student's unlocked set, and asks the
/// server to evaluate/grant achievements via the `claim_achievements` RPC.
class AchievementsRepository {
  AchievementsRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<List<Achievement>> fetchAchievements() async {
    final List<Map<String, dynamic>> rows =
        await _client.from('achievements').select().order('sort_order');
    return rows.map(Achievement.fromMap).toList();
  }

  /// The student's unlocked achievements, mapped achievement id -> unlocked time.
  Future<Map<String, DateTime>> fetchUnlocked() async {
    final String? userId = _userId;
    if (userId == null) return const {};
    final List<Map<String, dynamic>> rows = await _client
        .from('user_achievements')
        .select('achievement_id, unlocked_at')
        .eq('student_id', userId);
    return {
      for (final row in rows)
        row['achievement_id'] as String:
            DateTime.tryParse(row['unlocked_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
    };
  }

  /// Records activity, evaluates the rules server-side, and returns whatever was
  /// *newly* unlocked by this call (so the caller can celebrate it). Best-effort:
  /// failures (e.g. offline) yield an empty list rather than surfacing an error.
  Future<List<CelebrationData>> claim() async {
    if (_userId == null) return const [];
    try {
      final dynamic result = await _client.rpc('claim_achievements');
      final List<dynamic> rows = (result as List<dynamic>?) ?? const [];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(CelebrationData.fromRpc)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

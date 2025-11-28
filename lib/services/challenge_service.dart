import '../config/badge_definitions.dart';
import '../models/challenge_models.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';

/// High-level helper that ensures the challenges page always has data.
class ChallengeService {
  final SupabaseService _supabaseService = SupabaseService();
  final DatabaseService _databaseService = DatabaseService();

  /// Load challenges from Supabase if possible, otherwise fall back to cached/local defaults.
  Future<List<Challenge>> loadChallenges() async {
    final List<Challenge> remoteChallenges = await _fetchRemoteChallenges();
    if (remoteChallenges.isNotEmpty) {
      await _persistBadges(remoteChallenges);
      return remoteChallenges;
    }

    final cachedBadges = await _databaseService.getAllBadges();
    if (cachedBadges.isNotEmpty) {
      return cachedBadges.map(Challenge.fromBadge).toList();
    }

    final defaultBadges = BadgeDefinitions.getDefaultBadges();
    await _databaseService.upsertBadges(defaultBadges);
    return defaultBadges.map(Challenge.fromBadge).toList();
  }

  Future<List<Challenge>> _fetchRemoteChallenges() async {
    try {
      if (!await _supabaseService.isConnected()) {
        return [];
      }

      final remote = await _supabaseService.getChallenges();
      return remote;
    } catch (e) {
      print('Error fetching remote challenges: $e');
      return [];
    }
  }

  Future<void> _persistBadges(List<Challenge> challenges) async {
    final badgesToPersist = challenges
        .map((challenge) => challenge.badge ?? challenge.toBadgeFallback())
        .where((badge) => badge.id != 0)
        .toList();

    if (badgesToPersist.isEmpty) return;
    await _databaseService.upsertBadges(badgesToPersist);
  }
}


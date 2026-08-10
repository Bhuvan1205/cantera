import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/menu_screen.dart';

enum RecommendationState { loading, loaded, error }

class RecommendationService {
  RecommendationService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Main entry point for recommendations. 
  /// Returns a state and a list of 4-5 recommended MenuItem objects.
  static Future<(RecommendationState, List<MenuItem>)> getRecommendations(
    List<MenuItem> currentMenu,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return (RecommendationState.error, <MenuItem>[]);
      }
      
      final uid = user.uid;

      // 1. Fetch user orders (Limit to 100 to avoid full scans, sufficient for 7-order check)
      final userOrdersSnap = await _db
          .collection('Orders')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get(const GetOptions(source: Source.serverAndCache));

      final userDocs = userOrdersSnap.docs;
      final int orderCount = userDocs.length;

      Map<String, int> candidateFrequencies = {};

      if (orderCount >= 7) {
        // Personalized mode: Extract frequency from user's history
        candidateFrequencies = _extractFrequencies(userDocs);
        
        // Ensure we have enough candidates; supplement with global if needed
        if (candidateFrequencies.length < 5) {
          final globalFreq = await _fetchGlobalFrequencies();
          _mergeFrequencies(candidateFrequencies, globalFreq);
        }
      } else {
        // Discovery mode (New user): Global popularity
        candidateFrequencies = await _fetchGlobalFrequencies();
      }

      // 2. Filter by availability and map back to MenuItem objects
      // Using canAddToCart as the authoritative indicator of availability.
      final availableMenuItems = currentMenu.where((item) => item.canAddToCart).toList();
      final Map<String, MenuItem> availableMenuMap = {
        for (var item in availableMenuItems) item.name.toLowerCase().trim(): item
      };

      // Match candidates
      final List<MapEntry<String, int>> sortedCandidates = candidateFrequencies.entries
          .where((entry) => availableMenuMap.containsKey(entry.key))
          .toList();

      // 3. Sort purely by frequency (descending), secondary sort by name
      sortedCandidates.sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return a.key.compareTo(b.key);
      });

      // 4. Return Top 5
      final topItems = sortedCandidates.take(5).map((entry) => availableMenuMap[entry.key]!).toList();
      
      return (RecommendationState.loaded, topItems);
    } catch (e) {
      return (RecommendationState.error, <MenuItem>[]);
    }
  }

  /// Extracts and counts item occurrences across a list of order documents.
  /// Counts by *quantity ordered* to represent true absolute demand.
  static Map<String, int> _extractFrequencies(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final Map<String, int> freq = {};
    for (var doc in docs) {
      final data = doc.data();
      final items = data['items'] as List<dynamic>? ?? [];
      for (var item in items) {
        if (item is Map<String, dynamic>) {
          final nameRaw = item['name'] as String?;
          if (nameRaw != null) {
            final name = nameRaw.toLowerCase().trim();
            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            freq[name] = (freq[name] ?? 0) + qty;
          }
        }
      }
    }
    return freq;
  }

  /// Fetches the 100 most recent orders globally to represent current popularity.
  static Future<Map<String, int>> _fetchGlobalFrequencies() async {
    try {
      final globalSnap = await _db
          .collection('Orders')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get(const GetOptions(source: Source.serverAndCache));
      return _extractFrequencies(globalSnap.docs);
    } catch (e) {
      return {};
    }
  }

  /// Safely merges source frequencies into target.
  static void _mergeFrequencies(Map<String, int> target, Map<String, int> source) {
    source.forEach((key, value) {
      if (target.containsKey(key)) {
        target[key] = target[key]! + value;
      } else {
        target[key] = value;
      }
    });
  }
}

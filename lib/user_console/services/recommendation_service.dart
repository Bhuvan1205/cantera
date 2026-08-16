import '../../core/services/api_client.dart';
import '../screens/menu_screen.dart';

export '../screens/menu_screen.dart' show MenuItem;

enum RecommendationState { loading, loaded, error }

/// Thin API client wrapper for the recommendation feature.
///
/// All business logic (order history fetching, frequency extraction,
/// frequency merging, ranking, Top-5 selection, orderCount >= 7 decision)
/// has been moved to the FastAPI backend at GET /api/recommendations.
///
/// Flutter's sole responsibilities here are:
///   1. Calling the API with the Firebase ID token (auto-attached by ApiClient).
///   2. Parsing the JSON response.
///   3. Mapping returned item names → MenuItem objects from the live menu stream.
///   4. Filtering to currently available items for display.
///   5. Returning the (state, items, isPersonalized) tuple the UI expects.
///
/// The public interface is intentionally preserved so MenuScreen requires
/// no changes.
class RecommendationService {
  RecommendationService._();

  /// Fetches recommendations from FastAPI and maps them to [MenuItem] objects.
  ///
  /// [currentMenu] is the locally-available menu stream used only to:
  ///   - look up full MenuItem data (price, imageUrl, stock, etc.)
  ///   - filter out items not currently available (canAddToCart == false)
  ///
  /// Returns `(RecommendationState, List<MenuItem>, isPersonalized)`.
  static Future<(RecommendationState, List<MenuItem>, bool)> getRecommendations(
    List<MenuItem> currentMenu,
  ) async {
    try {
      // One authenticated GET request — ApiClient attaches the Firebase ID
      // token as "Authorization: Bearer <token>" automatically.
      final response =
          await ApiClient.instance.get('/api/recommendations') as Map<String, dynamic>;

      // Parse backend response
      final rawItems = response['recommendations'] as List<dynamic>? ?? [];
      final source = response['source'] as String? ?? 'fallback';
      final isPersonalized = source == 'personalized';

      if (rawItems.isEmpty) {
        return (RecommendationState.loaded, <MenuItem>[], isPersonalized);
      }

      // Build a lookup map from the live menu stream: name → MenuItem.
      // This is presentation-only work — mapping API names to local menu objects.
      final availableMenuMap = <String, MenuItem>{
        for (final item in currentMenu.where((i) => i.canAddToCart))
          item.name.toLowerCase().trim(): item,
      };

      // Map each recommendation name → MenuItem; skip any not in current menu.
      final topItems = rawItems
          .whereType<Map<String, dynamic>>()
          .map((rec) {
            final name = (rec['name'] as String? ?? '').toLowerCase().trim();
            return availableMenuMap[name];
          })
          .whereType<MenuItem>() // removes nulls (items not in current menu)
          .toList();

      return (RecommendationState.loaded, topItems, isPersonalized);
    } on ApiException {
      return (RecommendationState.error, <MenuItem>[], false);
    } catch (_) {
      return (RecommendationState.error, <MenuItem>[], false);
    }
  }
}

/// App-wide constants. No secrets live here (there are none).
class AppConstants {
  AppConstants._();

  static const tcgdexBaseUrl = 'https://api.tcgdex.net/v2';
  static const defaultLang = 'en';

  /// Cached card JSON older than this is refreshed on next open.
  static const cacheTtl = Duration(days: 7);

  /// Standard card is 63 × 88 mm.
  static const cardAspectRatio = 63 / 88;
}

class Utils {
  static const _PROD_BASE_URL = "https://api.ravepay.co/v3/sdkcheckout/";
  static const String STANDARD_PAYMENT = "payments";
  static const _DEBUG_BASE_URL =
      "https://ravesandboxapi.flutterwave.com/v3/sdkcheckout/";
  static const DEFAULT_CURRENCY = "NGN";

  /// Returns base url depending on test mode
  static String getBaseUrl(final bool isTestMode) {
    return isTestMode ? _DEBUG_BASE_URL : _PROD_BASE_URL;
  }

  static Map<String, dynamic> removeKeysWithEmptyValues(final Map<String, dynamic> map) {
    final Map<String, dynamic> copied = Map.from(map);
    map.forEach((key, value) {
      if (map[key] == null || map[key] == "") copied
          .remove(key);
    });
    return copied;
  }
}

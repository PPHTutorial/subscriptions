/// Comprehensive list of currencies with names and symbols
class CurrencyList {
  /// List of all supported currencies with their display names
  static const List<CurrencyInfo> currencies = [
    // Major currencies
    CurrencyInfo(code: 'USD', name: 'US Dollar', symbol: '\$', flag: '🇺🇸'),
    CurrencyInfo(code: 'EUR', name: 'Euro', symbol: '€', flag: '🇪🇺'),
    CurrencyInfo(code: 'GBP', name: 'British Pound', symbol: '£', flag: '🇬🇧'),
    CurrencyInfo(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flag: '🇯🇵'),
    CurrencyInfo(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flag: '🇨🇳'),
    CurrencyInfo(code: 'INR', name: 'Indian Rupee', symbol: '₹', flag: '🇮🇳'),
    CurrencyInfo(
        code: 'CAD', name: 'Canadian Dollar', symbol: '\$', flag: '🇨🇦'),
    CurrencyInfo(
        code: 'AUD', name: 'Australian Dollar', symbol: '\$', flag: '🇦🇺'),
    CurrencyInfo(code: 'CHF', name: 'Swiss Franc', symbol: 'Fr', flag: '🇨🇭'),
    CurrencyInfo(
        code: 'SGD', name: 'Singapore Dollar', symbol: '\$', flag: '🇸🇬'),
    CurrencyInfo(
        code: 'HKD', name: 'Hong Kong Dollar', symbol: '\$', flag: '🇭🇰'),
    CurrencyInfo(
        code: 'NZD', name: 'New Zealand Dollar', symbol: '\$', flag: '🇳🇿'),

    // African currencies
    CurrencyInfo(code: 'GHS', name: 'Ghanaian Cedi', symbol: '₵', flag: '🇬🇭'),
    CurrencyInfo(
        code: 'NGN', name: 'Nigerian Naira', symbol: '₦', flag: '🇳🇬'),
    CurrencyInfo(
        code: 'ZAR', name: 'South African Rand', symbol: 'R', flag: '🇿🇦'),
    CurrencyInfo(
        code: 'KES', name: 'Kenyan Shilling', symbol: 'KSh', flag: '🇰🇪'),
    CurrencyInfo(
        code: 'UGX', name: 'Ugandan Shilling', symbol: 'USh', flag: '🇺🇬'),
    CurrencyInfo(
        code: 'TZS', name: 'Tanzanian Shilling', symbol: 'TSh', flag: '🇹🇿'),
    CurrencyInfo(
        code: 'RWF', name: 'Rwandan Franc', symbol: 'RF', flag: '🇷🇼'),
    CurrencyInfo(
        code: 'ETB', name: 'Ethiopian Birr', symbol: 'Br', flag: '🇪🇹'),
    CurrencyInfo(
        code: 'EGP', name: 'Egyptian Pound', symbol: 'E£', flag: '🇪🇬'),
    CurrencyInfo(
        code: 'MAD', name: 'Moroccan Dirham', symbol: 'DH', flag: '🇲🇦'),
    CurrencyInfo(
        code: 'XOF', name: 'West African CFA Franc', symbol: 'CFA', flag: '🌍'),
    CurrencyInfo(
        code: 'XAF',
        name: 'Central African CFA Franc',
        symbol: 'CFA',
        flag: '🌍'),

    // European currencies
    CurrencyInfo(
        code: 'SEK', name: 'Swedish Krona', symbol: 'kr', flag: '🇸🇪'),
    CurrencyInfo(
        code: 'NOK', name: 'Norwegian Krone', symbol: 'kr', flag: '🇳🇴'),
    CurrencyInfo(code: 'DKK', name: 'Danish Krone', symbol: 'kr', flag: '🇩🇰'),
    CurrencyInfo(code: 'PLN', name: 'Polish Zloty', symbol: 'zł', flag: '🇵🇱'),
    CurrencyInfo(code: 'CZK', name: 'Czech Koruna', symbol: 'Kč', flag: '🇨🇿'),
    CurrencyInfo(
        code: 'HUF', name: 'Hungarian Forint', symbol: 'Ft', flag: '🇭🇺'),
    CurrencyInfo(
        code: 'RON', name: 'Romanian Leu', symbol: 'lei', flag: '🇷🇴'),
    CurrencyInfo(
        code: 'BGN', name: 'Bulgarian Lev', symbol: 'лв', flag: '🇧🇬'),
    CurrencyInfo(
        code: 'HRK', name: 'Croatian Kuna', symbol: 'kn', flag: '🇭🇷'),
    CurrencyInfo(code: 'TRY', name: 'Turkish Lira', symbol: '₺', flag: '🇹🇷'),
    CurrencyInfo(code: 'RUB', name: 'Russian Ruble', symbol: '₽', flag: '🇷🇺'),

    // Middle East & Asia
    CurrencyInfo(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', flag: '🇦🇪'),
    CurrencyInfo(code: 'SAR', name: 'Saudi Riyal', symbol: '﷼', flag: '🇸🇦'),
    CurrencyInfo(
        code: 'ILS', name: 'Israeli Shekel', symbol: '₪', flag: '🇮🇱'),
    CurrencyInfo(code: 'THB', name: 'Thai Baht', symbol: '฿', flag: '🇹🇭'),
    CurrencyInfo(
        code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM', flag: '🇲🇾'),
    CurrencyInfo(
        code: 'IDR', name: 'Indonesian Rupiah', symbol: 'Rp', flag: '🇮🇩'),
    CurrencyInfo(
        code: 'PHP', name: 'Philippine Peso', symbol: '₱', flag: '🇵🇭'),
    CurrencyInfo(
        code: 'VND', name: 'Vietnamese Dong', symbol: '₫', flag: '🇻🇳'),
    CurrencyInfo(
        code: 'KRW', name: 'South Korean Won', symbol: '₩', flag: '🇰🇷'),
    CurrencyInfo(
        code: 'TWD', name: 'Taiwan Dollar', symbol: 'NT\$', flag: '🇹🇼'),

    // South America
    CurrencyInfo(
        code: 'BRL', name: 'Brazilian Real', symbol: 'R\$', flag: '🇧🇷'),
    CurrencyInfo(code: 'MXN', name: 'Mexican Peso', symbol: '\$', flag: '🇲🇽'),
    CurrencyInfo(
        code: 'ARS', name: 'Argentine Peso', symbol: '\$', flag: '🇦🇷'),
    CurrencyInfo(code: 'CLP', name: 'Chilean Peso', symbol: '\$', flag: '🇨🇱'),
    CurrencyInfo(
        code: 'COP', name: 'Colombian Peso', symbol: '\$', flag: '🇨🇴'),
    CurrencyInfo(code: 'PEN', name: 'Peruvian Sol', symbol: 'S/', flag: '🇵🇪'),
  ];

  /// Get currency info by code
  static CurrencyInfo? getCurrencyInfo(String code) {
    try {
      return currencies.firstWhere(
        (currency) => currency.code == code.toUpperCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get currency name by code
  static String getCurrencyName(String code) {
    final info = getCurrencyInfo(code);
    return info?.name ?? code.toUpperCase();
  }

  /// Get currency symbol by code
  static String getCurrencySymbol(String code) {
    final info = getCurrencyInfo(code);
    return info?.symbol ?? code.toUpperCase();
  }

  /// Search currencies by name or code
  static List<CurrencyInfo> searchCurrencies(String query) {
    if (query.isEmpty) return currencies;

    final lowerQuery = query.toLowerCase();
    return currencies.where((currency) {
      return currency.code.toLowerCase().contains(lowerQuery) ||
          currency.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}

class CurrencyInfo {
  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    this.flag,
  });

  final String code;
  final String name;
  final String symbol;
  final String? flag;

  String get displayName =>
      flag != null ? '$flag $name ($code)' : '$name ($code)';
}

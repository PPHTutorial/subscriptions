import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_list.dart';

/// Service for currency conversion with exchange rate caching
class CurrencyConversionService {
  static const String _baseCurrencyKey = 'base_currency';
  static const String _exchangeRatesKey = 'exchange_rates';
  static const String _exchangeRatesTimestampKey = 'exchange_rates_timestamp';

  // Cache exchange rates for 24 hours
  static const Duration _cacheDuration = Duration(hours: 24);

  // Free exchange rate API (no API key required)
  static const String _exchangeRateApiUrl =
      'https://api.exchangerate-api.com/v4/latest/';

  String _baseCurrency = 'USD';
  Map<String, double> _exchangeRates = {};
  DateTime? _lastUpdate;

  CurrencyConversionService() {
    _loadBaseCurrency();
    _loadCachedRates();
  }

  /// Get the user's base currency preference
  String get baseCurrency => _baseCurrency;

  /// Set the user's base currency preference
  Future<void> setBaseCurrency(String currencyCode) async {
    _baseCurrency = currencyCode.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseCurrencyKey, _baseCurrency);
    // Clear cached rates when base currency changes
    await _clearCachedRates();
  }

  /// Load base currency from preferences
  Future<void> _loadBaseCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _baseCurrency = prefs.getString(_baseCurrencyKey)?.toUpperCase() ?? 'USD';
  }

  // Make _loadBaseCurrency accessible for provider
  Future<void> loadBaseCurrency() => _loadBaseCurrency();

  /// Load cached exchange rates from preferences
  Future<void> _loadCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    final ratesJson = prefs.getString(_exchangeRatesKey);
    final timestampStr = prefs.getString(_exchangeRatesTimestampKey);

    if (ratesJson != null && timestampStr != null) {
      try {
        final timestamp = DateTime.parse(timestampStr);
        final now = DateTime.now();

        // Check if cache is still valid
        if (now.difference(timestamp) < _cacheDuration) {
          final rates = jsonDecode(ratesJson) as Map<String, dynamic>;
          _exchangeRates = rates
              .map((key, value) => MapEntry(key, (value as num).toDouble()));
          _lastUpdate = timestamp;
          return;
        }
      } catch (e) {
        // Invalid cache, will fetch fresh rates
      }
    }

    // Cache expired or doesn't exist, fetch fresh rates
    await _fetchExchangeRates();
  }

  /// Fetch exchange rates from API
  Future<void> _fetchExchangeRates() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_exchangeRateApiUrl$_baseCurrency'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>;

        _exchangeRates =
            rates.map((key, value) => MapEntry(key, (value as num).toDouble()));
        _lastUpdate = DateTime.now();

        // Cache the rates
        await _saveCachedRates();
      } else {
        // If API fails, use fallback rates (1:1 for same currency, approximate for others)
        _useFallbackRates();
      }
    } catch (e) {
      // Network error or timeout, use fallback rates
      _useFallbackRates();
    }
  }

  /// Use fallback exchange rates when API is unavailable
  void _useFallbackRates() {
    // Common approximate exchange rates (fallback only)
    // These are rough estimates and should be updated regularly
    final fallbackRates = {
      'USD': 1.0,
      'EUR': 0.92,
      'GBP': 0.79,
      'INR': 83.0,
      'GHS': 12.0,
      'NGN': 1500.0,
      'ZAR': 18.5,
      'KES': 130.0,
      'UGX': 3700.0,
      'TZS': 2300.0,
      'RWF': 1300.0,
      'ETB': 55.0,
      'CAD': 1.35,
      'AUD': 1.52,
      'NZD': 1.65,
      'JPY': 150.0,
      'CNY': 7.2,
      'SGD': 1.34,
      'HKD': 7.8,
      'CHF': 0.88,
      'SEK': 10.5,
      'NOK': 10.8,
      'DKK': 6.85,
      'PLN': 4.0,
      'CZK': 23.0,
      'HUF': 360.0,
      'RON': 4.6,
      'BGN': 1.8,
      'HRK': 7.0,
    };

    // Convert fallback rates to base currency
    if (_baseCurrency == 'USD') {
      _exchangeRates = fallbackRates;
    } else {
      final baseRate = fallbackRates[_baseCurrency] ?? 1.0;
      _exchangeRates =
          fallbackRates.map((key, value) => MapEntry(key, value / baseRate));
    }

    _lastUpdate = DateTime.now();
  }

  /// Save exchange rates to cache
  Future<void> _saveCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_exchangeRatesKey, jsonEncode(_exchangeRates));
    await prefs.setString(
        _exchangeRatesTimestampKey, _lastUpdate!.toIso8601String());
  }

  /// Clear cached exchange rates
  Future<void> _clearCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_exchangeRatesKey);
    await prefs.remove(_exchangeRatesTimestampKey);
    _exchangeRates.clear();
    _lastUpdate = null;
  }

  /// Convert amount from source currency to base currency
  /// Returns the converted amount in base currency
  Future<double> convertToBase({
    required double amount,
    required String fromCurrency,
  }) async {
    // If already in base currency, no conversion needed
    if (fromCurrency.toUpperCase() == _baseCurrency) {
      return amount;
    }

    // Ensure we have exchange rates
    if (_exchangeRates.isEmpty || _shouldRefreshRates()) {
      await _fetchExchangeRates();
    }

    final fromCurrencyUpper = fromCurrency.toUpperCase();
    final fromRate = _exchangeRates[fromCurrencyUpper];

    if (fromRate == null) {
      // Currency not found in rates, return original amount
      // This prevents over/under-population due to missing rates
      return amount;
    }

    // Convert: amount in fromCurrency * (1 / fromRate) = amount in baseCurrency
    // Since rates are relative to base currency
    return amount / fromRate;
  }

  /// Convert amount from base currency to target currency
  Future<double> convertFromBase({
    required double amount,
    required String toCurrency,
  }) async {
    // If already in base currency, no conversion needed
    if (toCurrency.toUpperCase() == _baseCurrency) {
      return amount;
    }

    // Ensure we have exchange rates
    if (_exchangeRates.isEmpty || _shouldRefreshRates()) {
      await _fetchExchangeRates();
    }

    final toCurrencyUpper = toCurrency.toUpperCase();
    final toRate = _exchangeRates[toCurrencyUpper];

    if (toRate == null) {
      // Currency not found in rates, return original amount
      return amount;
    }

    // Convert: amount in baseCurrency * toRate = amount in toCurrency
    return amount * toRate;
  }

  /// Convert amount from one currency to another
  Future<double> convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    // If same currency, no conversion needed
    if (fromCurrency.toUpperCase() == toCurrency.toUpperCase()) {
      return amount;
    }

    // Convert to base currency first, then to target currency
    final baseAmount = await convertToBase(
      amount: amount,
      fromCurrency: fromCurrency,
    );

    return await convertFromBase(
      amount: baseAmount,
      toCurrency: toCurrency,
    );
  }

  /// Check if exchange rates should be refreshed
  bool _shouldRefreshRates() {
    if (_lastUpdate == null) return true;
    return DateTime.now().difference(_lastUpdate!) >= _cacheDuration;
  }

  /// Get exchange rate for a currency (relative to base currency)
  double? getExchangeRate(String currencyCode) {
    return _exchangeRates[currencyCode.toUpperCase()];
  }

  /// Refresh exchange rates manually
  Future<void> refreshRates() async {
    await _clearCachedRates();
    await _fetchExchangeRates();
  }

  /// Format currency amount with proper symbol/formatting
  String formatCurrency({
    required double amount,
    required String currencyCode,
  }) {
    final code = currencyCode.toUpperCase();
    final formattedAmount = amount.toStringAsFixed(2);

    // Get currency info from CurrencyList for proper symbol
    final currencyInfo = CurrencyList.getCurrencyInfo(code);

    if (currencyInfo != null) {
      // Use the symbol from CurrencyList
      return '${currencyInfo.symbol}$formattedAmount';
    }

    // Fallback: show currency code if symbol not found
    return '$code $formattedAmount';
  }
}

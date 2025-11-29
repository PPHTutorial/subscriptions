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
      // Always fetch USD rates first to ensure USD is available
      final usdResponse = await http
          .get(
            Uri.parse('${_exchangeRateApiUrl}USD'),
          )
          .timeout(const Duration(seconds: 10));

      if (usdResponse.statusCode == 200) {
        final usdData = jsonDecode(usdResponse.body) as Map<String, dynamic>;
        final usdRates = usdData['rates'] as Map<String, dynamic>;

        // If base currency is USD, use USD rates directly
        if (_baseCurrency == 'USD') {
          _exchangeRates = usdRates
              .map((key, value) => MapEntry(key, (value as num).toDouble()));
          // Ensure USD is always 1.0
          _exchangeRates['USD'] = 1.0;
        } else {
          // Base currency is not USD, fetch rates for base currency
          final baseResponse = await http
              .get(
                Uri.parse('$_exchangeRateApiUrl$_baseCurrency'),
              )
              .timeout(const Duration(seconds: 10));

          if (baseResponse.statusCode == 200) {
            final baseData =
                jsonDecode(baseResponse.body) as Map<String, dynamic>;
            final baseRates = baseData['rates'] as Map<String, dynamic>;

            _exchangeRates = baseRates
                .map((key, value) => MapEntry(key, (value as num).toDouble()));
            // Ensure base currency is always 1.0
            _exchangeRates[_baseCurrency] = 1.0;

            // Calculate USD rate from base currency
            // If base currency rate to USD is available, use it
            // Otherwise, calculate from USD rates
            final baseToUsd = _exchangeRates['USD'];
            if (baseToUsd != null && baseToUsd > 0) {
              // USD rate is already in the base currency rates
              // No additional calculation needed
            } else {
              // Calculate USD rate from USD rates
              // Get base currency rate from USD rates
              final baseFromUsd = usdRates[_baseCurrency];
              if (baseFromUsd != null && baseFromUsd > 0) {
                // 1 USD = baseFromUsd baseCurrency
                // So 1 baseCurrency = 1 / baseFromUsd USD
                // But we need: 1 USD = ? baseCurrency
                // Actually: 1 USD = baseFromUsd baseCurrency
                _exchangeRates['USD'] = baseFromUsd;
              }
            }
          } else {
            // Fallback: calculate from USD rates
            final baseFromUsd = usdRates[_baseCurrency];
            if (baseFromUsd != null && baseFromUsd > 0) {
              // Convert all USD rates to base currency rates
              _exchangeRates = usdRates.map((key, value) {
                final usdRate = (value as num).toDouble();
                // If key is base currency, it's 1.0
                if (key == _baseCurrency) {
                  return MapEntry(key, 1.0);
                }
                // Convert: 1 USD = baseFromUsd baseCurrency
                // So 1 keyCurrency = (usdRate / baseFromUsd) baseCurrency
                return MapEntry(key, usdRate / baseFromUsd);
              });
              // Ensure USD is available
              _exchangeRates['USD'] = baseFromUsd;
            } else {
              _useFallbackRates();
              return;
            }
          }
        }

        _lastUpdate = DateTime.now();
        // Cache the rates
        await _saveCachedRates();
      } else {
        // If API fails, use fallback rates
        _useFallbackRates();
      }
    } catch (e) {
      // Network error or timeout, use fallback rates
      _useFallbackRates();
    }
  }

  /// Use fallback exchange rates when API is unavailable
  void _useFallbackRates() {
    // Common approximate exchange rates relative to USD (fallback only)
    // These are rough estimates and should be updated regularly
    // Format: 1 USD = X currency
    final usdRates = {
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

    // Convert USD rates to base currency rates
    if (_baseCurrency == 'USD') {
      _exchangeRates = usdRates;
    } else {
      final baseFromUsd = usdRates[_baseCurrency] ?? 1.0;
      // Convert all rates: 1 baseCurrency = (usdRate / baseFromUsd) currency
      _exchangeRates = usdRates.map((key, value) {
        if (key == _baseCurrency) {
          return MapEntry(key, 1.0);
        }
        // 1 USD = value currency
        // 1 USD = baseFromUsd baseCurrency
        // So 1 baseCurrency = value / baseFromUsd currency
        return MapEntry(key, value / baseFromUsd);
      });
      // Ensure USD is always available
      _exchangeRates['USD'] = baseFromUsd;
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
  ///
  /// Exchange rates from the API are stored as: 1 baseCurrency = X currency
  /// This means the rate tells us how many units of 'currency' equal 1 unit of baseCurrency.
  ///
  /// To convert fromCurrency to baseCurrency:
  /// - If fromCurrency rate is R (meaning 1 baseCurrency = R fromCurrency)
  /// - Then: amount in fromCurrency / R = amount in baseCurrency
  ///
  /// Examples:
  /// 1. Base = USD, fromCurrency = GHS, amount = 60 GHS
  ///    - Rate GHS = 12.0 (1 USD = 12 GHS)
  ///    - Conversion: 60 / 12 = 5 USD ✓
  ///
  /// 2. Base = GHS, fromCurrency = USD, amount = 5 USD
  ///    - When fetching rates for base=GHS, API returns: 1 GHS = 0.083 USD
  ///    - So rate USD = 0.083 (meaning 1 GHS = 0.083 USD)
  ///    - To convert 5 USD to GHS: 5 / 0.083 = 60.24 GHS ✓
  ///    - (Alternatively: 1 USD = 1/0.083 = 12 GHS, so 5 USD = 5 * 12 = 60 GHS)
  ///
  /// The formula `amount / fromRate` works correctly because:
  /// - Rates are always stored relative to baseCurrency
  /// - If rate R means "1 baseCurrency = R fromCurrency"
  /// - Then "amount fromCurrency = amount / R baseCurrency"
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

    // Exchange rates are stored as: 1 baseCurrency = X fromCurrency
    // So to convert: amount in fromCurrency / rate = amount in baseCurrency
    // Example: 60 GHS / 12.0 (1 USD = 12 GHS) = 5 USD
    // Example: 5 USD / 0.083 (1 GHS = 0.083 USD) = 60.24 GHS
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
  /// Uses K for thousands and M for millions
  String formatCurrency({
    required double amount,
    required String currencyCode,
  }) {
    final code = currencyCode.toUpperCase();

    // Format amount with K/M suffixes
    String formattedAmount;
    if (amount >= 1000000) {
      // Millions
      final millions = amount / 1000000;
      formattedAmount = millions.toStringAsFixed(millions >= 10 ? 0 : 1);
      formattedAmount = formattedAmount.replaceAll(RegExp(r'\.0$'), '');
      formattedAmount = '${formattedAmount}M';
    } else if (amount >= 1000) {
      // Thousands
      final thousands = amount / 1000;
      formattedAmount = thousands.toStringAsFixed(thousands >= 10 ? 0 : 1);
      formattedAmount = formattedAmount.replaceAll(RegExp(r'\.0$'), '');
      formattedAmount = '${formattedAmount}K';
    } else {
      // Less than 1000, show with 2 decimal places
      formattedAmount = amount.toStringAsFixed(2);
      formattedAmount = formattedAmount.replaceAll(RegExp(r'\.0+$'), '');
    }

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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'currency_conversion_service.dart';

/// Provider for currency conversion service
final currencyConversionServiceProvider =
    Provider<CurrencyConversionService>((ref) {
  return CurrencyConversionService();
});

/// Provider for base currency preference
final baseCurrencyProvider =
    StateNotifierProvider<BaseCurrencyNotifier, String>((ref) {
  return BaseCurrencyNotifier(ref.read(currencyConversionServiceProvider));
});

class BaseCurrencyNotifier extends StateNotifier<String> {
  final CurrencyConversionService _service;

  BaseCurrencyNotifier(this._service) : super('USD') {
    _loadBaseCurrency();
  }

  Future<void> _loadBaseCurrency() async {
    await _service.loadBaseCurrency();
    state = _service.baseCurrency;
  }

  Future<void> setBaseCurrency(String currencyCode) async {
    await _service.setBaseCurrency(currencyCode);
    state = currencyCode.toUpperCase();
  }
}

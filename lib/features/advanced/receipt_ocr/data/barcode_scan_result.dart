/// Result from scanning a barcode/QR code
class BarcodeScanResult {
  BarcodeScanResult({
    required this.type,
    required this.rawData,
    this.url,
    this.parsedData,
    this.jsonData,
    this.subscriptionInfo,
  });

  final BarcodeScanType type;
  final String rawData;
  final String? url;
  final Map<String, String>? parsedData;
  final String? jsonData;
  final Map<String, dynamic>? subscriptionInfo;
}

enum BarcodeScanType {
  url,
  json,
  structured,
  text,
}

enum EmailProvider {
  gmail,
  outlook,
  yahoo,
  icloud,
  protonmail,
  custom,
}

extension EmailProviderExtension on EmailProvider {
  String get name {
    switch (this) {
      case EmailProvider.gmail:
        return 'Gmail Server';
      case EmailProvider.outlook:
        return 'Outlook Server';
      case EmailProvider.yahoo:
        return 'Yahoo Server';
      case EmailProvider.icloud:
        return 'iCloud Mail';
      case EmailProvider.protonmail:
        return 'ProtonMail';
      case EmailProvider.custom:
        return 'Custom Server';
    }
  }

  String get iconAsset {
    switch (this) {
      case EmailProvider.gmail:
        return 'assets/icons/gmail.svg';
      case EmailProvider.outlook:
        return 'assets/icons/outlook.svg';
      case EmailProvider.yahoo:
        return 'assets/icons/yahoo.svg';
      case EmailProvider.icloud:
        return 'assets/icons/icloud.svg';
      case EmailProvider.protonmail:
        return 'assets/icons/protonmail.svg';
      case EmailProvider.custom:
        return 'assets/icons/custom.svg';
    }
  }
}

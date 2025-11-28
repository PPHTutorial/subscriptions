enum EmailProvider {
  gmail,
  outlook,
}

extension EmailProviderExtension on EmailProvider {
  String get name {
    switch (this) {
      case EmailProvider.gmail:
        return 'Gmail';
      case EmailProvider.outlook:
        return 'Outlook';
    }
  }

  String get icon {
    switch (this) {
      case EmailProvider.gmail:
        return '📧';
      case EmailProvider.outlook:
        return '📬';
    }
  }
}

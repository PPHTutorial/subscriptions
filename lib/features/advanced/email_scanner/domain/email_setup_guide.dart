import '../domain/email_provider.dart';

/// Model for email setup instructions
class EmailSetupStep {
  final int stepNumber;
  final String title;
  final String description;
  final List<String>? subSteps;
  final String? url;

  const EmailSetupStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.subSteps,
    this.url,
  });
}

class EmailSetupGuide {
  final EmailProvider provider;
  final String overview;
  final List<EmailSetupStep> steps;
  final String? appPasswordUrl;
  final Map<String, String>? serverSettings;

  const EmailSetupGuide({
    required this.provider,
    required this.overview,
    required this.steps,
    this.appPasswordUrl,
    this.serverSettings,
  });

  /// Get setup guide for a specific email provider
  static EmailSetupGuide getGuide(EmailProvider provider) {
    switch (provider) {
      case EmailProvider.gmail:
        return _gmailGuide;
      case EmailProvider.outlook:
        return _outlookGuide;
      case EmailProvider.yahoo:
        return _yahooGuide;
      case EmailProvider.icloud:
        return _icloudGuide;
      case EmailProvider.protonmail:
        return _protonmailGuide;
      case EmailProvider.custom:
        return _customGuide;
    }
  }

  static const _gmailGuide = EmailSetupGuide(
    provider: EmailProvider.gmail,
    overview:
        'To use Gmail with this app, you need to enable 2-Step Verification and create an App Password. Your regular Gmail password will not work.',
    appPasswordUrl: 'https://myaccount.google.com/apppasswords',
    serverSettings: {
      'IMAP Server': 'imap.gmail.com',
      'IMAP Port': '993',
      'Security': 'SSL/TLS',
    },
    steps: [
      EmailSetupStep(
        stepNumber: 1,
        title: 'Enable 2-Step Verification',
        description:
            'Go to your Google Account settings and enable 2-Step Verification if you haven\'t already.',
        subSteps: [
          'Visit https://myaccount.google.com/security',
          'Click on "2-Step Verification"',
          'Follow the prompts to enable it',
          'You\'ll need your phone for verification',
        ],
        url: 'https://myaccount.google.com/security',
      ),
      EmailSetupStep(
        stepNumber: 2,
        title: 'Create an App Password',
        description:
            'Generate a 16-character app password specifically for this app. This is different from your regular Gmail password.',
        subSteps: [
          'Go to https://myaccount.google.com/apppasswords',
          'Sign in if prompted',
          'Select "Mail" as the app',
          'Select "Other (Custom name)" as the device',
          'Enter "Subscription Manager" as the name',
          'Click "Generate"',
          'Copy the 16-character password (no spaces)',
        ],
        url: 'https://myaccount.google.com/apppasswords',
      ),
      EmailSetupStep(
        stepNumber: 3,
        title: 'Enter Your Credentials',
        description:
            'In this app, enter your Gmail address and the 16-character app password you just created.',
        subSteps: [
          'Email: Your full Gmail address (e.g., yourname@gmail.com)',
          'Password: The 16-character app password (not your regular password)',
          'Click "Connect" to test the connection',
        ],
      ),
    ],
  );

  static const _outlookGuide = EmailSetupGuide(
    provider: EmailProvider.outlook,
    overview:
        'To use Outlook/Hotmail with this app, you need to enable 2-Step Verification and create an App Password.',
    appPasswordUrl: 'https://account.microsoft.com/security',
    serverSettings: {
      'IMAP Server': 'outlook.office365.com',
      'IMAP Port': '993',
      'Security': 'SSL/TLS',
    },
    steps: [
      EmailSetupStep(
        stepNumber: 1,
        title: 'Enable 2-Step Verification',
        description:
            'Go to your Microsoft Account security settings and enable 2-Step Verification.',
        subSteps: [
          'Visit https://account.microsoft.com/security',
          'Click on "Advanced security options"',
          'Under "Two-step verification", click "Turn on"',
          'Follow the prompts to set it up',
        ],
        url: 'https://account.microsoft.com/security',
      ),
      EmailSetupStep(
        stepNumber: 2,
        title: 'Create an App Password',
        description:
            'Generate an app password for this app. This is different from your regular Outlook password.',
        subSteps: [
          'Go to https://account.microsoft.com/security',
          'Click on "Advanced security options"',
          'Under "App passwords", click "Create a new app password"',
          'Enter "Subscription Manager" as the app name',
          'Click "Generate"',
          'Copy the 16-character password shown',
        ],
        url: 'https://account.microsoft.com/security',
      ),
      EmailSetupStep(
        stepNumber: 3,
        title: 'Enter Your Credentials',
        description:
            'In this app, enter your Outlook email address and the app password you just created.',
        subSteps: [
          'Email: Your full Outlook address (e.g., yourname@outlook.com)',
          'Password: The app password you generated',
          'Click "Connect" to test the connection',
        ],
      ),
    ],
  );

  static const _yahooGuide = EmailSetupGuide(
    provider: EmailProvider.yahoo,
    overview:
        'To use Yahoo Mail with this app, you need to enable 2-Step Verification and create an App Password.',
    appPasswordUrl: 'https://login.yahoo.com/account/security',
    serverSettings: {
      'IMAP Server': 'imap.mail.yahoo.com',
      'IMAP Port': '993',
      'Security': 'SSL/TLS',
    },
    steps: [
      EmailSetupStep(
        stepNumber: 1,
        title: 'Enable 2-Step Verification',
        description:
            'Go to your Yahoo Account security settings and enable 2-Step Verification.',
        subSteps: [
          'Visit https://login.yahoo.com/account/security',
          'Sign in to your Yahoo account',
          'Scroll to "Two-step verification"',
          'Click "Turn on" or "Manage"',
          'Follow the prompts to enable it',
        ],
        url: 'https://login.yahoo.com/account/security',
      ),
      EmailSetupStep(
        stepNumber: 2,
        title: 'Generate an App Password',
        description:
            'Create an app-specific password for this app. This is different from your regular Yahoo password.',
        subSteps: [
          'Go to https://login.yahoo.com/account/security',
          'Scroll to "App passwords" or "Generate app password"',
          'Click "Generate app password"',
          'Enter "Subscription Manager" as the app name',
          'Click "Generate"',
          'Copy the password shown (it may be formatted with spaces - remove them)',
        ],
        url: 'https://login.yahoo.com/account/security',
      ),
      EmailSetupStep(
        stepNumber: 3,
        title: 'Enter Your Credentials',
        description:
            'In this app, enter your Yahoo email address and the app password you just created.',
        subSteps: [
          'Email: Your full Yahoo address (e.g., yourname@yahoo.com)',
          'Password: The app password you generated',
          'Click "Connect" to test the connection',
        ],
      ),
    ],
  );

  static const _icloudGuide = EmailSetupGuide(
    provider: EmailProvider.icloud,
    overview:
        'To use iCloud Mail with this app, you need to enable 2-Factor Authentication and create an App-Specific Password.',
    appPasswordUrl: 'https://appleid.apple.com/account/manage',
    serverSettings: {
      'IMAP Server': 'imap.mail.me.com',
      'IMAP Port': '993',
      'Security': 'SSL/TLS',
    },
    steps: [
      EmailSetupStep(
        stepNumber: 1,
        title: 'Enable 2-Factor Authentication',
        description:
            'Make sure 2-Factor Authentication is enabled on your Apple ID.',
        subSteps: [
          'Go to https://appleid.apple.com/account/manage',
          'Sign in with your Apple ID',
          'Check if "Two-Factor Authentication" is enabled',
          'If not, go to Settings on your iPhone/iPad/Mac to enable it',
        ],
        url: 'https://appleid.apple.com/account/manage',
      ),
      EmailSetupStep(
        stepNumber: 2,
        title: 'Generate an App-Specific Password',
        description:
            'Create an app-specific password for this app. This is different from your Apple ID password.',
        subSteps: [
          'Go to https://appleid.apple.com/account/manage',
          'Sign in with your Apple ID',
          'In the "Security" section, find "App-Specific Passwords"',
          'Click "Generate Password"',
          'Enter "Subscription Manager" as the label',
          'Click "Create"',
          'Copy the password shown (it will be formatted like: xxxx-xxxx-xxxx-xxxx)',
        ],
        url: 'https://appleid.apple.com/account/manage',
      ),
      EmailSetupStep(
        stepNumber: 3,
        title: 'Enter Your Credentials',
        description:
            'In this app, enter your iCloud email address and the app-specific password you just created.',
        subSteps: [
          'Email: Your full iCloud address (e.g., yourname@icloud.com)',
          'Password: The app-specific password (format: xxxx-xxxx-xxxx-xxxx)',
          'Click "Connect" to test the connection',
        ],
      ),
    ],
  );

  static const _protonmailGuide = EmailSetupGuide(
    provider: EmailProvider.protonmail,
    overview:
        'ProtonMail requires a Bridge application for IMAP access. You need to install ProtonMail Bridge and use its credentials.',
    appPasswordUrl: 'https://proton.me/mail/bridge',
    serverSettings: {
      'IMAP Server': '127.0.0.1',
      'IMAP Port': '1143',
      'Security': 'None (Bridge handles encryption)',
      'Note': 'Requires ProtonMail Bridge installed on your computer',
    },
    steps: [
      EmailSetupStep(
        stepNumber: 1,
        title: 'Install ProtonMail Bridge',
        description:
            'Download and install ProtonMail Bridge on your computer. This is required for IMAP access.',
        subSteps: [
          'Go to https://proton.me/mail/bridge',
          'Download ProtonMail Bridge for your operating system',
          'Install the application',
          'Launch ProtonMail Bridge',
        ],
        url: 'https://proton.me/mail/bridge',
      ),
      EmailSetupStep(
        stepNumber: 2,
        title: 'Sign In to ProtonMail Bridge',
        description:
            'Sign in to ProtonMail Bridge with your ProtonMail account credentials.',
        subSteps: [
          'Open ProtonMail Bridge',
          'Sign in with your ProtonMail email and password',
          'Complete 2FA if enabled',
          'Bridge will generate IMAP credentials for you',
        ],
      ),
      EmailSetupStep(
        stepNumber: 3,
        title: 'Get Bridge Credentials',
        description: 'Copy the IMAP credentials shown in ProtonMail Bridge.',
        subSteps: [
          'In ProtonMail Bridge, go to "Settings" or "Account"',
          'Find the IMAP/SMTP settings',
          'Copy the username (usually your email)',
          'Copy the password (this is a Bridge-generated password, not your ProtonMail password)',
        ],
      ),
      EmailSetupStep(
        stepNumber: 4,
        title: 'Enter Your Credentials',
        description:
            'In this app, enter the Bridge credentials. Make sure ProtonMail Bridge is running.',
        subSteps: [
          'Email: Your ProtonMail address (e.g., yourname@protonmail.com)',
          'Password: The Bridge-generated password (from step 3)',
          'IMAP Server: 127.0.0.1 (localhost)',
          'IMAP Port: 1143',
          'Make sure ProtonMail Bridge is running on your computer',
          'Click "Connect" to test the connection',
        ],
      ),
    ],
  );

  static const _customGuide = EmailSetupGuide(
    provider: EmailProvider.custom,
    overview:
        'For custom email servers, you need to obtain IMAP settings and an app password from your email provider or IT administrator.',
    serverSettings: {
      'IMAP Server': 'Contact your email provider',
      'IMAP Port': 'Usually 993 (SSL) or 143 (TLS)',
      'Security': 'SSL/TLS recommended',
    },
    steps: [
      EmailSetupStep(
        stepNumber: 1,
        title: 'Contact Your Email Provider',
        description:
            'Get the IMAP server settings from your email provider or IT administrator.',
        subSteps: [
          'Contact your email hosting provider',
          'Ask for IMAP server settings',
          'Get the IMAP server address (e.g., imap.example.com)',
          'Get the IMAP port (usually 993 for SSL or 143 for TLS)',
          'Ask if SSL/TLS is required',
        ],
      ),
      EmailSetupStep(
        stepNumber: 2,
        title: 'Get App Password or Enable IMAP',
        description:
            'Some providers require app passwords, while others may need IMAP enabled in account settings.',
        subSteps: [
          'Check if your provider requires app passwords',
          'If yes, generate an app password in your account settings',
          'If no, ensure IMAP is enabled in your email account settings',
          'Some providers may require enabling "Less secure app access"',
        ],
      ),
      EmailSetupStep(
        stepNumber: 3,
        title: 'Enter Your Credentials',
        description:
            'In this app, enter your email address, password, and IMAP server settings.',
        subSteps: [
          'Email: Your full email address',
          'Password: Your email password or app password',
          'IMAP Server: The server address from your provider',
          'IMAP Port: Usually 993 (SSL) or 143 (TLS)',
          'Enable SSL if your provider requires it',
          'Click "Connect" to test the connection',
        ],
      ),
      EmailSetupStep(
        stepNumber: 4,
        title: 'Common Custom Server Examples',
        description: 'Here are some common custom email server configurations:',
        subSteps: [
          'Titan Email: imap.titan.email, Port 993, SSL enabled',
          'Zoho Mail: imap.zoho.com, Port 993, SSL enabled',
          'FastMail: imap.fastmail.com, Port 993, SSL enabled',
          'Check your provider\'s documentation for exact settings',
        ],
      ),
    ],
  );
}

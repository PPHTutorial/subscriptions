import '../../../subscriptions/domain/subscription.dart';

/// Comprehensive rule-based dataset for subscription insights
/// This dataset provides patterns, alternatives, and recommendations
/// to enhance AI-powered insights generation
class InsightsDataset {
  /// Service name patterns and their categories
  static const Map<String, SubscriptionCategory> serviceCategories = {
    // Entertainment - Streaming
    'netflix': SubscriptionCategory.entertainment,
    'spotify': SubscriptionCategory.entertainment,
    'disney': SubscriptionCategory.entertainment,
    'hulu': SubscriptionCategory.entertainment,
    'hbo': SubscriptionCategory.entertainment,
    'max': SubscriptionCategory.entertainment,
    'paramount': SubscriptionCategory.entertainment,
    'peacock': SubscriptionCategory.entertainment,
    'apple tv': SubscriptionCategory.entertainment,
    'apple music': SubscriptionCategory.entertainment,
    'youtube premium': SubscriptionCategory.entertainment,
    'youtube music': SubscriptionCategory.entertainment,
    'amazon prime': SubscriptionCategory.entertainment,
    'prime video': SubscriptionCategory.entertainment,
    'twitch': SubscriptionCategory.entertainment,
    'crunchyroll': SubscriptionCategory.entertainment,
    'funimation': SubscriptionCategory.entertainment,
    'vudu': SubscriptionCategory.entertainment,
    'fubo': SubscriptionCategory.entertainment,
    'sling': SubscriptionCategory.entertainment,
    'directv': SubscriptionCategory.entertainment,
    'pandora': SubscriptionCategory.entertainment,
    'tidal': SubscriptionCategory.entertainment,
    'deezer': SubscriptionCategory.entertainment,
    'soundcloud': SubscriptionCategory.entertainment,
    'audible': SubscriptionCategory.entertainment,
    'kindle unlimited': SubscriptionCategory.entertainment,

    // Productivity
    'microsoft 365': SubscriptionCategory.productivity,
    'microsoft office': SubscriptionCategory.productivity,
    'office 365': SubscriptionCategory.productivity,
    'google workspace': SubscriptionCategory.productivity,
    'g suite': SubscriptionCategory.productivity,
    'adobe creative cloud': SubscriptionCategory.productivity,
    'adobe': SubscriptionCategory.productivity,
    'notion': SubscriptionCategory.productivity,
    'evernote': SubscriptionCategory.productivity,
    'onenote': SubscriptionCategory.productivity,
    'dropbox': SubscriptionCategory.productivity,
    'box': SubscriptionCategory.productivity,
    'onedrive': SubscriptionCategory.productivity,
    'google drive': SubscriptionCategory.productivity,
    'icloud': SubscriptionCategory.productivity,
    'slack': SubscriptionCategory.productivity,
    'zoom': SubscriptionCategory.productivity,
    'teams': SubscriptionCategory.productivity,
    'asana': SubscriptionCategory.productivity,
    'trello': SubscriptionCategory.productivity,
    'monday': SubscriptionCategory.productivity,
    'jira': SubscriptionCategory.productivity,
    'confluence': SubscriptionCategory.productivity,
    'figma': SubscriptionCategory.productivity,
    'sketch': SubscriptionCategory.productivity,
    'canva': SubscriptionCategory.productivity,
    'grammarly': SubscriptionCategory.productivity,
    'lastpass': SubscriptionCategory.productivity,
    '1password': SubscriptionCategory.productivity,
    'dashlane': SubscriptionCategory.productivity,
    'nordvpn': SubscriptionCategory.productivity,
    'expressvpn': SubscriptionCategory.productivity,
    'surfshark': SubscriptionCategory.productivity,

    // Finance
    'mint': SubscriptionCategory.finance,
    'quickbooks': SubscriptionCategory.finance,
    'xero': SubscriptionCategory.finance,
    'freshbooks': SubscriptionCategory.finance,
    'wave': SubscriptionCategory.finance,
    'ynab': SubscriptionCategory.finance,
    'you need a budget': SubscriptionCategory.finance,
    'pocketguard': SubscriptionCategory.finance,
    'truebill': SubscriptionCategory.finance,
    'robinhood': SubscriptionCategory.finance,
    'coinbase': SubscriptionCategory.finance,
    'paypal': SubscriptionCategory.finance,
    'stripe': SubscriptionCategory.finance,

    // Utilities
    'aws': SubscriptionCategory.utilities,
    'amazon web services': SubscriptionCategory.utilities,
    'azure': SubscriptionCategory.utilities,
    'google cloud': SubscriptionCategory.utilities,
    'heroku': SubscriptionCategory.utilities,
    'digitalocean': SubscriptionCategory.utilities,
    'linode': SubscriptionCategory.utilities,
    'vultr': SubscriptionCategory.utilities,
    'github': SubscriptionCategory.utilities,
    'gitlab': SubscriptionCategory.utilities,
    'bitbucket': SubscriptionCategory.utilities,
    'vercel': SubscriptionCategory.utilities,
    'netlify': SubscriptionCategory.utilities,
    'cloudflare': SubscriptionCategory.utilities,
    'namecheap': SubscriptionCategory.utilities,
    'godaddy': SubscriptionCategory.utilities,

    // Education
    'coursera': SubscriptionCategory.education,
    'udemy': SubscriptionCategory.education,
    'skillshare': SubscriptionCategory.education,
    'linkedin learning': SubscriptionCategory.education,
    'lynda': SubscriptionCategory.education,
    'masterclass': SubscriptionCategory.education,
    'khan academy': SubscriptionCategory.education,
    'duolingo': SubscriptionCategory.education,
    'babbel': SubscriptionCategory.education,
    'rosetta stone': SubscriptionCategory.education,

    // Health
    'calm': SubscriptionCategory.health,
    'headspace': SubscriptionCategory.health,
    'myfitnesspal': SubscriptionCategory.health,
    'noom': SubscriptionCategory.health,
    'weight watchers': SubscriptionCategory.health,
    'ww': SubscriptionCategory.health,
    'strava': SubscriptionCategory.health,
    'peloton': SubscriptionCategory.health,
    'fitbit': SubscriptionCategory.health,
    'whoop': SubscriptionCategory.health,

    // African & Ghana-specific Services
    // Mobile Money & Financial Services
    'mtn mobile money': SubscriptionCategory.finance,
    'mtn momo': SubscriptionCategory.finance,
    'vodafone cash': SubscriptionCategory.finance,
    'airteltigo money': SubscriptionCategory.finance,
    'm-pesa': SubscriptionCategory.finance,
    'orange money': SubscriptionCategory.finance,
    'ecocash': SubscriptionCategory.finance,
    'tigo pesa': SubscriptionCategory.finance,
    'moov money': SubscriptionCategory.finance,
    'chipper cash': SubscriptionCategory.finance,
    'opay': SubscriptionCategory.finance,
    'palmpay': SubscriptionCategory.finance,
    'flutterwave': SubscriptionCategory.finance,
    'paystack': SubscriptionCategory.finance,
    'interswitch': SubscriptionCategory.finance,

    // African Telecoms
    'mtn': SubscriptionCategory.utilities,
    'vodafone': SubscriptionCategory.utilities,
    'airteltigo': SubscriptionCategory.utilities,
    'safaricom': SubscriptionCategory.utilities,
    'orange': SubscriptionCategory.utilities,
    'tigo': SubscriptionCategory.utilities,
    'airtel': SubscriptionCategory.utilities,
    'glo': SubscriptionCategory.utilities,
    'etisalat': SubscriptionCategory.utilities,
    'telkom': SubscriptionCategory.utilities,
    'cell c': SubscriptionCategory.utilities,

    // African Streaming Services
    'showmax': SubscriptionCategory.entertainment,
    'dstv': SubscriptionCategory.entertainment,
    'dstv now': SubscriptionCategory.entertainment,
    'gotv': SubscriptionCategory.entertainment,
    'startimes': SubscriptionCategory.entertainment,
    'irokotv': SubscriptionCategory.entertainment,
    'africa magic': SubscriptionCategory.entertainment,
    'multichoice': SubscriptionCategory.entertainment,
    'supersport': SubscriptionCategory.entertainment,
    'bounce': SubscriptionCategory.entertainment,
    'afrostream': SubscriptionCategory.entertainment,
    'kwese': SubscriptionCategory.entertainment,

    // Additional Hosting Services
    'hostinger': SubscriptionCategory.utilities,
    'bluehost': SubscriptionCategory.utilities,
    'siteground': SubscriptionCategory.utilities,
    'hostgator': SubscriptionCategory.utilities,
    'a2 hosting': SubscriptionCategory.utilities,
    'inmotion hosting': SubscriptionCategory.utilities,
    'dreamhost': SubscriptionCategory.utilities,
    'wp engine': SubscriptionCategory.utilities,
    'kinsta': SubscriptionCategory.utilities,
    'flywheel': SubscriptionCategory.utilities,
    'pantheon': SubscriptionCategory.utilities,
    'acquia': SubscriptionCategory.utilities,
    'ovh': SubscriptionCategory.utilities,
    'hetzner': SubscriptionCategory.utilities,
    'contabo': SubscriptionCategory.utilities,
    'ionos': SubscriptionCategory.utilities,
    '1&1': SubscriptionCategory.utilities,
    'scaleway': SubscriptionCategory.utilities,
    'ovhcloud': SubscriptionCategory.utilities,
    'rackspace': SubscriptionCategory.utilities,
    'akamai': SubscriptionCategory.utilities,
    'fastly': SubscriptionCategory.utilities,
    'bunnycdn': SubscriptionCategory.utilities,
    'keycdn': SubscriptionCategory.utilities,
    'stackpath': SubscriptionCategory.utilities,
    'cloudfront': SubscriptionCategory.utilities,

    // Additional Domain & DNS Services
    'name.com': SubscriptionCategory.utilities,
    'namesilo': SubscriptionCategory.utilities,
    'porkbun': SubscriptionCategory.utilities,
    'hover': SubscriptionCategory.utilities,
    'dynadot': SubscriptionCategory.utilities,
    'register.com': SubscriptionCategory.utilities,
    '1&1 ionos': SubscriptionCategory.utilities,
    'cloudflare dns': SubscriptionCategory.utilities,
    'route 53': SubscriptionCategory.utilities,
    'dnsimple': SubscriptionCategory.utilities,
    'dyn': SubscriptionCategory.utilities,
    'noip': SubscriptionCategory.utilities,

    // Additional Cloud & Infrastructure
    'oracle cloud': SubscriptionCategory.utilities,
    'ibm cloud': SubscriptionCategory.utilities,
    'alibaba cloud': SubscriptionCategory.utilities,
    'tencent cloud': SubscriptionCategory.utilities,
    'backblaze': SubscriptionCategory.utilities,
    'wasabi': SubscriptionCategory.utilities,
    'pcloud': SubscriptionCategory.utilities,
    'sync.com': SubscriptionCategory.utilities,
    'tresorit': SubscriptionCategory.utilities,
    'mega': SubscriptionCategory.utilities,
    'spideroak': SubscriptionCategory.utilities,
    'idrive': SubscriptionCategory.utilities,
    'carbonite': SubscriptionCategory.utilities,

    // Additional Productivity Tools
    'clickup': SubscriptionCategory.productivity,
    'wrike': SubscriptionCategory.productivity,
    'basecamp': SubscriptionCategory.productivity,
    'smartsheet': SubscriptionCategory.productivity,
    'airtable': SubscriptionCategory.productivity,
    'monday.com': SubscriptionCategory.productivity,
    'linear': SubscriptionCategory.productivity,
    'shortcut': SubscriptionCategory.productivity,
    'clubhouse': SubscriptionCategory.productivity,
    'pivotal tracker': SubscriptionCategory.productivity,
    'zendesk': SubscriptionCategory.productivity,
    'freshdesk': SubscriptionCategory.productivity,
    'intercom': SubscriptionCategory.productivity,
    'drift': SubscriptionCategory.productivity,
    'hubspot': SubscriptionCategory.productivity,
    'salesforce': SubscriptionCategory.productivity,
    'mailchimp': SubscriptionCategory.productivity,
    'sendgrid': SubscriptionCategory.productivity,
    'twilio': SubscriptionCategory.productivity,
    'square': SubscriptionCategory.productivity,
    'shopify': SubscriptionCategory.productivity,
    'woocommerce': SubscriptionCategory.productivity,
    'bigcommerce': SubscriptionCategory.productivity,
    'squarespace': SubscriptionCategory.productivity,
    'wix': SubscriptionCategory.productivity,
    'weebly': SubscriptionCategory.productivity,
    'webflow': SubscriptionCategory.productivity,
    'bubble': SubscriptionCategory.productivity,
    'zapier': SubscriptionCategory.productivity,
    'ifttt': SubscriptionCategory.productivity,
    'make': SubscriptionCategory.productivity,
    'integromat': SubscriptionCategory.productivity,
    'buffer': SubscriptionCategory.productivity,
    'hootsuite': SubscriptionCategory.productivity,
    'sprout social': SubscriptionCategory.productivity,
    'later': SubscriptionCategory.productivity,
    'planoly': SubscriptionCategory.productivity,

    // Additional Entertainment
    'shudder': SubscriptionCategory.entertainment,
    'mubi': SubscriptionCategory.entertainment,
    'criterion channel': SubscriptionCategory.entertainment,
    'britbox': SubscriptionCategory.entertainment,
    'acorn tv': SubscriptionCategory.entertainment,
    'apple tv+': SubscriptionCategory.entertainment,
    'paramount+': SubscriptionCategory.entertainment,
    'discovery+': SubscriptionCategory.entertainment,
    'fubo tv': SubscriptionCategory.entertainment,
    'sling tv': SubscriptionCategory.entertainment,
    'youtube tv': SubscriptionCategory.entertainment,
    'philo': SubscriptionCategory.entertainment,
    'pluto tv': SubscriptionCategory.entertainment,
    'tubi': SubscriptionCategory.entertainment,
    'crackle': SubscriptionCategory.entertainment,
    'imdb tv': SubscriptionCategory.entertainment,
    'plex': SubscriptionCategory.entertainment,
    'jellyfin': SubscriptionCategory.entertainment,
    'emby': SubscriptionCategory.entertainment,
    'qobuz': SubscriptionCategory.entertainment,
    'bandcamp': SubscriptionCategory.entertainment,
    'tunein': SubscriptionCategory.entertainment,
    'iheartradio': SubscriptionCategory.entertainment,
    'siriusxm': SubscriptionCategory.entertainment,

    // Additional Education
    'pluralsight': SubscriptionCategory.education,
    'treehouse': SubscriptionCategory.education,
    'codecademy': SubscriptionCategory.education,
    'freecodecamp': SubscriptionCategory.education,
    'khan academy kids': SubscriptionCategory.education,
    'brilliant': SubscriptionCategory.education,
    'udacity': SubscriptionCategory.education,
    'edx': SubscriptionCategory.education,
    'futurelearn': SubscriptionCategory.education,
    'alison': SubscriptionCategory.education,
    'coursera plus': SubscriptionCategory.education,
    'skillshare premium': SubscriptionCategory.education,
    'domestika': SubscriptionCategory.education,
    'creative live': SubscriptionCategory.education,
    'the great courses': SubscriptionCategory.education,
    'blinkist': SubscriptionCategory.education,
    'scribd': SubscriptionCategory.education,
    'perlego': SubscriptionCategory.education,
    'everand': SubscriptionCategory.education,

    // Additional Health & Fitness
    'nike training club': SubscriptionCategory.health,
    'freeletics': SubscriptionCategory.health,
    'centr': SubscriptionCategory.health,
    'obé fitness': SubscriptionCategory.health,
    'alo moves': SubscriptionCategory.health,
    'glo fitness': SubscriptionCategory.health,
    'down dog': SubscriptionCategory.health,
    'yoga studio': SubscriptionCategory.health,
    'yoga go': SubscriptionCategory.health,
    'yoga international': SubscriptionCategory.health,
    'yoga with adriene': SubscriptionCategory.health,
    'yogaia': SubscriptionCategory.health,
    'les mills on demand': SubscriptionCategory.health,
    'beachbody on demand': SubscriptionCategory.health,
    'daily burn': SubscriptionCategory.health,
    'aaptiv': SubscriptionCategory.health,
    '8fit': SubscriptionCategory.health,
    'sweat': SubscriptionCategory.health,
    'fiit': SubscriptionCategory.health,
    'future': SubscriptionCategory.health,
    'tonal': SubscriptionCategory.health,
    'mirror': SubscriptionCategory.health,
    'tempo': SubscriptionCategory.health,
    'apple fitness+': SubscriptionCategory.health,
    'apple fitness': SubscriptionCategory.health,
    'oura': SubscriptionCategory.health,
    'garmin': SubscriptionCategory.health,
    'polar': SubscriptionCategory.health,
    'suunto': SubscriptionCategory.health,
  };

  /// Service alternatives with cost savings estimates
  static const Map<String, List<ServiceAlternative>> serviceAlternatives = {
    'netflix': [
      ServiceAlternative(
        name: 'Disney+',
        savings: 0.2,
        reason: 'Lower cost with similar content library',
      ),
      ServiceAlternative(
        name: 'Hulu',
        savings: 0.15,
        reason: 'More current TV shows and live TV options',
      ),
      ServiceAlternative(
        name: 'Amazon Prime Video',
        savings: 0.3,
        reason: 'Included with Prime membership, additional benefits',
      ),
    ],
    'spotify': [
      ServiceAlternative(
        name: 'Apple Music',
        savings: 0.0,
        reason: 'Similar pricing, better integration with Apple devices',
      ),
      ServiceAlternative(
        name: 'YouTube Music',
        savings: 0.1,
        reason: 'Includes YouTube Premium benefits',
      ),
      ServiceAlternative(
        name: 'Amazon Music Unlimited',
        savings: 0.2,
        reason: 'Lower cost for Prime members',
      ),
    ],
    'adobe creative cloud': [
      ServiceAlternative(
        name: 'Affinity Suite',
        savings: 0.7,
        reason: 'One-time purchase, no subscription needed',
      ),
      ServiceAlternative(
        name: 'Canva Pro',
        savings: 0.8,
        reason: 'Much lower cost for basic design needs',
      ),
      ServiceAlternative(
        name: 'Figma',
        savings: 0.4,
        reason: 'Better for UI/UX design, lower cost',
      ),
    ],
    'microsoft office 365': [
      ServiceAlternative(
        name: 'Google Workspace',
        savings: 0.2,
        reason: 'Better collaboration features, cloud-first',
      ),
      ServiceAlternative(
        name: 'LibreOffice',
        savings: 1.0,
        reason: 'Free and open-source alternative',
      ),
      ServiceAlternative(
        name: 'Apple iWork',
        savings: 0.0,
        reason: 'Free for Apple device users',
      ),
    ],
    'dropbox': [
      ServiceAlternative(
        name: 'Google Drive',
        savings: 0.3,
        reason: 'More storage for less money',
      ),
      ServiceAlternative(
        name: 'OneDrive',
        savings: 0.2,
        reason: 'Included with Microsoft 365',
      ),
      ServiceAlternative(
        name: 'iCloud',
        savings: 0.1,
        reason: 'Better integration with Apple devices',
      ),
    ],
    'slack': [
      ServiceAlternative(
        name: 'Microsoft Teams',
        savings: 0.5,
        reason: 'Included with Microsoft 365',
      ),
      ServiceAlternative(
        name: 'Discord',
        savings: 0.8,
        reason: 'Free for most use cases',
      ),
      ServiceAlternative(
        name: 'Google Chat',
        savings: 0.6,
        reason: 'Included with Google Workspace',
      ),
    ],
    'zoom': [
      ServiceAlternative(
        name: 'Google Meet',
        savings: 0.7,
        reason: 'Free for most users, included with Workspace',
      ),
      ServiceAlternative(
        name: 'Microsoft Teams',
        savings: 0.5,
        reason: 'Included with Microsoft 365',
      ),
      ServiceAlternative(
        name: 'Jitsi Meet',
        savings: 1.0,
        reason: 'Free and open-source',
      ),
    ],
    'grammarly': [
      ServiceAlternative(
        name: 'LanguageTool',
        savings: 0.6,
        reason: 'Similar features, lower cost',
      ),
      ServiceAlternative(
        name: 'ProWritingAid',
        savings: 0.4,
        reason: 'Better for long-form writing',
      ),
    ],
    'lastpass': [
      ServiceAlternative(
        name: '1Password',
        savings: 0.0,
        reason: 'Better security features',
      ),
      ServiceAlternative(
        name: 'Bitwarden',
        savings: 0.7,
        reason: 'Free tier available, open-source',
      ),
      ServiceAlternative(
        name: 'Dashlane',
        savings: 0.1,
        reason: 'Better user interface',
      ),
    ],
    'nordvpn': [
      ServiceAlternative(
        name: 'ExpressVPN',
        savings: 0.0,
        reason: 'Faster speeds, better server network',
      ),
      ServiceAlternative(
        name: 'Surfshark',
        savings: 0.4,
        reason: 'Lower cost, unlimited devices',
      ),
      ServiceAlternative(
        name: 'ProtonVPN',
        savings: 0.3,
        reason: 'Free tier available, strong privacy',
      ),
    ],
    'aws': [
      ServiceAlternative(
        name: 'Google Cloud Platform',
        savings: 0.1,
        reason: 'Better pricing for some services',
      ),
      ServiceAlternative(
        name: 'DigitalOcean',
        savings: 0.5,
        reason: 'Simpler pricing, better for small projects',
      ),
      ServiceAlternative(
        name: 'Vultr',
        savings: 0.4,
        reason: 'Lower cost, similar features',
      ),
    ],
    'github': [
      ServiceAlternative(
        name: 'GitLab',
        savings: 0.3,
        reason: 'Free private repos, more features',
      ),
      ServiceAlternative(
        name: 'Bitbucket',
        savings: 0.2,
        reason: 'Free private repos, Atlassian integration',
      ),
    ],
    'coursera': [
      ServiceAlternative(
        name: 'Udemy',
        savings: 0.6,
        reason: 'One-time purchase per course, frequent sales',
      ),
      ServiceAlternative(
        name: 'Skillshare',
        savings: 0.5,
        reason: 'Lower monthly cost, creative focus',
      ),
      ServiceAlternative(
        name: 'LinkedIn Learning',
        savings: 0.3,
        reason: 'Professional development focus',
      ),
    ],
    'calm': [
      ServiceAlternative(
        name: 'Headspace',
        savings: 0.0,
        reason: 'Similar pricing, different meditation styles',
      ),
      ServiceAlternative(
        name: 'Insight Timer',
        savings: 0.9,
        reason: 'Free tier with extensive content',
      ),
    ],
    'myfitnesspal': [
      ServiceAlternative(
        name: 'Lose It!',
        savings: 0.3,
        reason: 'Lower cost, similar features',
      ),
      ServiceAlternative(
        name: 'Cronometer',
        savings: 0.4,
        reason: 'More detailed nutrition tracking',
      ),
    ],
    // African Services
    'showmax': [
      ServiceAlternative(
        name: 'Netflix',
        savings: 0.0,
        reason: 'Larger international content library',
      ),
      ServiceAlternative(
        name: 'Disney+',
        savings: 0.2,
        reason: 'Lower cost, family-friendly content',
      ),
    ],
    'dstv': [
      ServiceAlternative(
        name: 'Showmax',
        savings: 0.6,
        reason: 'Much lower cost, on-demand streaming',
      ),
      ServiceAlternative(
        name: 'Netflix',
        savings: 0.4,
        reason: 'Better value for international content',
      ),
    ],
    'mtn mobile money': [
      ServiceAlternative(
        name: 'Vodafone Cash',
        savings: 0.0,
        reason: 'Similar features, check transaction fees',
      ),
      ServiceAlternative(
        name: 'Chipper Cash',
        savings: 0.0,
        reason: 'Better for cross-border transfers',
      ),
    ],
    // Hosting Services
    'hostinger': [
      ServiceAlternative(
        name: 'DigitalOcean',
        savings: 0.0,
        reason: 'Better for developers, more control',
      ),
      ServiceAlternative(
        name: 'Vultr',
        savings: 0.1,
        reason: 'Similar pricing, better performance',
      ),
    ],
    'bluehost': [
      ServiceAlternative(
        name: 'SiteGround',
        savings: 0.0,
        reason: 'Better performance and support',
      ),
      ServiceAlternative(
        name: 'Hostinger',
        savings: 0.4,
        reason: 'Much lower cost, similar features',
      ),
    ],
    'siteground': [
      ServiceAlternative(
        name: 'Hostinger',
        savings: 0.5,
        reason: 'Much lower cost, good performance',
      ),
      ServiceAlternative(
        name: 'DigitalOcean',
        savings: 0.2,
        reason: 'Better for developers, scalable',
      ),
    ],
    'wp engine': [
      ServiceAlternative(
        name: 'Kinsta',
        savings: 0.0,
        reason: 'Similar pricing, better performance',
      ),
      ServiceAlternative(
        name: 'SiteGround',
        savings: 0.6,
        reason: 'Much lower cost, good WordPress hosting',
      ),
    ],
    'cloudflare': [
      ServiceAlternative(
        name: 'Cloudflare Free',
        savings: 1.0,
        reason: 'Free tier available for basic needs',
      ),
      ServiceAlternative(
        name: 'BunnyCDN',
        savings: 0.3,
        reason: 'Lower cost CDN service',
      ),
    ],
    // Additional Services
    'mailchimp': [
      ServiceAlternative(
        name: 'SendGrid',
        savings: 0.2,
        reason: 'Better for transactional emails',
      ),
      ServiceAlternative(
        name: 'ConvertKit',
        savings: 0.0,
        reason: 'Better for creators and bloggers',
      ),
    ],
    'zapier': [
      ServiceAlternative(
        name: 'Make (Integromat)',
        savings: 0.2,
        reason: 'Lower cost, more visual workflow builder',
      ),
      ServiceAlternative(
        name: 'IFTTT',
        savings: 0.8,
        reason: 'Free tier available for simple automations',
      ),
    ],
    'buffer': [
      ServiceAlternative(
        name: 'Later',
        savings: 0.3,
        reason: 'Lower cost, better for Instagram',
      ),
      ServiceAlternative(
        name: 'Hootsuite',
        savings: 0.0,
        reason: 'More features for enterprise',
      ),
    ],
  };

  /// Overlapping service groups (services that often overlap in functionality)
  static const Map<String, List<String>> overlappingGroups = {
    'streaming_video': [
      'netflix',
      'disney',
      'hulu',
      'hbo',
      'max',
      'paramount',
      'peacock',
      'apple tv',
      'amazon prime',
      'prime video',
    ],
    'streaming_music': [
      'spotify',
      'apple music',
      'youtube music',
      'pandora',
      'tidal',
      'deezer',
      'amazon music',
    ],
    'cloud_storage': [
      'dropbox',
      'google drive',
      'onedrive',
      'icloud',
      'box',
    ],
    'password_managers': [
      'lastpass',
      '1password',
      'dashlane',
      'bitwarden',
    ],
    'vpn_services': [
      'nordvpn',
      'expressvpn',
      'surfshark',
      'protonvpn',
    ],
    'productivity_suites': [
      'microsoft office',
      'microsoft 365',
      'office 365',
      'google workspace',
      'g suite',
    ],
    'design_tools': [
      'adobe creative cloud',
      'adobe',
      'figma',
      'sketch',
      'canva',
    ],
    'project_management': [
      'asana',
      'trello',
      'monday',
      'jira',
      'notion',
    ],
    'video_conferencing': [
      'zoom',
      'microsoft teams',
      'google meet',
      'slack',
    ],
    'fitness_tracking': [
      'myfitnesspal',
      'lose it',
      'noom',
      'strava',
    ],
    'meditation_apps': [
      'calm',
      'headspace',
      'insight timer',
    ],
    'code_repositories': [
      'github',
      'gitlab',
      'bitbucket',
    ],
    'cloud_hosting': [
      'aws',
      'amazon web services',
      'azure',
      'google cloud',
      'digitalocean',
      'vultr',
      'linode',
      'hetzner',
      'ovh',
      'ovhcloud',
      'scaleway',
      'contabo',
      'hostinger',
      'bluehost',
      'siteground',
      'hostgator',
      'a2 hosting',
      'inmotion hosting',
      'dreamhost',
      'oracle cloud',
      'ibm cloud',
      'alibaba cloud',
    ],
    'wordpress_hosting': [
      'wp engine',
      'kinsta',
      'flywheel',
      'pantheon',
      'siteground',
      'bluehost',
      'hostgator',
      'dreamhost',
      'hostinger',
    ],
    'cdn_services': [
      'cloudflare',
      'akamai',
      'fastly',
      'bunnycdn',
      'keycdn',
      'stackpath',
      'cloudfront',
      'maxcdn',
    ],
    'domain_registrars': [
      'namecheap',
      'godaddy',
      'name.com',
      'namesilo',
      'porkbun',
      'hover',
      'dynadot',
      'register.com',
      'ionos',
      '1&1',
    ],
    'african_streaming': [
      'showmax',
      'dstv',
      'dstv now',
      'gotv',
      'startimes',
      'irokotv',
      'africa magic',
      'multichoice',
      'supersport',
      'bounce',
      'afrostream',
    ],
    'mobile_money': [
      'mtn mobile money',
      'mtn momo',
      'vodafone cash',
      'airteltigo money',
      'm-pesa',
      'orange money',
      'ecocash',
      'tigo pesa',
      'moov money',
      'wave',
      'chipper cash',
      'opay',
      'palmpay',
    ],
    'african_telecoms': [
      'mtn',
      'vodafone',
      'airteltigo',
      'safaricom',
      'orange',
      'tigo',
      'airtel',
      'glo',
      'etisalat',
      'telkom',
      'cell c',
    ],
    'email_marketing': [
      'mailchimp',
      'sendgrid',
      'convertkit',
      'constant contact',
      'aweber',
      'getresponse',
      'campaign monitor',
      'activecampaign',
    ],
    'automation_tools': [
      'zapier',
      'ifttt',
      'make',
      'integromat',
      'microsoft power automate',
      'automate.io',
    ],
    'social_media_management': [
      'buffer',
      'hootsuite',
      'sprout social',
      'later',
      'planoly',
      'tailwind',
      'socialbakers',
    ],
    'crm_platforms': [
      'salesforce',
      'hubspot',
      'zoho crm',
      'pipedrive',
      'freshsales',
      'copper',
      'insightly',
    ],
    'customer_support': [
      'zendesk',
      'freshdesk',
      'intercom',
      'drift',
      'helpscout',
      'crisp',
      'tawk.to',
    ],
  };

  /// Price ranges for common services (monthly, in USD)
  static const Map<String, PriceRange> servicePriceRanges = {
    'netflix': PriceRange(min: 9.99, max: 19.99, typical: 15.99),
    'spotify': PriceRange(min: 9.99, max: 15.99, typical: 10.99),
    'disney': PriceRange(min: 7.99, max: 13.99, typical: 10.99),
    'hulu': PriceRange(min: 7.99, max: 14.99, typical: 12.99),
    'hbo': PriceRange(min: 9.99, max: 15.99, typical: 14.99),
    'max': PriceRange(min: 9.99, max: 19.99, typical: 15.99),
    'amazon prime': PriceRange(min: 8.99, max: 14.99, typical: 12.99),
    'apple music': PriceRange(min: 9.99, max: 14.99, typical: 10.99),
    'youtube premium': PriceRange(min: 11.99, max: 18.99, typical: 13.99),
    'adobe creative cloud': PriceRange(min: 20.99, max: 79.99, typical: 52.99),
    'microsoft 365': PriceRange(min: 6.99, max: 22.99, typical: 9.99),
    'office 365': PriceRange(min: 6.99, max: 22.99, typical: 9.99),
    'google workspace': PriceRange(min: 6.0, max: 18.0, typical: 12.0),
    'dropbox': PriceRange(min: 9.99, max: 20.0, typical: 16.58),
    'slack': PriceRange(min: 7.25, max: 12.5, typical: 7.25),
    'zoom': PriceRange(min: 14.99, max: 19.99, typical: 14.99),
    'notion': PriceRange(min: 8.0, max: 15.0, typical: 10.0),
    'figma': PriceRange(min: 12.0, max: 45.0, typical: 15.0),
    'canva': PriceRange(min: 12.99, max: 14.99, typical: 12.99),
    'grammarly': PriceRange(min: 12.0, max: 30.0, typical: 12.0),
    'lastpass': PriceRange(min: 3.0, max: 6.0, typical: 4.0),
    '1password': PriceRange(min: 2.99, max: 7.99, typical: 4.99),
    'nordvpn': PriceRange(min: 3.49, max: 11.95, typical: 4.92),
    'expressvpn': PriceRange(min: 6.67, max: 12.95, typical: 8.32),
    'github': PriceRange(min: 4.0, max: 21.0, typical: 4.0),
    'aws': PriceRange(min: 0.0, max: 1000.0, typical: 50.0),
    'coursera': PriceRange(min: 39.0, max: 79.0, typical: 49.0),
    'udemy': PriceRange(min: 0.0, max: 199.99, typical: 19.99),
    'calm': PriceRange(min: 14.99, max: 69.99, typical: 14.99),
    'headspace': PriceRange(min: 12.99, max: 69.99, typical: 12.99),
    'myfitnesspal': PriceRange(min: 9.99, max: 19.99, typical: 9.99),

    // African Services
    'showmax': PriceRange(min: 4.99, max: 9.99, typical: 6.99),
    'dstv': PriceRange(min: 15.0, max: 85.0, typical: 45.0),
    'dstv now': PriceRange(min: 9.99, max: 19.99, typical: 14.99),
    'gotv': PriceRange(min: 5.0, max: 25.0, typical: 15.0),
    'mtn mobile money': PriceRange(min: 0.0, max: 5.0, typical: 0.0),
    'vodafone cash': PriceRange(min: 0.0, max: 5.0, typical: 0.0),
    'm-pesa': PriceRange(min: 0.0, max: 3.0, typical: 0.0),
    'chipper cash': PriceRange(min: 0.0, max: 5.0, typical: 0.0),

    // Hosting Services
    'hostinger': PriceRange(min: 1.99, max: 11.99, typical: 3.99),
    'bluehost': PriceRange(min: 2.95, max: 13.95, typical: 4.95),
    'siteground': PriceRange(min: 3.99, max: 10.99, typical: 6.99),
    'hostgator': PriceRange(min: 2.75, max: 5.95, typical: 3.95),
    'a2 hosting': PriceRange(min: 2.99, max: 14.99, typical: 4.99),
    'wp engine': PriceRange(min: 20.0, max: 290.0, typical: 30.0),
    'kinsta': PriceRange(min: 30.0, max: 600.0, typical: 35.0),
    'hetzner': PriceRange(min: 3.29, max: 100.0, typical: 4.15),
    'contabo': PriceRange(min: 3.99, max: 50.0, typical: 4.99),
    'ionos': PriceRange(min: 1.0, max: 10.0, typical: 1.0),
    'scaleway': PriceRange(min: 0.01, max: 50.0, typical: 2.99),

    // CDN Services
    'cloudflare': PriceRange(min: 0.0, max: 200.0, typical: 20.0),
    'bunnycdn': PriceRange(min: 1.0, max: 50.0, typical: 5.0),
    'fastly': PriceRange(min: 50.0, max: 500.0, typical: 100.0),
    'akamai': PriceRange(min: 100.0, max: 1000.0, typical: 300.0),

    // Additional Services
    'mailchimp': PriceRange(min: 0.0, max: 350.0, typical: 13.0),
    'sendgrid': PriceRange(min: 15.0, max: 80.0, typical: 19.95),
    'zapier': PriceRange(min: 0.0, max: 50.0, typical: 20.0),
    'make': PriceRange(min: 0.0, max: 40.0, typical: 9.0),
    'buffer': PriceRange(min: 0.0, max: 99.0, typical: 6.0),
    'hootsuite': PriceRange(min: 49.0, max: 739.0, typical: 99.0),
    'salesforce': PriceRange(min: 25.0, max: 300.0, typical: 75.0),
    'hubspot': PriceRange(min: 0.0, max: 1200.0, typical: 45.0),
    'zendesk': PriceRange(min: 49.0, max: 215.0, typical: 55.0),
    'intercom': PriceRange(min: 39.0, max: 999.0, typical: 74.0),
    'shopify': PriceRange(min: 29.0, max: 299.0, typical: 79.0),
    'squarespace': PriceRange(min: 12.0, max: 40.0, typical: 18.0),
    'wix': PriceRange(min: 14.0, max: 39.0, typical: 23.0),
    'webflow': PriceRange(min: 12.0, max: 35.0, typical: 16.0),
    'clickup': PriceRange(min: 0.0, max: 19.0, typical: 9.0),
    'airtable': PriceRange(min: 0.0, max: 20.0, typical: 12.0),
    'pluralsight': PriceRange(min: 29.0, max: 45.0, typical: 35.0),
    'codecademy': PriceRange(min: 0.0, max: 39.99, typical: 19.99),
    'udacity': PriceRange(min: 0.0, max: 399.0, typical: 199.0),
    'blinkist': PriceRange(min: 4.99, max: 15.99, typical: 7.99),
    'scribd': PriceRange(min: 9.99, max: 14.99, typical: 9.99),
  };

  /// Waste indicators (patterns that suggest unused subscriptions)
  static const List<WastePattern> wastePatterns = [
    WastePattern(
      condition: 'past_due_90_days',
      description: 'Subscription past due for 90+ days',
      severity: 'high',
    ),
    WastePattern(
      condition: 'no_auto_renew',
      description: 'Auto-renew disabled for active subscription',
      severity: 'medium',
    ),
    WastePattern(
      condition: 'duplicate_category',
      description: 'Multiple subscriptions in same category',
      severity: 'medium',
    ),
    WastePattern(
      condition: 'expensive_unused',
      description: 'High-cost subscription with no recent activity',
      severity: 'high',
    ),
    WastePattern(
      condition: 'trial_expired',
      description: 'Trial expired but subscription not converted',
      severity: 'low',
    ),
  ];

  /// Budget thresholds for different spending levels
  static const Map<String, BudgetThreshold> budgetThresholds = {
    'low': BudgetThreshold(monthly: 25.0, yearly: 300.0),
    'medium': BudgetThreshold(monthly: 50.0, yearly: 600.0),
    'high': BudgetThreshold(monthly: 100.0, yearly: 1200.0),
    'very_high': BudgetThreshold(monthly: 200.0, yearly: 2400.0),
  };

  /// Get category for a service name
  static SubscriptionCategory? getCategoryForService(String serviceName) {
    final lowerName = serviceName.toLowerCase();
    for (final entry in serviceCategories.entries) {
      if (lowerName.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Get alternatives for a service
  static List<ServiceAlternative> getAlternativesForService(
      String serviceName) {
    final lowerName = serviceName.toLowerCase();
    for (final entry in serviceAlternatives.entries) {
      if (lowerName.contains(entry.key)) {
        return entry.value;
      }
    }
    return [];
  }

  /// Check if services overlap
  static bool doServicesOverlap(String service1, String service2) {
    final lower1 = service1.toLowerCase();
    final lower2 = service2.toLowerCase();

    for (final group in overlappingGroups.values) {
      final contains1 = group.any((s) => lower1.contains(s));
      final contains2 = group.any((s) => lower2.contains(s));
      if (contains1 && contains2) {
        return true;
      }
    }
    return false;
  }

  /// Get overlapping group for a service
  static String? getOverlappingGroup(String serviceName) {
    final lowerName = serviceName.toLowerCase();
    for (final entry in overlappingGroups.entries) {
      if (entry.value.any((s) => lowerName.contains(s))) {
        return entry.key;
      }
    }
    return null;
  }

  /// Check if price is typical for service
  static bool isPriceTypical(String serviceName, double monthlyCost) {
    final lowerName = serviceName.toLowerCase();
    for (final entry in servicePriceRanges.entries) {
      if (lowerName.contains(entry.key)) {
        final range = entry.value;
        return monthlyCost >= range.min && monthlyCost <= range.max;
      }
    }
    return true; // Unknown service, assume typical
  }

  /// Get price range for service
  static PriceRange? getPriceRangeForService(String serviceName) {
    final lowerName = serviceName.toLowerCase();
    for (final entry in servicePriceRanges.entries) {
      if (lowerName.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }
}

class ServiceAlternative {
  const ServiceAlternative({
    required this.name,
    required this.savings,
    required this.reason,
  });

  final String name;
  final double savings; // Percentage savings (0.0 to 1.0)
  final String reason;
}

class PriceRange {
  const PriceRange({
    required this.min,
    required this.max,
    required this.typical,
  });

  final double min;
  final double max;
  final double typical;
}

class WastePattern {
  const WastePattern({
    required this.condition,
    required this.description,
    required this.severity,
  });

  final String condition;
  final String description;
  final String severity; // 'low', 'medium', 'high'
}

class BudgetThreshold {
  const BudgetThreshold({
    required this.monthly,
    required this.yearly,
  });

  final double monthly;
  final double yearly;
}

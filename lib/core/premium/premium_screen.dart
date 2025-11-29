import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/currency/currency_list.dart';
import '../../core/currency/currency_preferences_provider.dart';
import '../../core/responsive/responsive_helper.dart';
import 'premium_pricing.dart';
import 'premium_provider.dart';
import 'premium_service.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  PremiumTier? _selectedTier;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _selectedTier = PremiumTier.yearly; // Default to yearly
  }

  @override
  Widget build(BuildContext context) {
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final currencyInfo = CurrencyList.getCurrencyInfo(baseCurrency);
    final currencySymbol = currencyInfo?.symbol ?? baseCurrency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Premium'),
      ),
      body: ListView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
        children: [
          // Header
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
              child: Column(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(16)),
                  Text(
                    'Unlock Premium Features',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(8)),
                  Text(
                    'Remove ads, unlock unlimited subscriptions, and access all features',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(24)),

          // Features list
          Text(
            'Premium Features',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(16)),
          _FeatureItem(
            icon: Icons.block_rounded,
            title: 'Ad-free experience',
            description: 'No banner, interstitial, or native ads',
          ),
          _FeatureItem(
            icon: Icons.all_inclusive_rounded,
            title: 'Unlimited subscriptions',
            description: 'Add as many subscriptions as you need',
          ),
          _FeatureItem(
            icon: Icons.cloud_sync_rounded,
            title: 'Cloud sync',
            description: 'Sync across all your devices',
          ),
          _FeatureItem(
            icon: Icons.psychology_rounded,
            title: 'Advanced AI insights',
            description: 'Get detailed analytics and recommendations',
          ),
          _FeatureItem(
            icon: Icons.download_rounded,
            title: 'Export data',
            description: 'Export your subscriptions to CSV/PDF',
          ),
          SizedBox(height: ResponsiveHelper.spacing(24)),

          // Pricing tiers
          Text(
            'Choose Your Plan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(16)),

          // Monthly
          _PricingCard(
            tier: PremiumTier.monthly,
            isSelected: _selectedTier == PremiumTier.monthly,
            currencySymbol: currencySymbol,
            onTap: () => setState(() => _selectedTier = PremiumTier.monthly),
          ),
          SizedBox(height: ResponsiveHelper.spacing(12)),

          // Quarterly
          _PricingCard(
            tier: PremiumTier.quarterly,
            isSelected: _selectedTier == PremiumTier.quarterly,
            currencySymbol: currencySymbol,
            onTap: () => setState(() => _selectedTier = PremiumTier.quarterly),
            showSavings: true,
          ),
          SizedBox(height: ResponsiveHelper.spacing(12)),

          // Yearly (Recommended)
          _PricingCard(
            tier: PremiumTier.yearly,
            isSelected: _selectedTier == PremiumTier.yearly,
            currencySymbol: currencySymbol,
            onTap: () => setState(() => _selectedTier = PremiumTier.yearly),
            showSavings: true,
            isRecommended: true,
          ),
          SizedBox(height: ResponsiveHelper.spacing(12)),

          // Lifetime
          _PricingCard(
            tier: PremiumTier.lifetime,
            isSelected: _selectedTier == PremiumTier.lifetime,
            currencySymbol: currencySymbol,
            onTap: () => setState(() => _selectedTier = PremiumTier.lifetime),
            showSavings: true,
          ),
          SizedBox(height: ResponsiveHelper.spacing(24)),

          // Purchase button
          ElevatedButton(
            onPressed: _isPurchasing ? null : _purchasePremium,
            style: ElevatedButton.styleFrom(
              padding:
                  EdgeInsets.symmetric(vertical: ResponsiveHelper.spacing(16)),
              minimumSize: const Size(double.infinity, 56),
            ),
            child: _isPurchasing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Subscribe Now',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(12)),

          // Restore purchases
          TextButton(
            onPressed: _restorePurchases,
            child: const Text('Restore Purchases'),
          ),
        ],
      ),
    );
  }

  Future<void> _purchasePremium() async {
    if (_selectedTier == null) return;

    setState(() => _isPurchasing = true);

    try {
      final service = ref.read(premiumServiceProvider);
      final success = await service.purchasePremium(_selectedTier!);

      if (success && mounted) {
        // Calculate expiry based on tier
        DateTime? expiry;
        switch (_selectedTier!) {
          case PremiumTier.monthly:
            expiry = DateTime.now().add(const Duration(days: 30));
            break;
          case PremiumTier.quarterly:
            expiry = DateTime.now().add(const Duration(days: 90));
            break;
          case PremiumTier.yearly:
            expiry = DateTime.now().add(const Duration(days: 365));
            break;
          case PremiumTier.lifetime:
            expiry = null; // No expiry
            break;
        }

        await service.setPremium(tier: _selectedTier!, expiry: expiry);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Premium activated successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase failed. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    try {
      final service = ref.read(premiumServiceProvider);
      await service.restorePurchases();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring purchases: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: ResponsiveHelper.spacing(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.tier,
    required this.isSelected,
    required this.currencySymbol,
    required this.onTap,
    this.showSavings = false,
    this.isRecommended = false,
  });

  final PremiumTier tier;
  final bool isSelected;
  final String currencySymbol;
  final VoidCallback onTap;
  final bool showSavings;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final savings = PremiumPricing.getSavings(tier);
    final displayPrice = PremiumPricing.getDisplayPrice(tier, currencySymbol);

    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
          child: Row(
            children: [
              // Radio button
              Radio<PremiumTier>(
                value: tier,
                groupValue: isSelected ? tier : null,
                onChanged: (_) => onTap(),
              ),
              SizedBox(width: ResponsiveHelper.spacing(12)),

              // Tier info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tier.displayName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        if (isRecommended) ...[
                          SizedBox(width: ResponsiveHelper.spacing(8)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveHelper.spacing(8),
                              vertical: ResponsiveHelper.spacing(4),
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'BEST VALUE',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onTertiary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (showSavings && savings > 0) ...[
                      SizedBox(height: ResponsiveHelper.spacing(4)),
                      Text(
                        'Save ${savings.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ],
                ),
              ),

              // Price
              Text(
                displayPrice,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

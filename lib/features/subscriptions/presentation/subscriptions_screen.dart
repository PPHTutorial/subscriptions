import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/ads/native_ad_widget.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../application/subscription_controller.dart';
import '../domain/subscription.dart';
import 'widgets/sort_filter_bar.dart';
import 'widgets/subscription_card.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({
    super.key,
    required this.onAddTap,
    required this.sortOption,
    required this.onSortChanged,
    required this.showTrialsOnly,
    required this.onTrialsFilterChanged,
    this.selectedCategory,
    this.onCategoryChanged,
    this.searchQuery = '',
  });

  final VoidCallback onAddTap;
  final SortOption sortOption;
  final ValueChanged<SortOption> onSortChanged;
  final bool showTrialsOnly;
  final ValueChanged<bool> onTrialsFilterChanged;
  final SubscriptionCategory? selectedCategory;
  final ValueChanged<SubscriptionCategory?>? onCategoryChanged;
  final String searchQuery;

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  SubscriptionCategory? _filterCategory;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _filterCategory = widget.selectedCategory;
  }

  @override
  void didUpdateWidget(SubscriptionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      _filterCategory = widget.selectedCategory;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions = ref.watch(subscriptionControllerProvider);

    return subscriptions.when(
      data: (items) {
        var filtered = _applyFilters(items);
        filtered = sortSubscriptions(filtered, widget.sortOption);
        return Column(
          children: [
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyListState(onAddTap: widget.onAddTap)
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              ResponsiveHelper.spacing(20),
                              ResponsiveHelper.spacing(12),
                              ResponsiveHelper.spacing(20),
                              // Add bottom padding to account for bottom nav bar + safe area
                              ResponsiveHelper.spacing(12) +
                                  ResponsiveHelper.safeAreaBottom(context) +
                                  80, // Bottom nav bar height
                            ),
                            itemCount: filtered.length +
                                (filtered.length > 0
                                    ? (filtered.length ~/ 5)
                                    : 0),
                            itemBuilder: (context, index) {
                              // Show native ad every 5 items
                              if (index > 0 && index % 5 == 0) {
                                return Column(
                                  children: [
                                    const NativeAdWidget(),
                                    SubscriptionCard(
                                      subscription:
                                          filtered[index - (index ~/ 5)],
                                    ),
                                  ],
                                );
                              }
                              // Adjust index for native ads
                              final adjustedIndex = index - (index ~/ 5);
                              if (adjustedIndex >= filtered.length) {
                                return const SizedBox.shrink();
                              }
                              return SubscriptionCard(
                                subscription: filtered[adjustedIndex],
                              );
                            },
                          ),
                        ),
                        const BannerAdWidget(),
                        SizedBox(
                            height: ResponsiveHelper.safeAreaBottom(context)),
                      ],
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  List<Subscription> _applyFilters(List<Subscription> items) {
    return items.where((subscription) {
      final matchesSearch = widget.searchQuery.isEmpty ||
          subscription.serviceName
              .toLowerCase()
              .contains(widget.searchQuery.toLowerCase()) ||
          subscription.paymentMethod
              .toLowerCase()
              .contains(widget.searchQuery.toLowerCase());

      final matchesCategory =
          _filterCategory == null || subscription.category == _filterCategory;

      final matchesTrialFilter = !widget.showTrialsOnly || subscription.isTrial;

      return matchesSearch && matchesCategory && matchesTrialFilter;
    }).toList();
  }
}

class _EmptyListState extends StatelessWidget {
  const _EmptyListState({required this.onAddTap});

  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.spacing(32),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.layers_clear_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing here yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Capture streaming, productivity, finance, and lifestyle subscriptions. Everything stays offline.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add),
              label: const Text('Add subscription'),
            ),
          ],
        ),
      ),
    );
  }
}

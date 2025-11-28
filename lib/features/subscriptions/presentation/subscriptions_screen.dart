import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ads/banner_ad_widget.dart';
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
  });

  final VoidCallback onAddTap;
  final SortOption sortOption;
  final ValueChanged<SortOption> onSortChanged;
  final bool showTrialsOnly;
  final ValueChanged<bool> onTrialsFilterChanged;

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  String _searchQuery = '';
  SubscriptionCategory? _filterCategory;
  final _scrollController = ScrollController();

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
            Padding(
              padding: EdgeInsets.fromLTRB(
                ResponsiveHelper.spacing(20),
                ResponsiveHelper.spacing(16),
                ResponsiveHelper.spacing(20),
                0,
              ),
              child: _buildSearchField(),
            ),
            _buildCategoryChips(),
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
                              ResponsiveHelper.spacing(12),
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return SubscriptionCard(
                                subscription: filtered[index],
                              );
                            },
                          ),
                        ),
                        const BannerAdWidget(),
                        const SizedBox(height: 80),
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

  Widget _buildSearchField() {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'Search services, payment methods...',
        prefixIcon: Icon(Icons.search_rounded),
      ),
      onChanged: (value) => setState(() => _searchQuery = value.trim()),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: ResponsiveHelper.spacing(60),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.spacing(16),
          vertical: ResponsiveHelper.spacing(12),
        ),
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: _filterCategory == null,
            onSelected: (_) => setState(() => _filterCategory = null),
          ),
          ...SubscriptionCategory.values.map(
            (category) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.spacing(6),
              ),
              child: ChoiceChip(
                label: Text(category.name),
                selected: _filterCategory == category,
                onSelected: (_) => setState(() => _filterCategory = category),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Subscription> _applyFilters(List<Subscription> items) {
    return items.where((subscription) {
      final matchesSearch = _searchQuery.isEmpty ||
          subscription.serviceName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          subscription.paymentMethod
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());

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

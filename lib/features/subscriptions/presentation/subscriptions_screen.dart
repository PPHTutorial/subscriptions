import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/subscription_controller.dart';
import '../domain/subscription.dart';
import 'widgets/subscription_card.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key, required this.onAddTap});

  final VoidCallback onAddTap;

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
        final filtered = _applyFilters(items);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildSearchField(),
            ),
            _buildCategoryChips(),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyListState(onAddTap: widget.onAddTap)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return SubscriptionCard(
                          subscription: filtered[index],
                        );
                      },
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
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: _filterCategory == null,
            onSelected: (_) => setState(() => _filterCategory = null),
          ),
          ...SubscriptionCategory.values.map(
            (category) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
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

      return matchesSearch && matchesCategory;
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
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
                    color: Colors.black54,
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


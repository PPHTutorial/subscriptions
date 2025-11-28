import 'package:flutter/material.dart';
import '../../domain/subscription.dart';

enum SortOption {
  renewalDate,
  price,
  category,
  name,
}

class SortFilterBar extends StatelessWidget {
  const SortFilterBar({
    super.key,
    required this.sortOption,
    required this.onSortChanged,
    required this.showTrialsOnly,
    required this.onTrialsFilterChanged,
  });

  final SortOption sortOption;
  final ValueChanged<SortOption> onSortChanged;
  final bool showTrialsOnly;
  final ValueChanged<bool> onTrialsFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: PopupMenuButton<SortOption>(
                initialValue: sortOption,
                child: Row(
                  children: [
                    const Icon(Icons.sort_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _getSortLabel(sortOption),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                onSelected: onSortChanged,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: SortOption.renewalDate,
                    child: Text('Sort by renewal date'),
                  ),
                  const PopupMenuItem(
                    value: SortOption.price,
                    child: Text('Sort by price'),
                  ),
                  const PopupMenuItem(
                    value: SortOption.category,
                    child: Text('Sort by category'),
                  ),
                  const PopupMenuItem(
                    value: SortOption.name,
                    child: Text('Sort by name'),
                  ),
                ],
              ),
            ),
            const VerticalDivider(),
            FilterChip(
              label: const Text('Trials only'),
              selected: showTrialsOnly,
              onSelected: onTrialsFilterChanged,
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.renewalDate:
        return 'Renewal date';
      case SortOption.price:
        return 'Price';
      case SortOption.category:
        return 'Category';
      case SortOption.name:
        return 'Name';
    }
  }
}

List<Subscription> sortSubscriptions(
  List<Subscription> subscriptions,
  SortOption sortOption,
) {
  final sorted = List<Subscription>.from(subscriptions);
  switch (sortOption) {
    case SortOption.renewalDate:
      sorted.sort((a, b) => a.renewalDate.compareTo(b.renewalDate));
      break;
    case SortOption.price:
      sorted.sort((a, b) => b.cost.compareTo(a.cost));
      break;
    case SortOption.category:
      sorted.sort((a, b) => a.category.name.compareTo(b.category.name));
      break;
    case SortOption.name:
      sorted.sort((a, b) => a.serviceName.compareTo(b.serviceName));
      break;
  }
  return sorted;
}

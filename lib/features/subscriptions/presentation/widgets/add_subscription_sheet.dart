import 'package:flutter/material.dart';

import '../../domain/subscription.dart';

class AddSubscriptionSheet extends StatefulWidget {
  const AddSubscriptionSheet({
    super.key,
    required this.onSubmit,
  });

  final Future<void> Function(Subscription subscription) onSubmit;

  @override
  State<AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _serviceController = TextEditingController();
  final _costController = TextEditingController();
  final _paymentController = TextEditingController(text: 'Mastercard');
  final _notesController = TextEditingController();
  final _customReminderController = TextEditingController();

  DateTime? _renewalDate;
  DateTime? _trialEndDate;
  BillingCycle _billingCycle = BillingCycle.monthly;
  SubscriptionCategory _category = SubscriptionCategory.entertainment;
  bool _autoRenew = true;
  bool _isTrial = false;
  String _currency = 'USD';
  final Set<int> _reminderDays = {7, 3, 1};
  bool _isSaving = false;

  @override
  void dispose() {
    _serviceController.dispose();
    _costController.dispose();
    _paymentController.dispose();
    _notesController.dispose();
    _customReminderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    'Add subscription',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _serviceController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Service name',
                      hintText: 'Netflix, Spotify, Canva...',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cost',
                            hintText: '9.99',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            final parsed = double.tryParse(value);
                            if (parsed == null) return 'Invalid amount';
                            if (parsed <= 0) return 'Must be > 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _currency,
                          decoration:
                              const InputDecoration(labelText: 'Currency'),
                          items:
                              const ['USD', 'EUR', 'GHS', 'NGN', 'GBP', 'INR']
                                  .map(
                                    (code) => DropdownMenuItem(
                                      value: code,
                                      child: Text(code),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) =>
                              setState(() => _currency = value ?? 'USD'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionLabel(
                    title: 'Billing cadence',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: BillingCycle.values
                          .map(
                            (cycle) => ChoiceChip(
                              label: Text(cycle.name),
                              selected: _billingCycle == cycle,
                              onSelected: (_) =>
                                  setState(() => _billingCycle = cycle),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: _renewalDate ?? now,
                        firstDate: now.subtract(const Duration(days: 1)),
                        lastDate: now.add(const Duration(days: 365 * 5)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context)
                                  .colorScheme
                                  .copyWith(
                                      primary: Theme.of(context)
                                          .colorScheme
                                          .primary),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (selected != null) {
                        setState(() => _renewalDate = selected);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.event_rounded),
                    label: Text(
                      _renewalDate == null
                          ? 'Pick renewal date'
                          : 'Renews ${_renewalDate!.toLocal().toString().split(' ').first}',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<SubscriptionCategory>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: SubscriptionCategory.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _category = value ?? _category),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _paymentController,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                      hintText: 'Visa, Apple Pay, Mobile Money...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-renew enabled'),
                    subtitle: const Text(
                        'Toggle if subscription renews automatically'),
                    value: _autoRenew,
                    onChanged: (value) => setState(() => _autoRenew = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Currently on a free trial'),
                    value: _isTrial,
                    onChanged: (value) => setState(() {
                      _isTrial = value;
                      if (!value) _trialEndDate = null;
                    }),
                  ),
                  if (_isTrial) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final selected = await showDatePicker(
                          context: context,
                          initialDate:
                              _trialEndDate ?? now.add(const Duration(days: 7)),
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (selected != null) {
                          setState(() => _trialEndDate = selected);
                        }
                      },
                      icon: const Icon(Icons.timer_rounded),
                      label: Text(
                        _trialEndDate == null
                            ? 'Trial ends on...'
                            : 'Trial ends ${_trialEndDate!.toLocal().toString().split(' ').first}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _SectionLabel(
                    title: 'Reminders',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [7, 3, 1, 0].map((day) {
                            final selected = _reminderDays.contains(day);
                            return FilterChip(
                              label: Text(
                                  day == 0 ? 'On the day' : '$day days before'),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  if (selected) {
                                    _reminderDays.remove(day);
                                  } else {
                                    _reminderDays.add(day);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customReminderController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Custom reminder (days before)',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _addCustomReminder,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText:
                          'Add context, cancellation policy, login info...',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save subscription'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addCustomReminder() {
    final raw = _customReminderController.text.trim();
    if (raw.isEmpty) return;
    final value = int.tryParse(raw);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number of days')),
      );
      return;
    }
    setState(() {
      _reminderDays.add(value);
      _customReminderController.clear();
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_renewalDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a renewal date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final subscription = Subscription(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      serviceName: _serviceController.text.trim(),
      billingCycle: _billingCycle,
      renewalDate: _renewalDate!,
      currencyCode: _currency,
      cost: double.parse(_costController.text.trim()),
      autoRenew: _autoRenew,
      category: _category,
      paymentMethod: _paymentController.text.trim().isEmpty
          ? 'Unknown'
          : _paymentController.text.trim(),
      reminderDays: _reminderDays.toList()..sort(),
      isTrial: _isTrial,
      trialEndsOn: _isTrial ? _trialEndDate : null,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    await widget.onSubmit(subscription);

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

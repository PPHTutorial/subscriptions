import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive_helper.dart';
import '../../domain/subscription.dart';

class AddSubscriptionSheet extends StatefulWidget {
  const AddSubscriptionSheet(
      {super.key, required this.onSubmit, this.subscription});

  final Future<void> Function(Subscription subscription) onSubmit;
  final Subscription? subscription; // For editing

  @override
  State<AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serviceController;
  late final TextEditingController _costController;
  late final TextEditingController _paymentController;
  late final TextEditingController _notesController;
  final _customReminderController = TextEditingController();

  late DateTime? _renewalDate;
  late DateTime? _trialEndDate;
  late BillingCycle _billingCycle;
  late SubscriptionCategory _category;
  late bool _autoRenew;
  late bool _isTrial;
  late String _currency;
  late Set<int> _reminderDays;
  bool _isSaving = false;
  bool get _isEditing => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final sub = widget.subscription!;
      _serviceController = TextEditingController(text: sub.serviceName);
      _costController = TextEditingController(text: sub.cost.toString());
      _paymentController = TextEditingController(text: sub.paymentMethod);
      _notesController = TextEditingController(text: sub.notes ?? '');
      _renewalDate = sub.renewalDate;
      _trialEndDate = sub.trialEndsOn;
      _billingCycle = sub.billingCycle;
      _category = sub.category;
      _autoRenew = sub.autoRenew;
      _isTrial = sub.isTrial;
      _currency = sub.currencyCode;
      _reminderDays = Set<int>.from(sub.reminderDays);
    } else {
      _serviceController = TextEditingController();
      _costController = TextEditingController();
      _paymentController = TextEditingController(text: 'Mastercard');
      _notesController = TextEditingController();
      _renewalDate = null;
      _trialEndDate = null;
      _billingCycle = BillingCycle.monthly;
      _category = SubscriptionCategory.entertainment;
      _autoRenew = true;
      _isTrial = false;
      _currency = 'USD';
      _reminderDays = {7, 3, 1};
    }
  }

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
        padding: EdgeInsets.fromLTRB(
          ResponsiveHelper.spacing(24),
          ResponsiveHelper.spacing(16),
          ResponsiveHelper.spacing(24),
          ResponsiveHelper.spacing(24),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ResponsiveHelper.spacing(32)),
          ),
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
                      width: ResponsiveHelper.width(64),
                      height: ResponsiveHelper.height(5),
                      margin:
                          EdgeInsets.only(bottom: ResponsiveHelper.spacing(18)),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(ResponsiveHelper.spacing(4)),
                      ),
                    ),
                  ),
                  Text(
                    _isEditing ? 'Edit subscription' : 'Add subscription',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(18)),
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
                  SizedBox(height: ResponsiveHelper.spacing(14)),
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
                      SizedBox(width: ResponsiveHelper.spacing(12)),
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
                  SizedBox(height: ResponsiveHelper.spacing(14)),
                  _SectionLabel(
                    title: 'Billing cadence',
                    child: Wrap(
                      spacing: ResponsiveHelper.spacing(10),
                      runSpacing: ResponsiveHelper.spacing(10),
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
                  SizedBox(height: ResponsiveHelper.spacing(14)),
                  FormField<DateTime>(
                    validator: (value) {
                      if (_renewalDate == null) {
                        return 'Please pick a renewal date & time';
                      }
                      return null;
                    },
                    builder: (field) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            style: ButtonStyle(
                                side: WidgetStatePropertyAll<BorderSide>(
                                    BorderSide(
                                        color: field.errorText != null
                                            ? Theme.of(context)
                                                .colorScheme
                                                .error
                                            : Theme.of(context)
                                                .colorScheme
                                                .outline))),
                            onPressed: () async {
                              final now = DateTime.now();
                              final initialDate = _renewalDate ?? now;

                              // Pick date
                              final selectedDate = await showDatePicker(
                                context: context,
                                initialDate: initialDate,
                                firstDate:
                                    now.subtract(const Duration(days: 1)),
                                lastDate:
                                    now.add(const Duration(days: 365 * 5)),
                              );

                              if (selectedDate != null && mounted) {
                                final selectedTime = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      TimeOfDay.fromDateTime(initialDate),
                                );

                                if (selectedTime != null && mounted) {
                                  setState(() {
                                    _renewalDate = DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                      selectedDate.day,
                                      selectedTime.hour,
                                      selectedTime.minute,
                                    );
                                  });

                                  // IMPORTANT: notify the field that value changed
                                  field.didChange(_renewalDate);
                                }
                              }
                            },
                            icon: const Icon(Icons.event_rounded),
                            label: Text(
                              _renewalDate == null
                                  ? 'Pick renewal date & time'
                                  : 'Renews ${DateFormat('MMM dd, yyyy • HH:mm').format(_renewalDate!)}',
                            ),
                          ),

                          // ⛔ validation message (same style as TextFormField)
                          if (field.errorText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 12),
                              child: Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(14)),
                  DropdownButtonFormField<SubscriptionCategory>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: SubscriptionCategory.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _category = value ?? _category),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(14)),
                  TextFormField(
                    controller: _paymentController,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                      hintText: 'Visa, Apple Pay, Mobile Money...',
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(14)),
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
                    SizedBox(height: ResponsiveHelper.spacing(10)),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final initialDate =
                            _trialEndDate ?? now.add(const Duration(days: 7));

                        // First pick the date
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );

                        if (selectedDate != null && mounted) {
                          // Then pick the time
                          final selectedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(initialDate),
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

                          if (selectedTime != null && mounted) {
                            setState(() {
                              _trialEndDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.timer_rounded),
                      label: Text(
                        _trialEndDate == null
                            ? 'Trial ends on...'
                            : 'Trial ends ${DateFormat('MMM dd, yyyy • HH:mm').format(_trialEndDate!)}',
                      ),
                    ),
                  ],
                  SizedBox(height: ResponsiveHelper.spacing(14)),
                  _SectionLabel(
                    title: 'Reminders',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: ResponsiveHelper.spacing(10),
                          runSpacing: ResponsiveHelper.spacing(10),
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
                        SizedBox(height: ResponsiveHelper.spacing(12)),
                        TextFormField(
                          controller: _customReminderController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Custom reminder (days before)',
                            /*  suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _addCustomReminder,
                            ), */
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(14)),
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
                  SizedBox(height: ResponsiveHelper.spacing(24)),
                  if (_formKey.currentState?.validate() == false)
                    Text(
                      "An input need data. Check your form",
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? SizedBox(
                            width: ResponsiveHelper.width(24),
                            height: ResponsiveHelper.height(24),
                            child:
                                const CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save subscription'),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(24)),
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
    if (_formKey.currentState?.validate() != true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check for form input')),
        );
      }
      return;
    }
    if (_renewalDate == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a renewal date')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    final subscription = Subscription(
      id: _isEditing
          ? widget.subscription!.id
          : DateTime.now().microsecondsSinceEpoch.toString(),
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
      accentColor: _isEditing ? widget.subscription!.accentColor : null,
    );

    try {
      await widget.onSubmit(subscription);
      if (mounted) {
        setState(() => _isSaving = false);
        //// Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data Saved Successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
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
        SizedBox(height: ResponsiveHelper.spacing(12)),
        child,
      ],
    );
  }
}

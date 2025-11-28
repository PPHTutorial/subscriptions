import '../../../subscriptions/domain/subscription.dart';

class EmailSubscriptionMatch {
  EmailSubscriptionMatch({
    required this.serviceName,
    required this.cost,
    required this.currencyCode,
    required this.renewalDate,
    required this.billingCycle,
    required this.confidence,
    this.category,
    this.paymentMethod,
    this.notes,
    this.emailSubject,
    this.emailDate,
  });

  final String serviceName;
  final double cost;
  final String currencyCode;
  final DateTime renewalDate;
  final BillingCycle billingCycle;
  final double confidence; // 0.0 to 1.0
  final SubscriptionCategory? category;
  final String? paymentMethod;
  final String? notes;
  final String? emailSubject;
  final DateTime? emailDate;

  Subscription toSubscription() {
    return Subscription(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      serviceName: serviceName,
      billingCycle: billingCycle,
      renewalDate: renewalDate,
      currencyCode: currencyCode,
      cost: cost,
      autoRenew: true,
      category: category ?? SubscriptionCategory.other,
      paymentMethod: paymentMethod ?? 'Unknown',
      reminderDays: [7, 3, 1],
      notes: notes,
    );
  }
}

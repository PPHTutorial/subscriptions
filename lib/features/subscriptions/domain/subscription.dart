import 'dart:convert';

class Subscription {
  Subscription({
    required this.id,
    required this.serviceName,
    required this.billingCycle,
    required this.renewalDate,
    required this.currencyCode,
    required this.cost,
    required this.autoRenew,
    required this.category,
    required this.paymentMethod,
    required this.reminderDays,
    this.isTrial = false,
    this.trialEndsOn,
    this.notes,
    this.accentColor,
  });

  final String id;
  final String serviceName;
  final BillingCycle billingCycle;
  final DateTime renewalDate;
  final String currencyCode;
  final double cost;
  final bool autoRenew;
  final SubscriptionCategory category;
  final String paymentMethod;
  final List<int> reminderDays;
  final bool isTrial;
  final DateTime? trialEndsOn;
  final String? notes;
  final int? accentColor;

  bool get isPastDue => renewalDate.isBefore(DateTime.now());

  String get billingLabel => switch (billingCycle) {
        BillingCycle.weekly => 'Weekly',
        BillingCycle.monthly => 'Monthly',
        BillingCycle.quarterly => 'Quarterly',
        BillingCycle.yearly => 'Yearly',
        BillingCycle.custom => 'Custom',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceName': serviceName,
        'billingCycle': billingCycle.name,
        'renewalDate': renewalDate.toIso8601String(),
        'currencyCode': currencyCode,
        'cost': cost,
        'autoRenew': autoRenew,
        'category': category.name,
        'paymentMethod': paymentMethod,
        'reminderDays': reminderDays,
        'isTrial': isTrial,
        'trialEndsOn': trialEndsOn?.toIso8601String(),
        'notes': notes,
        'accentColor': accentColor,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        serviceName: json['serviceName'] as String,
        billingCycle:
            BillingCycle.values.byName(json['billingCycle'] as String),
        renewalDate: DateTime.parse(json['renewalDate'] as String),
        currencyCode: json['currencyCode'] as String,
        cost: (json['cost'] as num).toDouble(),
        autoRenew: json['autoRenew'] as bool,
        category:
            SubscriptionCategory.values.byName(json['category'] as String),
        paymentMethod: json['paymentMethod'] as String,
        reminderDays: List<int>.from(json['reminderDays'] as List<dynamic>),
        isTrial: json['isTrial'] as bool? ?? false,
        trialEndsOn: json['trialEndsOn'] != null
            ? DateTime.parse(json['trialEndsOn'] as String)
            : null,
        notes: json['notes'] as String?,
        accentColor: json['accentColor'] as int?,
      );

  Subscription copyWith({
    String? id,
    String? serviceName,
    BillingCycle? billingCycle,
    DateTime? renewalDate,
    String? currencyCode,
    double? cost,
    bool? autoRenew,
    SubscriptionCategory? category,
    String? paymentMethod,
    List<int>? reminderDays,
    bool? isTrial,
    DateTime? trialEndsOn,
    String? notes,
    int? accentColor,
  }) {
    return Subscription(
      id: id ?? this.id,
      serviceName: serviceName ?? this.serviceName,
      billingCycle: billingCycle ?? this.billingCycle,
      renewalDate: renewalDate ?? this.renewalDate,
      currencyCode: currencyCode ?? this.currencyCode,
      cost: cost ?? this.cost,
      autoRenew: autoRenew ?? this.autoRenew,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reminderDays: reminderDays ?? this.reminderDays,
      isTrial: isTrial ?? this.isTrial,
      trialEndsOn: trialEndsOn ?? this.trialEndsOn,
      notes: notes ?? this.notes,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  static String encodeList(List<Subscription> subscriptions) => jsonEncode(
        subscriptions.map((subscription) => subscription.toJson()).toList(),
      );

  static List<Subscription> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Subscription.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

enum BillingCycle { weekly, monthly, quarterly, yearly, custom }

enum SubscriptionCategory {
  entertainment,
  productivity,
  finance,
  utilities,
  education,
  health,
  other
}


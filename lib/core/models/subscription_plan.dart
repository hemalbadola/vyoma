class SubscriptionPlan {
  final String id;
  final String name;
  final String priceLabel;
  final String cta;
  final int amountPaise;
  final int durationDays;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.cta,
    required this.amountPaise,
    required this.durationDays,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      priceLabel: json['priceLabel'] as String,
      cta: json['cta'] as String,
      amountPaise: json['amountPaise'] as int,
      durationDays: json['durationDays'] as int,
    );
  }
}

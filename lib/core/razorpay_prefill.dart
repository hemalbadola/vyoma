/// Razorpay checkout prefill — strict formats to avoid mobile validation errors.

String? formatIndiaContact(String? phone) {
  if (phone == null || phone.trim().isEmpty) return null;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return null;
  final local = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  if (!RegExp(r'^\d{10}$').hasMatch(local)) return null;
  return '+91$local';
}

Map<String, String> buildRazorpayPrefill({
  String? name,
  String? email,
  String? contact,
}) {
  final prefill = <String, String>{};
  final trimmedName = name?.trim();
  if (trimmedName != null && trimmedName.isNotEmpty) {
    prefill['name'] = trimmedName;
  }
  final trimmedEmail = email?.trim();
  if (trimmedEmail != null &&
      trimmedEmail.isNotEmpty &&
      trimmedEmail.contains('@') &&
      !trimmedEmail.contains(' ')) {
    prefill['email'] = trimmedEmail;
  }
  final formattedContact = formatIndiaContact(contact);
  if (formattedContact != null) {
    prefill['contact'] = formattedContact;
  }
  return prefill;
}

String buildOrderReceipt(String planId) {
  final safe = planId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  final receipt = 'vyoma$safe${DateTime.now().millisecondsSinceEpoch}';
  return receipt.length <= 40 ? receipt : receipt.substring(0, 40);
}

/// Razorpay Standard Checkout — UPI-first (India).
class RazorpayCheckoutConfig {
  RazorpayCheckoutConfig._();

  static Map<String, dynamic> get checkoutOptions => {
        'config': {
          'display': {
            'blocks': {
              'upi': {
                'name': 'Pay with UPI',
                'instruments': [
                  {'method': 'upi'},
                ],
              },
            },
            'sequence': ['block.upi'],
            'preferences': {
              'show_default_blocks': true,
            },
            'hide': [
              {
                'method': 'upi',
                'flows': ['collect'],
              },
            ],
          },
        },
        'method': {
          'upi': true,
          'card': true,
          'wallet': true,
          'netbanking': false,
          'emi': false,
          'paylater': false,
        },
      };
}

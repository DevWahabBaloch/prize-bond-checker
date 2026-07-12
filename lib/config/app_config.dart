class AppConfig {
  AppConfig._();

  static const List<String> denominations = [
    'Rs. 100',
    'Rs. 200',
    'Rs. 750',
    'Rs. 1500',
    'Rs. 7500',
    'Rs. 15000',
    'Rs. 25000',
    'Rs. 40000',
  ];

  static const String defaultDenomination = 'Rs. 1500';

  static const List<String> drawCities = [
    'Lahore',
    'Karachi',
    'Islamabad',
    'Rawalpindi',
    'Multan',
    'Faisalabad',
    'Hyderabad',
    'Quetta',
    'Peshawar',
  ];

  // Demo-only bootstrap password for the local admin fallback. A production
  // app should use server-side authentication and role claims instead.
  static const String adminPassword = 'admin@619';

  static const String appName = 'Prize Bond Checker';

  static const String dataDisclaimer =
      'Draw data is simulated for demonstration purposes as approved by the project supervisor. '
      'No official National Savings API is used.';
}

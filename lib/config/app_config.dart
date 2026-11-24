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

  static const String appName = 'Prize Bond Checker';

  static const String simulatedResultsLabel = 'Simulated FYP results';

  static const String dataDisclaimer =
      'Draw data is simulated for demonstration purposes as approved by the project supervisor. '
      'These are sample results. Consult National Savings for official results.';
}

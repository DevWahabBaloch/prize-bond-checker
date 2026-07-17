class BondNumberExtractor {
  BondNumberExtractor._();

  static final RegExp _sixDigitPattern = RegExp(r'\b\d{6}\b');
  static String? extract(String recognizedText) {
    for (final match in _sixDigitPattern.allMatches(recognizedText)) {
      final candidate = match.group(0);
      if (candidate != null && isValidBondNumber(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static bool isValidBondNumber(String candidate) {
    return RegExp(r'^\d{6}$').hasMatch(candidate);
  }
}

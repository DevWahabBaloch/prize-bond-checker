/// Extracts a valid 6-digit Pakistan Prize Bond number from raw OCR text.
///
/// Only a standalone run of exactly 6 digits is accepted. Anything shorter
/// (e.g. "12345"), longer (e.g. "1234567" or "987654321"), or mixed with
/// letters (e.g. "12AB56") is rejected because `\b` (word boundary) fails
/// to match on either side of the digit run in those cases.
class BondNumberExtractor {
  BondNumberExtractor._();

  static final RegExp _sixDigitPattern = RegExp(r'\b\d{6}\b');

  /// Returns the first valid 6-digit number found in [recognizedText],
  /// or `null` if none is present.
  static String? extract(String recognizedText) {
    for (final match in _sixDigitPattern.allMatches(recognizedText)) {
      final candidate = match.group(0);
      if (candidate != null && isValidBondNumber(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  /// Standalone validity check, exposed separately so it can be reused
  /// (e.g. for manual entry validation elsewhere in the app).
  static bool isValidBondNumber(String candidate) {
    return RegExp(r'^\d{6}$').hasMatch(candidate);
  }
}
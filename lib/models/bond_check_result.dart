enum BondCheckOutcome {
  win('Won'),
  noWin('No Win'),
  resultsUnavailable('Results Unavailable');

  const BondCheckOutcome(this.label);

  final String label;
}

class DrawPeriod {
  DrawPeriod(DateTime start, DateTime end)
    : start = DateTime.utc(start.year, start.month, start.day),
      end = DateTime.utc(end.year, end.month, end.day) {
    if (this.end.isBefore(this.start)) throw ArgumentError('The check period must end on or after its start.');
  }

  final DateTime start;
  final DateTime end;

  bool includes(DateTime day) => !day.isBefore(start) && !day.isAfter(end);
}

class DrawCoverage {
  DrawCoverage({
    required this.catalogVersion,
    required this.period,
    required Iterable<String> expectedDrawIds,
    required Iterable<String> checkedDrawIds,
  }) : expectedDrawIds = List.unmodifiable(expectedDrawIds),
       checkedDrawIds = List.unmodifiable(checkedDrawIds);

  final int? catalogVersion;
  final DrawPeriod? period;
  final List<String> expectedDrawIds;
  final List<String> checkedDrawIds;

  bool get hasVerifiedAllExpectedDraws => expectedDrawIds.isNotEmpty && checkedDrawIds.length == expectedDrawIds.length;

  String get summary {
    if (catalogVersion == null) return 'The FYP sample draw catalog is unavailable.';
    if (expectedDrawIds.isEmpty) return 'No eligible FYP sample draws are listed for this check.';
    final checked = checkedDrawIds.length;
    if (hasVerifiedAllExpectedDraws) return 'All eligible FYP sample draws for this check were verified ($checked total).';
    return 'Eligible FYP sample draws verified ($checked of ${expectedDrawIds.length} expected).';
  }
}

class BondWin {
  const BondWin({
    required this.drawId,
    required this.drawNumber,
    required this.drawDate,
    required this.city,
    required this.position,
    required this.amount,
  });

  final String drawId;
  final String drawNumber;
  final String drawDate;
  final String city;
  final String position;
  final String amount;
}

class BondCheckResult {
  const BondCheckResult({required this.number, required this.denomination, required this.coverage, required this.win});

  final String number;
  final String denomination;
  final DrawCoverage coverage;
  final BondWin? win;

  bool get isSimulated => true;

  BondCheckOutcome get outcome {
    if (win != null) return BondCheckOutcome.win;
    return coverage.hasVerifiedAllExpectedDraws ? BondCheckOutcome.noWin : BondCheckOutcome.resultsUnavailable;
  }
}

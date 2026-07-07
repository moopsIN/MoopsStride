String formatHeightToFtIn(double cm) {
  if (cm <= 0) return '--';
  final inches = cm / 2.54;
  final feet = (inches / 12).floor();
  final remainingInches = (inches % 12).round();
  
  if (feet == 0 && remainingInches == 0) return '--';
  return '$feet\' $remainingInches"';
}

double kgToLbs(double kg) {
  return kg * 2.20462;
}

double lbsToKg(double lbs) {
  return lbs / 2.20462;
}

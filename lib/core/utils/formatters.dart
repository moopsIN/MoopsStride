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

const double kmPerMile = 1.609344;

/// Pace as minutes'seconds" per km (or per mile when [isKm] is false), e.g.
/// 5'37". Returns --'--" below walking-crawl speeds, where pace is noise.
String formatPace(double speedKmH, {required bool isKm}) {
  final speedPerUnit = isKm ? speedKmH : speedKmH / kmPerMile;
  if (speedPerUnit < 1.0) return '--\'--"';
  final totalSeconds = (3600 / speedPerUnit).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes\'${seconds.toString().padLeft(2, '0')}"';
}

/// mm:ss, or h:mm:ss from one hour.
String formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mmss = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  return hours > 0 ? '$hours:$mmss' : mmss;
}

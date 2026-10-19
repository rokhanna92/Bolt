// Body measurements are stored metric (kg, cm) and shown in the unit chosen
// in Settings: kg with cm, or lb with inches.

const _lbPerKg = 2.20462;
const _cmPerIn = 2.54;

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String weightUnit(bool metric) => metric ? 'kg' : 'lb';
String lengthUnit(bool metric) => metric ? 'cm' : 'in';

/// Number only, for prefilling an input.
String weightValue(double? kg, {required bool metric}) => kg == null ? '' : _num(metric ? kg : kg * _lbPerKg);
String lengthValue(double? cm, {required bool metric}) => cm == null ? '' : _num(metric ? cm : cm / _cmPerIn);

String fmtWeight(double kg, {required bool metric}) => '${weightValue(kg, metric: metric)} ${weightUnit(metric)}';
String fmtLength(double cm, {required bool metric}) => '${lengthValue(cm, metric: metric)} ${lengthUnit(metric)}';

double? _parse(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', '.'));
  return v == null || v <= 0 ? null : v;
}

/// One step up or down on the bar: 2.5 kg, or 5 lb. A weight between steps
/// moves to the next one first. Down from the first step is bodyweight, null.
double? stepWeight(double? kg, int dir, {required bool metric}) {
  final step = metric ? 2.5 : 5.0;
  final q = (kg == null ? 0.0 : (metric ? kg : kg * _lbPerKg)) / step;
  final n = (q - q.round()).abs() < 1e-6 ? q.round() + dir : (dir > 0 ? q.ceil() : q.floor());
  if (n <= 0) return null;
  return metric ? n * step : n * step / _lbPerKg;
}

/// Parses an input in the current unit back to kg.
double? parseWeight(String s, {required bool metric}) {
  final v = _parse(s);
  return v == null ? null : (metric ? v : v / _lbPerKg);
}

/// Parses an input in the current unit back to cm.
double? parseLength(String s, {required bool metric}) {
  final v = _parse(s);
  return v == null ? null : (metric ? v : v * _cmPerIn);
}

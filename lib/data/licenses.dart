import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a key unlocks. Solo and trainee keys open those ways of training, a
/// coach key coaching too, and the admin key everything.
enum License { solo, trainee, coach, admin }

/// How a go at the key screen ended: in, a real key that is not a coach key on
/// a phone set up for coaching, or not a key at all.
enum KeyResult { ok, needsCoach, wrong }

// Bolt's source is public, so only hashes of the keys live here. The keys
// themselves are handed out by the app's owner. The order is the owner's own
// list: index 0 is Solo 1, Trainee 1, Coach 1.
const _soloKeys = [
  -1699218972452885507,
  -8228332809990388263,
  -7020642279539304697,
  4592168230108353626,
  -2434325509941152438,
  264588874631195842,
  -4641641019768470363,
  7507427674093509024,
  -3667138616108212498,
  1320722925968997886,
];
const _traineeKeys = [
  1687348731917378163,
  -6520802752251929693,
  7628840115633977174,
  -9139240903386426157,
  -2083189154032091953,
  7590181531867274673,
  4738020308501070171,
  -8055275592276008713,
  -6711091327337236941,
  -6393185330360213969,
];
const _coachKeys = [
  8592604027390717746,
  8012939993975502224,
  1051011781709699422,
  -3922828175096279653,
  8187216367353418019,
  -2611910258148722856,
  -60248343148617482,
  4707614899753257330,
  803520510762924265,
  2315544033166269070,
];
const _adminKey = 230909407197158641;

/// Which key generation the app is on. Raising it sends every phone back to
/// the key screen on the next launch, with its training data untouched.
const kKeyGen = 3;

/// 64-bit FNV-1a of the key behind a fixed prefix. Case, spaces and dashes do
/// not matter, so a key can be typed however it is read out.
int licenseHash(String code) {
  final c = code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  var h = 0xcbf29ce484222325;
  for (final b in utf8.encode('bolt-license:$c')) {
    h = (h ^ b) * 0x100000001b3;
  }
  return h;
}

/// What [code] unlocks, or null when it unlocks nothing.
License? checkLicense(String code) {
  final h = licenseHash(code);
  if (h == _adminKey) return License.admin;
  if (_coachKeys.contains(h)) return License.coach;
  if (_traineeKeys.contains(h)) return License.trainee;
  if (_soloKeys.contains(h)) return License.solo;
  return null;
}

/// The name of [code] on the owner's list, like "Solo 3", or null when it is
/// not a key.
String? keyName(String code) {
  final h = licenseHash(code);
  if (h == _adminKey) return 'Admin';
  for (final (name, keys) in const [('Solo', _soloKeys), ('Trainee', _traineeKeys), ('Coach', _coachKeys)]) {
    final i = keys.indexOf(h);
    if (i >= 0) return '$name ${i + 1}';
  }
  return null;
}

/// Names a key for the log. Overridden in tests.
final keyNameProvider = Provider<String? Function(String)>((ref) => keyName);

/// Checks codes in onboarding. Overridden in tests.
final licenseProvider = Provider<License? Function(String)>((ref) => checkLicense);

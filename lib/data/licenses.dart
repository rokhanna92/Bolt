import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a code unlocks: coaching (5 digits) or the admin view (6 digits).
enum License { coach, admin }

/// How a go at the key screen ended: in, recognised but not switched on yet,
/// or not a key at all.
enum KeyResult { ok, pending, wrong }

// Bolt's source is public, so only hashes of the codes live here. The codes
// themselves are handed out by the app's owner. The order is the owner's own
// list: index 0 is Coach 1.
const _coachKeys = [
  -5046494917874319855,
  -7225266335180600691,
  -8597806596250815624,
  4549050317095049273,
  8915874103447610937,
];
const _adminKey = 230909407197158641;

/// How many coach codes there are, for the admin's activation list.
const kCoachKeys = 5;

/// Which key generation the app is on. Raising it sends every phone back to
/// the key screen on the next launch, with its training data untouched.
const kKeyGen = 1;

/// 64-bit FNV-1a of the code behind a fixed prefix.
int licenseHash(String code) {
  var h = 0xcbf29ce484222325;
  for (final b in utf8.encode('bolt-license:$code')) {
    h = (h ^ b) * 0x100000001b3;
  }
  return h;
}

/// What [code] unlocks, or null when it unlocks nothing.
License? checkLicense(String code) {
  final c = code.trim();
  if (coachSlot(c) != null) return License.coach;
  if (c.length == 6 && licenseHash(c) == _adminKey) return License.admin;
  return null;
}

/// Which coach code [code] is, numbered as the owner numbers them (0 is
/// Coach 1), or null when it is not a coach code.
int? coachSlot(String code) {
  final c = code.trim();
  if (c.length != 5) return null;
  final i = _coachKeys.indexOf(licenseHash(c));
  return i < 0 ? null : i;
}

/// Which coach key a code is. Overridden in tests.
final coachSlotProvider = Provider<int? Function(String)>((ref) => coachSlot);

/// Checks codes in onboarding. Overridden in tests.
final licenseProvider = Provider<License? Function(String)>((ref) => checkLicense);

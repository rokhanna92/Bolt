import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a code unlocks: coaching (5 digits) or the admin view (6 digits).
enum License { coach, admin }

// Bolt's source is public, so only hashes of the codes live here. The codes
// themselves are handed out by the app's owner.
const _coachKeys = {
  -5046494917874319855,
  -7225266335180600691,
  -8597806596250815624,
  4549050317095049273,
  8915874103447610937,
};
const _adminKey = 230909407197158641;

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
  if (c.length == 5 && _coachKeys.contains(licenseHash(c))) return License.coach;
  if (c.length == 6 && licenseHash(c) == _adminKey) return License.admin;
  return null;
}

/// Checks codes in onboarding. Overridden in tests.
final licenseProvider = Provider<License? Function(String)>((ref) => checkLicense);

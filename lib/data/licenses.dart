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
  'e86b2958ef576bfd',
  '8dcf16e7a6d4c5d9',
  '9e91ab0b30f89707',
  '3fbaa8acc871545a',
  'de3789d8a849354a',
  '03ac022dfbe9acc2',
  'bf959415c1d184a5',
  '682fbdb18b47d9a0',
  'cd1bb4dba4c09eee',
  '12542680f118bdfe',
];
const _traineeKeys = [
  '176aaabb52242273',
  'a58174720da25ba3',
  '69df15aa749cf756',
  '812ae4d1f4ee94d3',
  'e317068069f87ccf',
  '6955bde383adddb1',
  '41c0d45e12cb015b',
  '9035e9870a83a0f7',
  'a2dd69fea2dbf633',
  'a746d7d088a41e2f',
];
const _coachKeys = [
  '773f0fd65c36ef32',
  '6f33ae785b6e3590',
  '0e95f1a59f8e995e',
  'c98f508f0c7e0d9b',
  '719ed5e88b5d5123',
  'dbc0a1756dd8b758',
  'ff29f4737c5220f6',
  '4154cecf2f210972',
  '0b26ada5b5c3b8e9',
  '20227707a6a69a8e',
];
const _adminKey = '03345ae1e7485cf1';

/// Which key generation the app is on. Raising it sends every phone back to
/// the key screen on the next launch, with its training data untouched.
const kKeyGen = 3;

/// 64-bit FNV-1a of the key behind a fixed prefix, as 16 hex digits. Case,
/// spaces and dashes do not matter, so a key can be typed however it is read
/// out. Worked in 16-bit pieces because browser ints stop at 53 bits, so a key
/// hashes the same on a phone and on the web.
String licenseHash(String code) {
  final c = code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  // 0xcbf29ce484222325, lowest piece first.
  var (a, b, d, e) = (0x2325, 0x8422, 0x9ce4, 0xcbf2);
  for (final byte in utf8.encode('bolt-license:$c')) {
    a ^= byte;
    // Times the FNV prime, 0x100000001b3: h * 0x1b3 + (h << 40).
    final r0 = a * 0x1b3;
    final r1 = b * 0x1b3 + (r0 >> 16);
    final r2 = d * 0x1b3 + (a << 8) + (r1 >> 16);
    final r3 = e * 0x1b3 + (b << 8) + (r2 >> 16);
    (a, b, d, e) = (r0 & 0xffff, r1 & 0xffff, r2 & 0xffff, r3 & 0xffff);
  }
  return [e, d, b, a].map((p) => p.toRadixString(16).padLeft(4, '0')).join();
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

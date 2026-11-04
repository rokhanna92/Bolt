import 'package:bolt/data/share_codes.dart';
import 'package:flutter_test/flutter_test.dart';

// Real codes from each side, so phones and browsers keep reading each other's
// messages. Runs on both: flutter test, and flutter test --platform chrome.
const _fromPhone =
    'BOLT1.H4sIAAAAAAAAA2XSMQ6CYAyG4auYzsTQVhS4gAdwNA4YGYwoKj8xxngDj-XBDKN9x77Tky99SXpeW6nl0d9P_ZgGyeTSnKfy_bSHfjqlLvN5kUl3HJLUW1n3-65Ns81tbNIsl-w_aAwWg8ewiKGIYRnDKoYyhgowUmFVYBVaBVfhVYAVYgVZYTaYjfvCbDAbzAazwWwwG8wGs8PsMDufAmaH2WF2mB1mh9kr2b1_xY1lifoCAAA=';
const _fromBrowser =
    'BOLT1.H4sIAEcT62oA_2XSMQrCUAyA4auUzEWaxGrbC3gAR3Go2EGsPrWviIg38FgeTDv6_jE_GT5CnhIfl04auYfbMYxxkFzO7Wkqn3e3D9MoTVXMylz6wxCl2cgq7PouZuvr2Mas-G38BU2DpcHTME9DmYZFGpZpqNJQA0YqrAqsQqvgKrwKsEKsICvMBrPxvjAbzAazwWwwG8wGs8HsMDvMzqeA2WF2mB1mh9lh9lq2ry_FjWWJ-gIAAA==';

void main() {
  for (final (who, code) in const [('a phone', _fromPhone), ('a browser', _fromBrowser)]) {
    test('reads a code made on $who', () {
      final packet = ShareCode.decode('Bolt workouts:\n\n$code')!;
      expect(packet['type'], 'workouts');
      expect(packet['name'], 'Čedo');
      expect(packet['n'], 80.5);
      expect(packet['list'], hasLength(40));
    });
  }

  test('survives a round trip here', () {
    final packet = {'name': 'Đorđe', 'kg': 62.5, 'reps': 'max'};
    expect(ShareCode.decode(ShareCode.encode(packet)), packet);
  });

  test('a damaged code reads as nothing', () {
    expect(ShareCode.decode('BOLT1.AAAA'), isNull);
  });
}

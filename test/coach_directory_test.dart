import 'dart:convert';
import 'dart:io';

import 'package:bolt/services/coach_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coaches need a name, specialty is optional', () {
    final list = parseCoaches(
      jsonDecode('''[
        {"name": " Marko Ilić ", "specialty": "Strength"},
        {"name": "Sara"},
        {"name": ""},
        {"specialty": "No name"},
        "Ana",
        {"name": "Ivo", "specialty": 3}
      ]'''),
    );
    expect([for (final c in list) '${c.name}|${c.specialty}'], ['Marko Ilić|Strength', 'Sara|', 'Ivo|']);
    expect(parseCoaches({'coaches': []}), isEmpty);
  });

  test('the list in the repo is valid', () {
    final json = jsonDecode(File('coaches.json').readAsStringSync());
    expect(json, isA<List>());
    expect(parseCoaches(json), hasLength((json as List).length));
  });
}

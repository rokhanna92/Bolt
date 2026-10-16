// Serbian (Latin script) translations, keyed by the English text in the
// code. See l10n.dart.

import 'sr_content.dart';
import 'sr_ui.dart';

const kSr = <String, String>{...kSrUi, ...kSrContent};

/// Noun forms for [plural]: one, few (2-4), many.
const kSrNouns = <String, List<String>>{
  'session': ['trening', 'treninga', 'treninga'],
  'workout': ['trening', 'treninga', 'treninga'],
  'exercise': ['vežba', 'vežbe', 'vežbi'],
  'set': ['serija', 'serije', 'serija'],
  'rep': ['ponavljanje', 'ponavljanja', 'ponavljanja'],
  'day': ['dan', 'dana', 'dana'],
  'week': ['nedelja', 'nedelje', 'nedelja'],
  'trainee': ['vežbač', 'vežbača', 'vežbača'],
  'hour': ['sat', 'sata', 'sati'],
  'gym hour': ['sat u teretani', 'sata u teretani', 'sati u teretani'],
  'gym visit': ['dolazak u teretanu', 'dolaska u teretanu', 'dolazaka u teretanu'],
  'gym day': ['dan u teretani', 'dana u teretani', 'dana u teretani'],
  'rest day': ['dan odmora', 'dana odmora', 'dana odmora'],
  'training day': ['dan treninga', 'dana treninga', 'dana treninga'],
  'early check-in': ['rani dolazak', 'rana dolaska', 'ranih dolazaka'],
  'late check-in': ['kasni dolazak', 'kasna dolaska', 'kasnih dolazaka'],
  'PR': ['PR', 'PR-a', 'PR-ova'],
  'perfect week': ['savršena nedelja', 'savršene nedelje', 'savršenih nedelja'],
  'weekend workout': ['vikend trening', 'vikend treninga', 'vikend treninga'],
  'long session': ['dug trening', 'duga treninga', 'dugih treninga'],
  'new workout': ['novi trening', 'nova treninga', 'novih treninga'],
  'own workout': ['sopstveni trening', 'sopstvena treninga', 'sopstvenih treninga'],
  'diary day': ['dan iz dnevnika', 'dana iz dnevnika', 'dana iz dnevnika'],
  'full workout': ['kompletan trening', 'kompletna treninga', 'kompletnih treninga'],
  'chest day': ['dan za grudi', 'dana za grudi', 'dana za grudi'],
  'back day': ['dan za leđa', 'dana za leđa', 'dana za leđa'],
  'leg day': ['dan za noge', 'dana za noge', 'dana za noge'],
  'shoulder day': ['dan za ramena', 'dana za ramena', 'dana za ramena'],
  'arm day': ['dan za ruke', 'dana za ruke', 'dana za ruke'],
  'core day': ['dan za trbuh', 'dana za trbuh', 'dana za trbuh'],
  'cardio day': ['kardio dan', 'kardio dana', 'kardio dana'],
};

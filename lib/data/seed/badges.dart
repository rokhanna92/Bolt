// Badges, ported verbatim from `BADGES` in Bolt UI.html.

enum BadgeShape { plate, kb, hex }

class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.shape,
    required this.big,
    required this.unit,
    required this.name,
    required this.desc,
    required this.key,
    required this.goal,
  });

  final String id;
  final BadgeShape shape;
  final String big;
  final String unit;
  final String name;
  final String desc;

  /// Stats counter this badge reads.
  final String key;
  final int goal;
}

const kBadges = <BadgeDef>[
  BadgeDef(id: 's1', shape: BadgeShape.plate, big: '1', unit: 'SESSION', name: 'First Rep', desc: 'Check in for the first time.', key: 'sessions', goal: 1),
  BadgeDef(id: 's10', shape: BadgeShape.plate, big: '10', unit: 'SESSIONS', name: 'Ten Down', desc: 'Complete 10 gym sessions.', key: 'sessions', goal: 10),
  BadgeDef(id: 's25', shape: BadgeShape.plate, big: '25', unit: 'SESSIONS', name: '25 Club', desc: 'Complete 25 gym sessions.', key: 'sessions', goal: 25),
  BadgeDef(id: 's100', shape: BadgeShape.plate, big: '100', unit: 'SESSIONS', name: 'Century', desc: 'Complete 100 gym sessions.', key: 'sessions', goal: 100),
  BadgeDef(id: 'h10', shape: BadgeShape.kb, big: '10H', unit: 'TRAINED', name: 'Under the Bar', desc: 'Spend 10 hours in the gym.', key: 'hours', goal: 10),
  BadgeDef(id: 'h50', shape: BadgeShape.kb, big: '50H', unit: 'TRAINED', name: 'Iron Hours', desc: 'Spend 50 hours in the gym.', key: 'hours', goal: 50),
  BadgeDef(id: 'w4', shape: BadgeShape.kb, big: '4W', unit: 'STREAK', name: 'Clockwork', desc: 'Four weeks without missing a planned session.', key: 'streak', goal: 4),
  BadgeDef(id: 'w12', shape: BadgeShape.kb, big: '12W', unit: 'STREAK', name: 'Unbroken', desc: 'Twelve weeks without missing a planned session.', key: 'streak', goal: 12),
  BadgeDef(id: 'am', shape: BadgeShape.hex, big: 'AM', unit: 'BEFORE 7', name: 'Early Bird', desc: 'Check in before 7:00 five times.', key: 'early', goal: 5),
  BadgeDef(id: 'pm', shape: BadgeShape.hex, big: 'PM', unit: 'AFTER 21', name: 'Late Shift', desc: 'Check in after 21:00 five times.', key: 'late', goal: 5),
  BadgeDef(id: 'pr', shape: BadgeShape.hex, big: 'PR', unit: '× 5', name: 'PR Hunter', desc: 'Set five personal records.', key: 'prs', goal: 5),
  BadgeDef(id: 'pw', shape: BadgeShape.hex, big: 'ALL', unit: 'IN A WEEK', name: 'Full House', desc: 'Finish every planned session in a week.', key: 'perfect', goal: 1),
];

/// Unit word per counter, for "3 sessions to go".
const kBadgeUnits = <String, String>{
  'sessions': 'session',
  'hours': 'hour',
  'streak': 'week',
  'early': 'early check-in',
  'late': 'late check-in',
  'prs': 'PR',
  'perfect': 'perfect week',
};

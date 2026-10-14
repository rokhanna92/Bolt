# Bolt — Gym coaching app (Flutter / Android)

Build instructions for implementing the **Bolt** UI prototype as a production Flutter app. The prototype file `Bolt UI.html` in the repo root is the **source of truth**. Open it in a browser and match it screen for screen: layout, copy, colors, spacing, states, animations.

All seed content (workout templates, splits, exercise how-tos, supplements, badges, demo users) lives in the `<script>` logic section of `Bolt UI.html`. Search for `const TPL`, `SPLITS`, `WHY`, `HOW`, `SUPPS` and `BADGES`, and port them **verbatim** into Dart seed files.

---

## 1. Stack

| Concern | Choice |
|---|---|
| Framework | Flutter 3.24+, Dart 3, Material 3 (heavily themed, dark only) |
| Platform | Android first (minSdk 24). Keep the code iOS-safe. |
| State | `flutter_riverpod` (Notifier/AsyncNotifier) |
| Routing | `go_router` with a `StatefulShellRoute` per role (trainee / coach) |
| Backend | Supabase (Postgres + Auth + Realtime). Realtime is needed so coach and trainee changes appear live. |
| Local cache | `drift` or `isar` for offline plans and visits |
| QR | `mobile_scanner` |
| Notifications | `firebase_messaging` (push) + `flutter_local_notifications` (reminders) |
| Fonts | Archivo (variable, with `wdth` axis) + JetBrains Mono, **bundled as assets** (not google_fonts) |
| Models | `freezed` + `json_serializable` |

---

## 2. Design tokens (`lib/theme/tokens.dart`)

### Colors
```
ink        #0A0B09   app background
surface1   #141612   cards
surface2   #1C1F19   chips / confirmed cells
sheet      #111310   bottom sheets
line       #2E332A   borders
lineSoft   #23271F   card borders
divider    #1E221B
text       #F1F4EC
textSoft   #C9CEC2
muted      #9CA393   secondary text
muted2     #80877A
muted3     #6E7566
muted4     #5E6558   numbering, past days
neon       #C6FF1A   primary accent (Ronaldinho green)
warn       #FF7A45   injuries / destructive
```
Rules: only **one** accent (neon) plus warn for injuries. Text on neon is always `ink`. There are no gradients except the fade behind the bottom nav (ink at 70% → transparent).

### Typography
- **Display / headings:** Archivo, weight 900, `FontVariation('wdth', 112–125)`, uppercase for workout titles, letter-spacing −0.02 to −0.03 em, line height 0.95.
- **Body:** Archivo 400–800.
- **Labels, numbers, timers, dates:** JetBrains Mono 500–700, uppercase, letter-spacing 0.08–0.14 em, sizes 9–13 px.
- Workout title auto-size: ≤6 chars → base size, ≤9 → 74 %, longer → 56 % (see `tsz()`).

### Shape and spacing
- Radii: cards 16–20, hero card 24, sheets 28 (top corners), buttons 12–16, chips 99 (pill), calendar cells 12.
- Screen padding: 20 horizontal, 20 top, 120 bottom (clears the nav).
- Primary button: height 50–56, radius 14–16, neon fill, ink text, weight 800. Secondary: 1.5 px outline.
- Minimum touch target: 44 dp.

---

## 3. Roles and navigation

Two roles share one app. The role comes from the user profile after login.

**Trainee bottom nav (5):** Today · Plan · **[Scan, raised centre]** · Badges · Me
**Coach bottom nav (5):** Trainees · Schedule · **[Scan, raised centre]** · Library · Profile

Centre button: 58×58, radius 20, neon fill, ink QR-frame icon, raised 18 dp above the bar, neon glow shadow. Its label underneath is either "Check in" or the live duration (e.g. `42m`) in mono.
Inactive tabs: a pill indicator 52×30 behind the icon, tinted `neon @14 %` when active. Icons are **custom SVGs** (barbell, calendar, kettlebell, initials avatar, group, weight plate). Export them from the HTML; do not use Material Icons.

Pushed (non-tab) routes: Workout session, Trainee detail (coach), Editor, Learn, Settings, Plaque.
Modal bottom sheets: Day detail, Exercise how-to, Exercise picker, Injury report, Add coach.
Full-screen overlays: QR scanner, Badge unlocked.

---

## 4. Screens

### Trainee
1. **Today**: date line (mono), greeting, avatar. A live "In the gym" strip with a pulsing dot and HH:MM:SS timer when checked in. A **neon hero card** for today's workout (status pill, huge uppercase title, focus, chips for exercises/sets/minutes, injury warning, **Start workout** + **Details**). Variants: done card (outlined) and rest-day card. Coach note card. 7-day week strip (today inverted white). Learn card. A dashed-neon **"Coach planned N sessions"** card with **Accept all**.
2. **Plan**: month calendar with prev/next. Each cell shows the day number + a 4-letter template code (PUSH, PULL, LEGS…). There is a legend and a "Coming up" list. Tapping a planned day opens the **Day sheet**. **Move mode**: a neon banner appears, free future days tint neon at 9 %, and tapping one moves the session (status → moved, coach notified).
3. **Gym**: big ring (rotating neon arc + glow) with a live timer, or a dashed "Not in" ring. Scan button. Stats: this week, visits, average visit. A 6-week bar chart (current week in neon; bars animate up). Visit log (in → out, duration).
4. **Badges**: count, "closest" progress card, 3-column grid of 12 badges in three gym shapes: **weight plate** (sessions), **kettlebell** (hours/streaks), **hex dumbbell head** (special). Locked badges are grey with a progress bar.
5. **Me**: avatar, chips (goal, split, since), stats (sessions, hours, week streak), injuries list + **Report**, coach card, settings button.
6. **Workout session**: title, progress bar, coach note, one card per exercise with tappable **set buttons**. Done = neon. All sets done → card border turns neon. The **i** button opens the how-to sheet. Injury swap. The **Rest timer** bar starts automatically when a set is checked (default 90 s, −15/+15/Skip, progress line). **Finish** logs "x/y sets".

### Coach
1. **Trainees (roster)**: header, a horizontally scrolling "In the gym now" list, a **Needs you** list (moved sessions → OK, new injury → Review, unconfirmed → Nudge, nothing planned → Plan), and trainee cards with a 7-dot week strip, injury tag, and a neon ring when in the gym.
2. **Schedule**: week navigation, counts (sessions / confirmed / open), day sections listing every trainee's session with a status pill. Tap → trainee detail.
3. **Trainee detail**: split selector (tap cycles), **Auto-fill 3 wks**, injury flags (resolve / add), calendar. Tapping an empty future day adds the **next workout in the rotation** as a draft. A selected day shows a template chip switcher, the exercise list, **Edit exercises** and **Remove**. A floating **Send N sessions to {name}** button appears while drafts exist. Recent visits list.
4. **Editor**: for one day or for a template. Per exercise: sets stepper, reps and load fields, remove, and an injury swap. **+ Add exercise** (picker sheet), a note to the trainee, and Save. Saving a day sends it for approval; saving a template affects future auto-fills only.
5. **Library**: 2-column template grid + **New**, weekly split previews (7 cells with codes), Learn link.
6. **Profile**: stats, coach list + **Add coach** (unlimited coaches), plaque QR entry.
7. **Plaque**: the printable static QR (BOLT, "SCAN IN · SCAN OUT").

### Shared
- **Learn**: segmented tabs Workouts / Exercises / Supplements (content from `WHY`, `HOW`, `SUPPS`). Keep the medical disclaimer copy.
- **Settings**: toggles (session reminders, plan updates, check-out reminder after 3 h), units kg/lb (converts loads app-wide), week start, rest timer default, home gym, sign out.

---

## 5. Data model (Supabase tables)

```
gyms(id, name, plaque_token)                 -- plaque_token is static, printed on the QR
coaches(id, user_id, gym_id, name, specialty)
trainees(id, user_id, coach_id, name, goal, split_id, since)
templates(id, gym_id, code, name, focus, minutes, is_custom)
template_exercises(id, template_id, order, name, sets, reps, load, area, alt_name)
splits(id, name, short_name) ; split_days(split_id, weekday 1-7, template_id)
sessions(id, trainee_id, date, template_id, title, focus, minutes, status, moved_from, note, log)
session_exercises(id, session_id, order, name, sets, reps, load, area, alt_name, swapped_from)
set_logs(session_exercise_id, set_index, done_at)
injuries(id, trainee_id, area, note, created_by_role, created_at, seen_by_coach, resolved_at)
visits(id, user_id, gym_id, check_in, check_out)          -- coaches can check in too
achievements(user_id, badge_id, unlocked_at)
```
Sessions **copy** the template's exercises when created, so later template edits never change planned days.

---

## 6. Business rules

**Session status machine**
```
draft ──send──▶ pending ──trainee accept──▶ approved ──finish──▶ done
                   │                            │
                   └──trainee moves─────────────┴──▶ moved ──coach OK──▶ approved
coach edits any non-done session ──▶ draft (must be re-sent)
```
- Trainees never see drafts.
- Calendar styles: done = neon fill; approved = surface2 + line border; pending = 1.5 px dashed neon; moved = surface2 + 1.5 px white border; draft = dashed muted2.
- Moving only works onto empty days that are today or later.

**Auto-fill**: for the next 3 weeks (from this Monday), put each split day's template on its weekday if that date is today or later **and** empty. Status = draft.
**Tap empty day**: template = the one after the most recent earlier session in the split rotation, or the first one.

**Injuries**: areas are knee, lower back, shoulder, elbow, wrist, ankle. Any exercise whose `area` matches an active injury shows a warn banner, plus **Swap** to `alt_name` if one exists. A swap records `swapped_from`. Trainee-reported injuries notify the coach and show in Needs you.

**QR check-in**: one permanent QR per gym (`bolt://checkin?gym=<plaque_token>`). Scanning it toggles: if no open visit, create one (check-in); otherwise close it (check-out). Show the success overlay for 1.8 s, then evaluate badges. Reject a scan with the wrong token. Use server time. If a visit is still open after 3 h, send a reminder. Auto-close after 5 h (flag it as auto).

**Badges** (`BADGES` array): sessions 1/10/25/100, hours 10/50, streak weeks 4/12, early check-ins before 07:00 ×5, late check-ins after 21:00 ×5, PRs ×5, perfect week ×1. Evaluate on check-out and on workout finish. Show the unlock overlay for each new one.

**Rest timer**: starts on set completion with the default from settings. Run it as a foreground countdown and vibrate at 0.

---

## 7. Motion

| Element | Animation |
|---|---|
| Screen enter | fade + 10 dp slide up, 350 ms, easeOut |
| Bottom sheets | slide from bottom 350 ms, curve (0.2, 0.8, 0.2, 1); scrim fades in 250 ms |
| Set button | color 200 ms; press scale 0.94 |
| Buttons | press scale 0.96–0.97 |
| Live dot | pulsing ring shadow 1.6 s loop |
| Gym ring | neon arc rotating 3 s linear + glow breathing 2.4 s |
| Scanner | neon laser line sweeping 2.2 s, glowing corner brackets |
| Check-in success | circle pop (scale 0.3 → 1.1 → 1), then text fade-ups staggered by 150/250 ms |
| Badge unlock | rotate −220° + scale 0.2 → 1 with overshoot, 900 ms |
| Bars / progress | grow from 0, 600 ms |
| Toast | white pill above nav, slide up 300 ms, auto-dismiss 2.6 s |

---

## 8. Project structure
```
lib/
  main.dart, app.dart (router, theme)
  theme/ tokens.dart, text_styles.dart, bolt_theme.dart
  data/ models/, repositories/, seed/ (templates.dart, splits.dart, learn.dart, badges.dart)
  features/
    auth/  today/  plan/  gym/  badges/  profile/  workout/  learn/  settings/
    coach_roster/  coach_schedule/  coach_trainee/  editor/  library/  coach_profile/  plaque/
  widgets/ bolt_nav_bar.dart, calendar_grid.dart, status_pill.dart, badge_medal.dart,
           bolt_sheet.dart, primary_button.dart, live_timer.dart, icons/ (custom SVG painters)
assets/ fonts/ (Archivo-Variable.ttf, JetBrainsMono-*.ttf), icons/*.svg
```

---

## 9. Acceptance checklist
- [ ] Every screen in `Bolt UI.html` exists, with identical copy, colors and hierarchy
- [ ] Coach → draft → send → trainee accept / move → coach OK flows live via Realtime
- [ ] Auto-fill and rotation rules behave as in section 6
- [ ] Injury flags show swaps everywhere exercises appear (day sheet, workout, editor, coach detail)
- [ ] The same static QR checks in and checks out; visits and durations are correct across midnight
- [ ] Badges unlock with the overlay; locked ones show progress
- [ ] Rest timer, kg/lb toggle and notification toggles work
- [ ] Unlimited coaches; each coach sees only their own trainees
- [ ] 60 fps animations on a mid-range Android phone

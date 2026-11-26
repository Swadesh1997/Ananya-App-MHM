import 'package:flutter_test/flutter_test.dart';
import 'package:ananya/widgets/cycle_visuals.dart';

/// The four phases, and which one a given cycle day falls in.
///
/// These boundaries used to be worked out twice — the bar derived segment
/// widths while the caption derived day boundaries — and the two were off by
/// one. It was invisible only because the bar had no marker on it. Now that a
/// "today" pin sits on the bar, a disagreement would put the pin in one phase
/// while the words underneath named another.

CyclePhases phases({int cycle = 28, int bleed = 5}) =>
    CyclePhases.forCycle(cycleDays: cycle, bleedDays: bleed, isBangla: false);

/// Which phase a given cycle day falls in, by POSITION rather than by the
/// words on screen: 0 menstrual, 1 follicular, 2 ovulation, 3 luteal.
///
/// It used to compare the phase's display text. That made a boundary test
/// fail whenever the copy was reworded, which says nothing about boundaries —
/// and the copy is reworded, because the clinical names meant little to the
/// reader this screen is for.
int? phaseIndexAt(int day, {int cycle = 28, int bleed = 5}) {
  final p = phases(cycle: cycle, bleed: bleed);
  final match = p.phaseFor(day);
  return match == null ? null : p.all.indexOf(match);
}

void main() {
  group('phase boundaries for a 28-day cycle with a 5-day period', () {
    test('the four phases tile the cycle with no gaps or overlaps', () {
      final p = phases().all;

      expect(p.first.from, 1);
      expect(p.last.to, 28);
      for (var i = 1; i < p.length; i++) {
        expect(p[i].from, p[i - 1].to + 1,
            reason: 'phase ${p[i].term} must start the day after '
                '${p[i - 1].term} ends');
      }
      expect(p.fold<int>(0, (sum, x) => sum + x.length), 28);
    });

    test('every phase has at least one day', () {
      for (final x in phases().all) {
        expect(x.length, greaterThan(0), reason: x.term);
      }
    });

    // The exact days named in the brief.
    test('day 1 -> menstrual', () => expect(phaseIndexAt(1), 0));
    test('day 5 -> menstrual', () => expect(phaseIndexAt(5), 0));
    test('day 6 -> follicular', () => expect(phaseIndexAt(6), 1));
    test('day 12 -> follicular', () => expect(phaseIndexAt(12), 1));
    test('day 13 -> ovulation', () => expect(phaseIndexAt(13), 2));
    test('day 15 -> ovulation', () => expect(phaseIndexAt(15), 2));
    test('day 16 -> luteal', () => expect(phaseIndexAt(16), 3));
    test('day 28 -> luteal', () => expect(phaseIndexAt(28), 3));

    test('the drawn widths match the named boundaries', () {
      // This is the bug that made the two implementations disagree: the bar
      // drew follicular 8 days wide (6-13) while the caption called day 13
      // ovulation.
      final p = phases().all;
      expect(p[0].length, 5, reason: 'menstrual, days 1-5');
      expect(p[1].length, 7, reason: 'follicular, days 6-12');
      expect(p[2].length, 3, reason: 'ovulation, days 13-15');
      expect(p[3].length, 13, reason: 'luteal, days 16-28');
    });
  });

  group('other cycle and period lengths', () {
    test('a 35-day cycle still tiles cleanly', () {
      final p = phases(cycle: 35, bleed: 6).all;
      expect(p.first.from, 1);
      expect(p.last.to, 35);
      expect(p.fold<int>(0, (s, x) => s + x.length), 35);
      for (final x in p) {
        expect(x.length, greaterThan(0), reason: x.term);
      }
    });

    test('a 21-day cycle still tiles cleanly', () {
      final p = phases(cycle: 21, bleed: 4).all;
      expect(p.last.to, 21);
      expect(p.fold<int>(0, (s, x) => s + x.length), 21);
      for (final x in p) {
        expect(x.length, greaterThan(0), reason: x.term);
      }
    });

    test('a long period cannot swallow the follicular phase', () {
      // 12 days of bleeding in a 28-day cycle is not plausible, but a mistyped
      // setting must not produce an empty or negative phase.
      final p = phases(cycle: 28, bleed: 12).all;
      for (final x in p) {
        expect(x.length, greaterThan(0), reason: x.term);
      }
      expect(p.fold<int>(0, (s, x) => s + x.length), 28);
    });

    test('a nonsense cycle length falls back to 28 rather than breaking', () {
      expect(phases(cycle: 0, bleed: 5).cycleDays, 28);
      expect(phases(cycle: 3, bleed: 5).cycleDays, 28);
    });

    test('the bleed length drives the first boundary', () {
      expect(phaseIndexAt(7, bleed: 7), 0);
      expect(phaseIndexAt(8, bleed: 7), 1);
    });
  });

  group('edge states', () {
    test('no logged period means no phase, not a guessed one', () {
      expect(phases().phaseFor(null), isNull);
      expect(phases().phaseFor(0), isNull);
      expect(phases().phaseFor(-3), isNull);
    });

    test('a cycle running past its expected length stays in the last phase',
        () {
      // Day 31 of a 28-day cycle: she is not off the end of the model, her
      // cycle simply ran longer than predicted.
      expect(phaseIndexAt(31), 3);
      expect(phaseIndexAt(60), 3);
    });
  });

  group('wording', () {
    test('plain language leads, the medical term is separate', () {
      final bn = CyclePhases.forCycle(
          cycleDays: 28, bleedDays: 5, isBangla: true);
      final en = phases();

      for (var i = 0; i < en.all.length; i++) {
        expect(en.all[i].plain, isNotEmpty);
        expect(en.all[i].term, isNotEmpty);
        expect(en.all[i].plain, isNot(en.all[i].term),
            reason: 'the plain wording must not just repeat the term');
        expect(bn.all[i].plain, isNot(en.all[i].plain),
            reason: 'Bangla must actually be translated');
      }
    });

    test('every phase is distinguishable by more than its colour', () {
      final p = phases().all;
      expect(p.map((x) => x.plain).toSet().length, 4);
      expect(p.map((x) => x.term).toSet().length, 4);
    });
  });

  group('drawn widths', () {
    test('the four segments fill the bar exactly', () {
      for (final c in [16, 21, 28, 35]) {
        final p = phases(cycle: c, bleed: 5);
        final sum = p.weights.reduce((a, b) => a + b);
        expect(sum, closeTo(1.0, 1e-9), reason: 'cycle $c');
      }
    });

    test('a one-day phase is still drawn wide enough to see', () {
      // A 16-day cycle leaves the follicular phase 1 day long. At true scale
      // that is 6% of the bar — a sliver you cannot see and cannot point at.
      final p = phases(cycle: 16, bleed: 5);
      expect(p.all[1].length, 1, reason: 'the sliver case we are guarding');

      final raw = p.all[1].length / p.cycleDays;
      expect(p.weights[1], greaterThan(raw),
          reason: 'the drawn width must be widened above true scale');
      expect(p.weights[1], greaterThan(0.07),
          reason: 'and must end up visible');
    });

    test('no phase is ever drawn as a sliver, at any cycle length', () {
      for (final c in [16, 18, 21, 24, 28, 35, 45]) {
        for (final b in [2, 5, 8]) {
          final p = phases(cycle: c, bleed: b);
          for (var i = 0; i < p.weights.length; i++) {
            expect(p.weights[i], greaterThan(0.07),
                reason: 'cycle $c bleed $b: ${p.all[i].term} too thin');
          }
        }
      }
    });

    test('widening one phase does not reorder or drop any', () {
      final p = phases(cycle: 16, bleed: 5);
      expect(p.weights.length, 4);
      expect(p.all.length, 4);
    });
  });

  group('the marker agrees with the highlighted phase', () {
    test('28-day cycle, every day', () => markerLandsInItsOwnPhase(28, 5));
    test('21-day cycle, every day', () => markerLandsInItsOwnPhase(21, 4));
    test('35-day cycle, every day', () => markerLandsInItsOwnPhase(35, 6));
    test('16-day cycle with a sliver phase', () =>
        markerLandsInItsOwnPhase(16, 5));
    test('long period, every day', () => markerLandsInItsOwnPhase(28, 12));

    test('a day past the cycle pins at the end, never outside', () {
      final p = phases(cycle: 28, bleed: 5);
      for (final day in [29, 31, 60]) {
        final m = p.markerFraction(day);
        expect(m, lessThanOrEqualTo(1.0));
        expect(m, greaterThanOrEqualTo(0.0));
      }
      expect(p.markerFraction(31), p.markerFraction(28),
          reason: 'past the end it should hold at the last day, not drift');
    });

    test('day 1 sits inside the first segment, not on the rail', () {
      final p = phases();
      expect(p.markerFraction(1), greaterThan(0.0));
      expect(p.markerFraction(1), lessThan(p.weights[0]));
    });
  });
}

/// The marker and the highlighted segment must agree.
///
/// Segment widths are floored so a one-day phase stays visible, which means the
/// bar is no longer exactly to scale. The marker therefore cannot be placed at
/// day/cycle — it has to be placed against the same floored layout, or it would
/// drift out of the very phase the caption names. This checks it never does.
void markerLandsInItsOwnPhase(int cycle, int bleed) {
  final p =
      CyclePhases.forCycle(cycleDays: cycle, bleedDays: bleed, isBangla: false);

  for (var day = 1; day <= p.cycleDays; day++) {
    final phase = p.phaseFor(day)!;
    final index = p.all.indexOf(phase);

    var lo = 0.0;
    for (var i = 0; i < index; i++) {
      lo += p.weights[i];
    }
    final hi = lo + p.weights[index];
    final marker = p.markerFraction(day);

    expect(marker, greaterThanOrEqualTo(lo - 1e-9),
        reason: 'day $day of $cycle/$bleed: marker sits before ${phase.term}');
    expect(marker, lessThanOrEqualTo(hi + 1e-9),
        reason: 'day $day of $cycle/$bleed: marker sits after ${phase.term}');
  }
}

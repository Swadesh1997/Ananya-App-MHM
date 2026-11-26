import 'package:ananya/services/period_history_service.dart';
import 'dart:math' as math;

import 'package:ananya/utils/constants.dart';
import 'package:flutter/material.dart';

import 'package:ananya/utils/bangla_date.dart';

/// Circular countdown to the next predicted period.
///
/// The arc shows how far through the current cycle she is, so the number in the
/// middle has something to sit against — "17 days left" alone says nothing about
/// whether that is early or nearly due.
class CycleRing extends StatelessWidget {
  /// 0.0 at the start of the cycle, 1.0 the day the next period is due.
  final double progress;

  /// Big number in the centre, already in the right digits.
  final String value;

  /// Small caption under it.
  final String label;

  /// Optional line above the number, e.g. "Period coming".
  final String? topLabel;

  final double size;

  const CycleRing({
    required this.progress,
    required this.value,
    required this.label,
    this.topLabel,
    this.size = 92,
    super.key,
  });

  /// A single line that fits inside the ARC, not merely inside the padding.
  ///
  /// The padding reserves a rectangle 72% of the ring wide, which is the right
  /// amount at the vertical middle and far too much near the top and bottom,
  /// where the circle has curved inwards. The label above the number sits
  /// exactly there: it measured as fitting, and crossed the stroke anyway —
  /// "পরের পিরিয়ড আসতে" ran straight over the arc on the right.
  ///
  /// 62% is the chord the circle actually leaves at the height these two lines
  /// occupy, with a little to spare. Text that needs more is scaled down
  /// rather than wrapped, so the ring keeps its three-line shape.
  Widget _fitted(String text, TextStyle style) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: size * 0.62),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress.clamp(0.0, 1.0), size),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (topLabel != null) ...[
                  _fitted(
                    topLabel!,
                    TextStyle(
                      color: ACCENT.withValues(alpha: 0.5),
                      fontSize: size * 0.062,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: size * 0.03),
                ],
                // Shrinks to fit rather than wrapping.
                //
                // This slot was sized for a number and given words. At 210px
                // the ring is 151px wide inside its padding, and the value is
                // set at 63pt: "Today" wrapped to two lines and overflowed the
                // fixed box by 42px, "Any day now" wrapped to three and
                // overflowed by 240. In debug that paints the striped banner;
                // in release it silently clips. Both were visible on the main
                // screen, and the second occurs for several days each cycle
                // for anyone whose cycle has not been measured.
                //
                // scaleDown leaves a one- or two-digit countdown at full size
                // — its natural width is far inside the limit, so the scale
                // factor is 1 — and only shrinks the strings that would not
                // otherwise fit. softWrap false keeps it on one line so the
                // column's height cannot grow either.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: PRIMARY_COLOR,
                        fontSize: size * 0.30,
                        fontWeight: FontWeight.bold,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
                _fitted(
                  label,
                  TextStyle(
                    color: ACCENT.withValues(alpha: 0.62),
                    fontSize: size * 0.068,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double ringSize;

  const _RingPainter(this.progress, this.ringSize);

  @override
  void paint(Canvas canvas, Size size) {
    // Proportional: a 7px stroke that reads right at 92px looks like a hairline
    // at 210px.
    final stroke = (ringSize * 0.075).clamp(6.0, 16.0);
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = PRIMARY_COLOR.withValues(alpha: 0.12);

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = PRIMARY_COLOR;

    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    if (progress > 0) {
      // Starts at 12 o'clock and runs clockwise, the direction people expect a
      // countdown to move.
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringSize != ringSize;
}

/// One named stretch of the cycle, as a range of cycle days.
class CyclePhase {
  /// First cycle day of this phase, 1-based and inclusive.
  final int from;

  /// Last cycle day of this phase, inclusive.
  final int to;

  /// What being in this phase means, in words she already uses.
  final String plain;

  /// Two or three words, for the key under the bar.
  final String short;

  /// The name the learning material gives it. Kept, but never leading.
  final String term;

  /// Full strength, used for the phase she is in today.
  final Color active;

  /// The same colour stepped back, for the phases she is not in.
  final Color muted;

  const CyclePhase({
    required this.from,
    required this.to,
    required this.plain,
    required this.short,
    required this.term,
    required this.active,
    required this.muted,
  });

  int get length => to - from + 1;
  bool contains(int day) => day >= from && day <= to;
}

/// The four phases of one cycle — the single place their boundaries, their
/// drawn widths, and the position of the today marker are all decided.
///
/// This exists because the boundaries used to be worked out twice: the bar
/// derived segment *widths* while the caption derived day *boundaries*, and the
/// two were off by one. Nobody could see it while the bar had no marker; the
/// moment one is added, the pin sits in a segment the caption disagrees with.
///
/// The drawn widths live here for the same reason. They are NOT simply the
/// phase lengths: a short measured cycle can make a phase one day long, which
/// at true scale is a sliver too thin to see. Widths are floored — and because
/// that makes the drawing no longer exactly to scale, the marker has to be
/// placed against the floored layout too, or it would drift out of its own
/// phase. Both come from here so they cannot disagree.
class CyclePhases {
  final List<CyclePhase> all;

  /// Cycle length actually used, after the guards below.
  final int cycleDays;

  /// Share of the bar each phase is drawn with, summing to 1.
  final List<double> weights;

  const CyclePhases._(this.all, this.cycleDays, this.weights);

  /// No phase may be drawn thinner than this share of the bar. A phase she
  /// cannot see is worse than one drawn a little generously.
  static const double _minShare = 0.09;

  factory CyclePhases.forCycle({
    required int cycleDays,
    required int bleedDays,
    required bool isBangla,
  }) {
    // Guards against nonsense settings — a zero cycle or a bleed longer than
    // the cycle would otherwise produce empty or negative phases.
    final cycle = cycleDays < 8 ? 28 : cycleDays;

    // Ovulation is counted back from the next period rather than taken as the
    // midpoint, which is only correct at 28 days — see
    // PeriodHistoryService.ovulationDayOfCycle. The bleed is clamped first so
    // the two agree about where bleeding ends.
    final provisionalBleed = bleedDays.clamp(1, math.max(1, cycle - 4)).toInt();
    // Null-safe: the function now declines rather than throwing when no valid
    // day exists. The pre-clamp above keeps that from happening here, so the
    // fallback is unreachable in practice — it is kept so a future change to
    // the clamp cannot reintroduce a crash. The bar's own midpoint is used,
    // which is what this widget drew before ovulation was counted back.
    final ovulationMid = PeriodHistoryService.ovulationDayOfCycle(
          cycle,
          bleedDays: provisionalBleed,
        ) ??
        (cycle ~/ 2);
    final ovulationStart = ovulationMid - 1;
    // Two days of headroom so the follicular phase is never empty.
    final bleed =
        provisionalBleed.clamp(1, math.max(1, ovulationStart - 2)).toInt();
    final ovulationEnd = ovulationMid + 1;

    final phases = [
      // One word for menstruation throughout: পিরিয়ড. The Bangla here mixed
      // পিরিয়ড and মাসিক between the key, the status line and the rest of the
      // screen, so the same thing appeared under two names on one card.
      //
      // The subtitles say where a phase sits relative to the period rather
      // than naming it clinically. "লুটিয়াল ধাপ" and "ফলিকুলার ধাপ" are
      // transliterated Latin — they carry no meaning for a reader who has not
      // been taught the words, which is the reader this screen is for. The
      // English is kept equivalent for the same reason.
      CyclePhase(
        from: 1,
        to: bleed,
        plain: isBangla ? 'পিরিয়ড চলছে' : 'Your period',
        short: isBangla ? 'পিরিয়ড' : 'Period',
        term: isBangla ? 'পিরিয়ডের সময়' : 'While you bleed',
        active: PRIMARY_COLOR,
        muted: PRIMARY_COLOR.withValues(alpha: 0.45),
      ),
      CyclePhase(
        from: bleed + 1,
        to: ovulationStart - 1,
        plain: isBangla ? 'পিরিয়ডের পরের সময়' : 'After your period',
        short: isBangla ? 'পিরিয়ডের পর' : 'After period',
        term: isBangla ? 'ডিম্বস্ফোটনের আগের ধাপ' : 'Before ovulation',
        active: PRIMARY_COLOR.withValues(alpha: 0.62),
        muted: PRIMARY_COLOR.withValues(alpha: 0.32),
      ),
      CyclePhase(
        from: ovulationStart,
        to: ovulationEnd,
        plain: isBangla ? 'ডিম্বস্ফোটনের সময়' : 'Ovulation time',
        short: isBangla ? 'ডিম্বস্ফোটন' : 'Ovulation',
        term: isBangla ? 'ডিম বের হওয়ার সময়' : 'When an egg is released',
        active: SECONDARY_COLOR.withValues(alpha: 0.70),
        muted: SECONDARY_COLOR.withValues(alpha: 0.35),
      ),
      CyclePhase(
        from: ovulationEnd + 1,
        to: cycle,
        plain: isBangla
            ? 'পরের পিরিয়ডের অপেক্ষায়'
            : 'Waiting for your next period',
        short: isBangla ? 'পরের পিরিয়ডের অপেক্ষায়' : 'Before next period',
        term: isBangla ? 'পিরিয়ডের আগের ধাপ' : 'The phase before your period',
        active: ACCENT.withValues(alpha: 0.48),
        muted: ACCENT.withValues(alpha: 0.22),
      ),
    ];

    final floored = phases
        .map((p) => math.max(p.length / cycle, _minShare))
        .toList(growable: false);
    final total = floored.reduce((a, b) => a + b);
    final weights =
        floored.map((f) => f / total).toList(growable: false);

    return CyclePhases._(phases, cycle, weights);
  }

  /// The phase [cycleDay] falls in.
  ///
  /// A day past the end of the expected cycle stays in the last phase rather
  /// than falling off the model — her cycle simply ran longer than predicted,
  /// which is ordinary and not an error state.
  CyclePhase? phaseFor(int? cycleDay) {
    if (cycleDay == null || cycleDay < 1) return null;
    for (final p in all) {
      if (p.contains(cycleDay)) return p;
    }
    return all.last;
  }

  /// Where the today marker sits, as 0..1 across the drawn bar.
  ///
  /// Measured against [weights], not against the raw day count, so the marker
  /// lands inside the segment its own phase is drawn as even where that segment
  /// was widened by the minimum above.
  double markerFraction(int cycleDay) {
    final day = cycleDay.clamp(1, cycleDays);
    final phase = phaseFor(day) ?? all.last;
    final index = all.indexOf(phase);

    // How far through its own phase this day is, as 0..1.
    final within = ((day - phase.from) + 0.5) / phase.length;

    var before = 0.0;
    for (var i = 0; i < index; i++) {
      before += weights[i];
    }
    return (before + within.clamp(0.0, 1.0) * weights[index]).clamp(0.0, 1.0);
  }
}

/// The cycle as a timeline, with today marked on it.
///
/// The four phases are still drawn to scale, because seeing that a cycle has
/// parts is worth something. But the question this has to answer first is
/// "where am I today", so the day she is on is marked, her current phase is the
/// only one at full strength, and the key underneath says what each colour
/// means rather than leaving three of the four as decoration.
class CyclePhaseTimeline extends StatelessWidget {
  /// Total cycle length in days.
  final int cycleDays;

  /// Bleed length in days.
  final int bleedDays;

  /// Which day of the cycle today is, or null when nothing has been logged and
  /// there is therefore no honest answer.
  final int? cycleDay;

  const CyclePhaseTimeline({
    required this.cycleDays,
    required this.bleedDays,
    required this.cycleDay,
    super.key,
  });

  static const double _barHeight = 24;
  static const double _restingSegment = 7;
  static const double _activeSegment = 12;
  static const double _markerSize = 15;

  @override
  Widget build(BuildContext context) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    final phases = CyclePhases.forCycle(
      cycleDays: cycleDays,
      bleedDays: bleedDays,
      isBangla: isBangla,
    );
    final current = phases.phaseFor(cycleDay);
    final hasData = current != null;
    final overrun = cycleDay != null && cycleDay! > phases.cycleDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Both halves stay on one line and shrink if they have to.
        //
        // Wrapping and ellipsising were both tried and both looked broken in
        // Bangla: the heading split across two lines while the day beside it
        // was cut to "আজ · চক্রের ২৪তম …". The phrases are longer there than
        // in English and the row is the same width, so something has to give,
        // and a slightly smaller line is the only one of the three that still
        // reads as finished text.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  // Not a literal "Where you are now": in Bangla that reads
                  // as a question about her physical location. This names the
                  // thing the section is actually about.
                  isBangla
                      ? 'আপনার চক্রের বর্তমান অবস্থা'
                      : 'Your cycle right now',
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: PRIMARY_COLOR,
                  ),
                ),
              ),
            ),
            if (hasData) ...[
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    isBangla
                        // "চক্রের" spelled out: "২৪তম দিন" on its own does
                        // not say the day of WHAT, and the heading beside it
                        // is the only other place that says it.
                        ? 'আজ · চক্রের ${localeNumber(cycleDay!, true)}তম দিন'
                        : 'Today · day ${localeNumber(cycleDay!, false)}',
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: ACCENT,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: _barHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  for (var i = 0; i < phases.all.length; i++)
                    Expanded(
                      // Floored widths, so a one-day phase is still visible.
                      flex: (phases.weights[i] * 1000).round(),
                      child: Center(
                        child: Container(
                          // Height is the second cue, so the current phase is
                          // still identifiable without knowing what the colours
                          // mean.
                          height: hasData && phases.all[i] == current
                              ? _activeSegment
                              : _restingSegment,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: !hasData
                                ? phases.all[i].muted
                                : (phases.all[i] == current
                                    ? phases.all[i].active
                                    : phases.all[i].muted),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Today. A dot on a track, not a line: a line at the end of the
              // bar reads as an edge or a divider, while a ringed dot is the
              // shape every slider uses and needs no interpreting. Align keeps
              // it inside the component at both extremes, so it cannot clip.
              if (hasData)
                AnimatedAlign(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment:
                      Alignment(phases.markerFraction(cycleDay!) * 2 - 1, 0),
                  child: Container(
                    width: _markerSize,
                    height: _markerSize,
                    decoration: BoxDecoration(
                      color: ACCENT,
                      shape: BoxShape.circle,
                      // The ring is what keeps it legible wherever it lands.
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: ACCENT.withValues(alpha: 0.22),
                          blurRadius: 5,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- the key. Without it three of the four colours mean nothing, and
        // the bar asks four questions while answering one.
        // One line, always, at one size.
        //
        // This was a Wrap, which put the fourth Bangla label — "পরের
        // পিরিয়ডের অপেক্ষায়" — on a row of its own while the other three
        // shared the first. The key reads as a single scale of the cycle, and
        // breaking it in two made the last phase look like a separate thing.
        //
        // Scaling the whole row rather than each item keeps every label the
        // same size: shrinking only the one that does not fit would make the
        // longest phase the smallest text on the line.
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < phases.all.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  _KeyItem(
                    colour: !hasData
                        ? phases.all[i].muted
                        : (phases.all[i] == current
                            ? phases.all[i].active
                            : phases.all[i].muted),
                    label: phases.all[i].short,
                    // The key doubles as a second place her position is
                    // stated, which is what makes this readable without
                    // relying on colour.
                    isCurrent: hasData && phases.all[i] == current,
                  ),
                ],
              ],
            ),
          ),
        ),

        // The phase she is in is not restated in prose underneath.
        //
        // It used to be, twice: the phase's plain name and then its
        // description, directly below a key that already highlights the same
        // phase in bold and a bar that already marks it. Three statements of
        // one fact read as three facts. The key carries it.
        //
        // What survives is the empty state, which has no bar to read, and the
        // overrun note, which says something the diagram cannot.
        if (!hasData) ...[
          const SizedBox(height: 12),
          Text(
            isBangla
                ? 'আপনার চক্রের অবস্থা দেখতে একটি পিরিয়ড যোগ করুন'
                : 'Add a period to see where you are in your cycle',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: ACCENT.withValues(alpha: 0.68),
            ),
          ),
        ] else if (overrun) ...[
          const SizedBox(height: 10),
          Text(
            // States what is true — the predicted window has passed — without
            // telling her she is late, which this arithmetic cannot know.
            isBangla
                ? 'প্রত্যাশিত সময় পেরিয়ে গেছে'
                : 'Past the expected window',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: PRIMARY_COLOR.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );
  }
}

/// One colour and its meaning, in the key under the timeline.
class _KeyItem extends StatelessWidget {
  final Color colour;
  final String label;
  final bool isCurrent;

  const _KeyItem({
    required this.colour,
    required this.label,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        // Plain, and deliberately not flexible: the key's row is laid out
        // inside a FittedBox, which gives its children unbounded width, and a
        // flex child cannot live there. Fitting is handled once, for the
        // whole row, so that every label ends up the same size.
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 11.5,
            // Weight, not just colour, marks the one she is in.
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: ACCENT.withValues(alpha: isCurrent ? 1.0 : 0.68),
          ),
        ),
      ],
    );
  }
}

import 'dart:math';
import 'package:ananya/widgets/app_loader.dart';

import 'package:flutter/material.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/models/myth_data.dart';
import 'package:ananya/utils/bangla_date.dart';
import 'package:ananya/utils/constants.dart';

class MythBusterScreen extends StatefulWidget {
  const MythBusterScreen({super.key});

  @override
  State<MythBusterScreen> createState() => _MythBusterScreenState();
}

class _MythBusterScreenState extends State<MythBusterScreen> {
  final Random _rng = Random();

  /// Statements already asked, across every round and every previous visit.
  Set<int> _seen = {};

  List<Myth> _round = const [];

  /// What she answered for each statement in this round, by index. Kept so the
  /// end of the round can show every statement back with its correct answer —
  /// the score alone tells her how many she missed but not which.
  List<bool?> _answers = const [];

  int _index = 0;
  int _correct = 0;
  bool _loading = true;

  bool? get _picked => _index < _answers.length ? _answers[_index] : null;

  bool get _answered => _picked != null;
  bool get _wasRight => _picked == _round[_index].isTrue;
  bool get _isLast => _index == _round.length - 1;
  bool get _finished => _round.isEmpty || _index >= _round.length;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    final seen = await MythProgress.load();
    if (!mounted) return;
    setState(() {
      _seen = seen;
      _round = buildMythRound(mythPool, _rng, seen: _seen);
      _answers = List<bool?>.filled(_round.length, null);
      _index = 0;
      _correct = 0;
      _loading = false;
    });
  }

  void _choose(bool value) {
    if (_answered) return;
    setState(() {
      _answers[_index] = value;
      if (value == _round[_index].isTrue) _correct++;
    });
  }

  Future<void> _advance() async {
    if (_isLast) {
      // Banked only once the round is finished, so abandoning halfway does
      // not silently burn six statements whose answers she never saw.
      await MythProgress.add(_seen, _round);
      if (!mounted) return;
      setState(() => _index = _round.length);
      return;
    }
    setState(() => _index++);
  }

  /// Another round, drawn only from what she has not been asked yet.
  Future<void> _nextRound() async {
    final next = buildMythRound(mythPool, _rng, seen: _seen);
    if (!mounted) return;
    setState(() {
      _round = next;
      _answers = List<bool?>.filled(next.length, null);
      _index = 0;
      _correct = 0;
    });
  }

  Future<void> _startOver() async {
    await MythProgress.reset();
    await _begin();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bn = Localizations.localeOf(context).languageCode == 'bn';

    return Scaffold(
      backgroundColor: BACKGROUND,
      body: SafeArea(
        child: _loading
            ? const AppLoader()
            : Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: _finished ? _result(loc, bn) : _question(loc, bn),
              ),
      ),
    );
  }

  // --------------------------------------------------------------- chrome

  Widget _topBar(AppLocalizations loc, bool bn) {
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: ACCENT.withValues(alpha: 0.10)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.arrow_back, size: 19, color: ACCENT),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc.myth_eyebrow.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: ACCENT.withValues(alpha: 0.38),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                loc.myth_quiz_title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                  color: ACCENT,
                ),
              ),
            ],
          ),
        ),
        if (!_finished)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: PRIMARY_COLOR.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              loc.myth_progress(
                localeNumber(_index + 1, bn),
                localeNumber(_round.length, bn),
              ),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: PRIMARY_COLOR,
              ),
            ),
          ),
      ],
    );
  }

  /// One segment per statement: how many are left is legible at a glance,
  /// which a single sliding bar never shows.
  Widget _progressBar() {
    final done = _index + (_answered ? 1 : 0);
    return Row(
      children: [
        for (var i = 0; i < _round.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 5,
              decoration: BoxDecoration(
                color: i < done ? PRIMARY_COLOR : ACCENT.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------- question

  Widget _question(AppLocalizations loc, bool bn) {
    final Myth myth = _round[_index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topBar(loc, bn),
        const SizedBox(height: 16),
        _progressBar(),
        const SizedBox(height: 16),

        // The card fills whatever height is left rather than hugging its
        // text, so the screen never opens with a void between the statement
        // and the buttons.
        Expanded(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: ACCENT.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // A soft disc bleeding off the top corner. Purely to give the
                // card some life; it is clipped by the card's own radius.
                Positioned(
                  right: -46,
                  top: -46,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: PRIMARY_COLOR.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: PRIMARY_COLOR.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '“',
                          style: TextStyle(
                            fontSize: 34,
                            height: 2.0,
                            fontWeight: FontWeight.w700,
                            color: PRIMARY_COLOR.withValues(alpha: 0.85),
                          ),
                        ),
                      ),

                      // The statement takes the middle of the card, with the
                      // subject tag pinned below it.
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 22),
                              Text(
                                myth.statement(loc),
                                style: const TextStyle(
                                  fontSize: 22.5,
                                  height: 1.5,
                                  fontWeight: FontWeight.w700,
                                  color: ACCENT,
                                ),
                              ),
                              if (_answered) ...[
                                const SizedBox(height: 22),
                                Container(
                                    height: 1,
                                    color: ACCENT.withValues(alpha: 0.08)),
                                const SizedBox(height: 20),
                                _verdict(loc, myth),
                              ],
                              const SizedBox(height: 18),
                            ],
                          ),
                        ),
                      ),

                      // What the statement is about, so a question arrives
                      // with a subject rather than out of nowhere.
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: PRIMARY_COLOR,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              myth.category.label(loc),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ACCENT.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (!_answered)
          Row(
            children: [
              Expanded(
                child: _choiceButton(
                    loc.myth_true, true, Icons.check_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _choiceButton(
                    loc.myth_false, false, Icons.close_rounded),
              ),
            ],
          )
        else
          _primaryButton(
            _isLast ? loc.myth_see_result : loc.myth_next,
            _advance,
            color: ACCENT,
          ),
      ],
    );
  }

  Widget _choiceButton(String label, bool value, IconData icon) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _choose(value),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ACCENT.withValues(alpha: 0.12), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: ACCENT.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Both choices carry equal visual weight. Colouring one of them
            // would nudge the answer before she has thought about it.
            Icon(icon, size: 20, color: ACCENT.withValues(alpha: 0.45)),
            const SizedBox(width: 9),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: ACCENT,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The correction, shown whether she was right or wrong — being right for
  /// the wrong reason is still worth correcting, and the reason is the part
  /// she can repeat to someone else.
  Widget _verdict(AppLocalizations loc, Myth myth) {
    final good = _wasRight;
    final tone = good ? SECONDARY_COLOR : PRIMARY_COLOR;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(
                good ? Icons.check_rounded : Icons.priority_high_rounded,
                size: 17,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                good ? loc.myth_correct : loc.myth_incorrect,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: tone,
                ),
              ),
            ),
            // States what the statement actually was, so the correction can
            // never be ambiguous about which way round it goes.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                myth.isTrue ? loc.myth_true : loc.myth_false,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          myth.answer(loc),
          style: TextStyle(
            fontSize: 15,
            height: 1.7,
            color: ACCENT.withValues(alpha: 0.80),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- result

  Widget _result(AppLocalizations loc, bool bn) {
    final exhausted = MythProgress.isExhausted(mythPool, _seen);
    final left = MythProgress.remaining(mythPool, _seen);
    final total = _round.isEmpty ? mythRoundSize : _round.length;
    final ratio = total == 0 ? 0.0 : _correct / total;

    final message = ratio >= 0.83
        ? loc.myth_result_strong
        : ratio >= 0.5
            ? loc.myth_result_mixed
            : loc.myth_result_low;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topBar(loc, bn),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: ACCENT.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: exhausted
                      ? [
                          Text(
                            loc.myth_done_title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: ACCENT,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            loc.myth_done_body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.65,
                              color: ACCENT.withValues(alpha: 0.65),
                            ),
                          ),
                        ]
                      : [
                          Text(
                            loc.myth_round_done,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: ACCENT.withValues(alpha: 0.42),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _scoreRing(bn, ratio),
                          const SizedBox(height: 24),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17.5,
                              height: 1.5,
                              fontWeight: FontWeight.w700,
                              color: ACCENT,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Container(
                              height: 1, color: ACCENT.withValues(alpha: 0.08)),
                          const SizedBox(height: 22),
                          _recap(loc, bn),
                        ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!exhausted) ...[
          Text(
            loc.myth_continue_prompt(localeNumber(left, bn)),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ACCENT.withValues(alpha: 0.50),
            ),
          ),
          const SizedBox(height: 10),
          _primaryButton(loc.myth_continue, _nextRound, color: PRIMARY_COLOR),
        ] else
          _primaryButton(loc.myth_start_over, _startOver,
              color: PRIMARY_COLOR),
      ],
    );
  }

  /// Every statement from the round, with the right answer and whether she
  /// got it. The score says how many she missed; this says which, which is
  /// the part worth reading.
  Widget _recap(AppLocalizations loc, bool bn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          loc.myth_your_answers,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: ACCENT.withValues(alpha: 0.42),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < _round.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _recapRow(loc, bn, i),
        ],
      ],
    );
  }

  Widget _recapRow(AppLocalizations loc, bool bn, int i) {
    final myth = _round[i];
    final picked = i < _answers.length ? _answers[i] : null;
    final right = picked == myth.isTrue;
    final tone = right ? SECONDARY_COLOR : PRIMARY_COLOR;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: BACKGROUND.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(
                  right ? Icons.check_rounded : Icons.close_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  myth.statement(loc),
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: ACCENT,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Row(
              children: [
                Text(
                  loc.myth_correct_answer,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ACCENT.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: (myth.isTrue ? SECONDARY_COLOR : PRIMARY_COLOR)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    myth.isTrue ? loc.myth_true : loc.myth_false,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: myth.isTrue ? SECONDARY_COLOR : PRIMARY_COLOR,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 8),
            child: Text(
              myth.answer(loc),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: ACCENT.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Score as a ring, echoing the cycle countdown on the home screen so the
  /// two read as the same app.
  Widget _scoreRing(bool bn, double ratio) {
    return SizedBox(
      width: 136,
      height: 136,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 136,
            height: 136,
            child: CircularProgressIndicator(
              value: ratio,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: PRIMARY_COLOR.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(PRIMARY_COLOR),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localeNumber(_correct, bn),
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                  color: ACCENT,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '/ ${localeNumber(_round.length, bn)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ACCENT.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap,
      {required Color color}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        minimumSize: const Size(double.infinity, 58),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

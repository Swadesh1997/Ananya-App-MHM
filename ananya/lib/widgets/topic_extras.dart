import 'package:ananya/utils/probahini_gate.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:ananya/utils/constants.dart';

/// Hands the reader on to the chatbot with the topic she just read.
///
/// The article was a dead end: everything the app knows about the subject had
/// been shown, and any question she still had went nowhere. Probahini already
/// exists and is reachable from the home screen only, so almost nobody arrives
/// there from the place a question actually occurs to them.
class AskProbahiniButton extends StatelessWidget {
  /// The topic's own question, sent as the opening message.
  final String question;

  const AskProbahiniButton({required this.question, super.key});

  /// Probahini answers from a server, so it is one of the few things in the
  /// app that genuinely cannot work offline. Rather than hiding the button —
  /// which would make the feature invisible on the patchy connections these
  /// users have most of the time — it stays visible and says plainly what is
  /// missing when tapped.
  Future<bool> _hasNetwork() async {
    try {
      final r = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 4));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: PRIMARY_COLOR.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: PRIMARY_COLOR,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 17, color: Colors.white),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  isBangla
                      ? 'আরও কিছু জানার আছে?'
                      : 'Still have a question?',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: ACCENT,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              final online = await _hasNetwork();
              if (!context.mounted) return;
              if (!online) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isBangla
                          ? 'প্রবাহিনীর সাথে কথা বলতে ইন্টারনেট সংযোগ প্রয়োজন।'
                          : 'Talking to Probahini needs an internet connection.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              openProbahini(context, question: question);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PRIMARY_COLOR,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(
              isBangla ? 'প্রবাহিনীকে জিজ্ঞাসা করুন' : 'Ask Probahini',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

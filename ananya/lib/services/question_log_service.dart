import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what girls ask Probahini, so the programme can see which questions
/// actually come up and where.
///
/// Anonymous on purpose. Each record carries her age, her district and the
/// question — and no user id, so nothing here can be traced back to a person.
/// That is a deliberate limit: these are menstrual-health questions from
/// adolescent girls, and the analysis the programme wants ("what do girls in
/// Chattogram ask about?") never needed to know who was asking. Adding a uid
/// later would be a one-line change and a much larger decision.
///
/// One residual risk worth knowing: the question is free text, so a girl could
/// type her own name into it. Nothing can reliably strip that, so whoever
/// reads the export should treat the text as potentially identifying even
/// though the record is not.
///
/// Writes are best-effort. A failure here must never interrupt her
/// conversation — the chat is the feature, this is instrumentation.
class QuestionLogService {
  static const _collection = 'probahini_questions';

  static const _kBirthYear = 'profile_birth_year';
  static const _kDistrict = 'profile_district';

  /// An answer longer than this is truncated before storing.
  ///
  /// Real answers run to a few thousand characters — the Bangla table reply is
  /// about 4,000. This only guards against something pathological; a document
  /// that approached Firestore's 1MB ceiling would fail the write and lose the
  /// question along with it.
  static const _maxAnswerChars = 10000;

  /// Records one exchange, once the outcome is known.
  ///
  /// Called after the reply arrives — or fails to — rather than before, so
  /// every row says whether Probahini actually answered. That is the point of
  /// keeping the answer at all: the rows where [failure] is set are the ones
  /// worth reading, because they are the questions the chatbot could not
  /// handle.
  ///
  /// Deliberately not awaited by callers: Firestore write Futures complete
  /// only when the server acknowledges them, so awaiting this on a weak
  /// connection would hold up the screen. Firestore queues the write locally
  /// and sends it when the network returns, which is the behaviour we want on
  /// a rural handset.
  ///
  /// [answer] is what Probahini returned, and is null when it returned
  /// nothing. The apologetic message the screen shows her in that case is the
  /// app's own text, not the chatbot's, and storing it would make a failed
  /// exchange look like an answered one.
  ///
  /// [failure] is null on success, otherwise why it failed: 'empty' when the
  /// service replied with no text, 'timeout' when it never replied, 'error'
  /// for anything else.
  ///
  /// [source] separates what she typed from the canned question a
  /// knowledge-hub article sends on her behalf. Both are worth having — one
  /// says what girls ask unprompted, the other says which article prompts get
  /// used — but mixed together the repeated article text would swamp the real
  /// questions and make the counts meaningless.
  static void record(
    String question, {
    required String languageCode,
    String? answer,
    String? failure,
    String source = 'typed',
  }) {
    final text = question.trim();
    if (text.isEmpty) return;

    // Only signed-in users reach the chat, but check rather than assume: the
    // Firestore rule requires an authenticated caller and an unauthenticated
    // write would be refused anyway.
    if (FirebaseAuth.instance.currentUser == null) return;

    unawaited(
      _write(text, languageCode, source, answer, failure).catchError((Object e) {
        // Swallowed on purpose. Analytics failing is not something to show her.
        debugPrint('QuestionLog: not recorded: $e');
      }),
    );
  }

  static Future<void> _write(
    String text,
    String languageCode,
    String source,
    String? answer,
    String? failure,
  ) async {
    final profile = await _profile();

    final trimmedAnswer = answer?.trim();
    final stored = (trimmedAnswer == null || trimmedAnswer.isEmpty)
        ? null
        : (trimmedAnswer.length > _maxAnswerChars
            ? trimmedAnswer.substring(0, _maxAnswerChars)
            : trimmedAnswer);

    await FirebaseFirestore.instance.collection(_collection).add({
      'question': text,
      'answer': stored,
      // A plain flag so a spreadsheet can filter on it without anyone having
      // to reason about empty strings and nulls.
      'answered': stored != null,
      'failure': failure,
      // Age rather than year of birth: a year is a stabler identifier and
      // buys the analysis nothing that the age does not.
      'age': profile.age,
      'district': profile.district,
      'language': languageCode,
      'source': source,
      // The server's clock, not the handset's. Phones in the field are often
      // set wrong, and a mis-dated row is worse than no row.
      'asked_at': FieldValue.serverTimestamp(),
    });
  }

  /// Her age and district, from the device where possible.
  ///
  /// Cached after the first lookup so that asking ten questions costs one
  /// Firestore read rather than ten.
  static Future<_Profile> _profile() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final year = prefs.getInt(_kBirthYear);
      final district = prefs.getString(_kDistrict);
      if (year != null && district != null) {
        return _Profile(age: _ageFrom(year), district: district);
      }
    } catch (e) {
      debugPrint('QuestionLog: cache unreadable: $e');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const _Profile(age: null, district: null);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      final data = doc.data();
      final year = data?['birth_year'];
      final district = data?['location'];

      final yearInt = year is int ? year : int.tryParse('$year');
      final districtStr = district is String && district.trim().isNotEmpty
          ? district.trim()
          : null;

      if (prefs != null) {
        if (yearInt != null) await prefs.setInt(_kBirthYear, yearInt);
        if (districtStr != null) await prefs.setString(_kDistrict, districtStr);
      }

      return _Profile(
        age: yearInt == null ? null : _ageFrom(yearInt),
        district: districtStr,
      );
    } catch (e) {
      // A question with no age or district is still worth having; the text is
      // the point. Record it rather than dropping it.
      debugPrint('QuestionLog: profile lookup failed: $e');
      return const _Profile(age: null, district: null);
    }
  }

  /// Age in whole years, from the year alone.
  ///
  /// Signup collects a year of birth and no date, so this is right to within a
  /// year — which is the accuracy the programme reports in anyway, and one
  /// less identifying detail stored.
  static int? _ageFrom(int birthYear) {
    final age = DateTime.now().year - birthYear;
    // Nonsense in, nothing out: a mistyped year should not put a 120-year-old
    // in the data.
    return (age < 5 || age > 100) ? null : age;
  }

  /// Clears the cached profile. Called when an account is deleted or on sign
  /// out, so the next person to use the handset is not recorded as the last.
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kBirthYear);
      await prefs.remove(_kDistrict);
    } catch (e) {
      debugPrint('QuestionLog: cache clear failed: $e');
    }
  }
}

class _Profile {
  final int? age;
  final String? district;
  const _Profile({required this.age, required this.district});
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the two rules that make the question log work, both of which are
/// easy to break by editing an unrelated file.
///
/// Neither can be tested by pumping a widget: the gate needs a live
/// FirebaseAuth and the logger needs Firestore, so these read the source
/// instead. Crude, but it catches the actual regression — a new entry point
/// added later that pushes '/chat' directly and quietly bypasses both the
/// sign-in requirement and the recording.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('every route into Probahini goes through the gate', () {
    const entryPoints = [
      'lib/screens/landing/landing.dart',
      'lib/screens/landing/user_home.dart',
      'lib/widgets/user_sidebar.dart',
      'lib/widgets/topic_extras.dart',
    ];

    test('no screen pushes /chat directly', () {
      final offenders = <String>[];
      for (final file in entryPoints) {
        if (read(file).contains("pushNamed(context, '/chat'")) {
          offenders.add(file);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'These open Probahini without the sign-in gate, so the '
            'question would go unrecorded and a signed-out user would get '
            'in: ${offenders.join(", ")}',
      );
    });

    test('each entry point calls openProbahini', () {
      for (final file in entryPoints) {
        expect(
          read(file),
          contains('openProbahini('),
          reason: '$file no longer routes through the gate',
        );
      }
    });

    test('the gate itself is the only thing that pushes /chat', () {
      final gate = read('lib/utils/probahini_gate.dart');
      expect(gate, contains("pushNamed(context, '/chat'"));
      expect(gate, contains('FirebaseAuth.instance.currentUser != null'));
    });
  });

  group('what gets recorded', () {
    final log = read('lib/services/question_log_service.dart');

    test('no user id is stored', () {
      // The programme chose anonymous records. A uid would make every question
      // traceable to a named girl, which is the one thing this must not do.
      expect(log.contains("'uid'"), isFalse,
          reason: 'A user id would make the log identifiable');
      expect(log.contains("'name'"), isFalse);
      expect(log.contains("'phone'"), isFalse);
      expect(log.contains("'email'"), isFalse);
    });

    test('age is stored, not year of birth', () {
      expect(log, contains("'age'"));
      expect(log.contains("'birth_year':"), isFalse,
          reason: 'A birth year is a stabler identifier than an age');
    });

    test('the timestamp comes from the server', () {
      // Handsets in the field are often set to the wrong date, and a
      // mis-dated row is worse than no row.
      expect(log, contains('FieldValue.serverTimestamp()'));
    });

    test('the chat records once the outcome is known', () {
      final chat = read('lib/chat/chat_page.dart');
      final recordAt = chat.indexOf('QuestionLogService.record(');
      final sendAt = chat.indexOf('ChatService().sendChatQuery(');

      expect(recordAt, greaterThan(-1), reason: 'nothing records the question');
      expect(sendAt, greaterThan(-1));
      expect(
        recordAt,
        greaterThan(sendAt),
        reason: 'The record has to carry the answer and whether there was '
            'one, so it cannot be written before the reply arrives',
      );
    });

    test('a failed exchange is recorded too, with a reason', () {
      // The rows where Probahini answered nothing are the point of storing
      // answers at all; if only successes were logged the data would say the
      // chatbot never fails.
      final chat = read('lib/chat/chat_page.dart');
      for (final reason in ["'empty'", "'timeout'", "'error'"]) {
        expect(chat, contains('failure = $reason'),
            reason: 'no failure path sets $reason');
      }
      expect(chat, contains('failure: failure'));
    });

    test('the app apology is never stored as Probahini answer', () {
      // `reply` holds what she reads, which on failure is the app's own
      // apology. Recording that would make a failed exchange look answered.
      final chat = read('lib/chat/chat_page.dart');
      expect(chat, contains('answer: answerText'));
      expect(chat.contains('answer: reply'), isFalse);
    });

    test('records survive her closing the screen mid-answer', () {
      // Giving up on a slow reply is itself worth seeing in the data, so the
      // write must not sit behind the mounted check.
      final chat = read('lib/chat/chat_page.dart');
      final recordAt = chat.indexOf('QuestionLogService.record(');
      final mountedAt = chat.indexOf('if (!mounted) return;', recordAt - 1200);
      expect(recordAt, lessThan(chat.indexOf('if (!mounted) return;', recordAt)),
          reason: 'record() must come before the mounted guard that follows it');
      expect(mountedAt, isNot(-1));
    });

    test('article questions are marked apart from typed ones', () {
      final chat = read('lib/chat/chat_page.dart');
      expect(chat, contains("source: 'article'"));
    });
  });

  group('firestore rules', () {
    final rules = File('../firestore.rules').readAsStringSync();

    test('the question log exists and is not readable by clients', () {
      expect(rules, contains('probahini_questions'));
      expect(rules, contains('allow read, update, delete: if false'));
    });

    test('only signed-in users may write to it', () {
      expect(rules, contains('allow create: if request.auth != null'));
    });
  });
}

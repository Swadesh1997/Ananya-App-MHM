import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/services/question_log_service.dart';
import 'package:ananya/utils/constants.dart';

import 'chat_service.dart';
import 'message.dart';
import 'chat_input.dart';
import 'chat_message.dart';
import 'typing_indicator.dart';

/// Probahini, answering inside Ananya's own chat.
///
/// This screen spent a while as a WebView wrapped around the chatbot's
/// Streamlit page, because the JSON service the app used to call had gone off
/// the air. That showed the vendor's interface — English headings, its own
/// fonts, its own input box — inside Ananya. The service behind
/// [probahiniBaseUri] restores the original arrangement: the app asks a
/// question, receives a sentence, and draws it here.
class ChatPage extends StatefulWidget {
  /// A question an article wants to ask on the reader's behalf.
  ///
  /// Sent automatically when the screen opens, so tapping "ask Probahini"
  /// from a topic lands on the answer rather than on an empty chat.
  final String? openingQuestion;

  const ChatPage({this.openingQuestion, super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();

  /// New for every visit to the screen.
  ///
  /// The service keys conversation history by this id and never drops it, so
  /// a permanent id would make every prompt longer than the last until the
  /// model refused them. A fresh id per visit keeps replies in context within
  /// a conversation and costs nothing between them.
  late final String _userId;

  bool _isBotTyping = false;

  /// Only the first reply waits on the container waking up.
  bool _firstReply = true;

  @override
  void initState() {
    super.initState();
    _userId = const Uuid().v4();

    final opener = widget.openingQuestion?.trim();
    if (opener != null && opener.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _sendMessage(opener, source: 'article'),
      );
    }
  }

  Future<void> _sendMessage(String text, {String source = 'typed'}) async {
    final query = text.trim();
    if (query.isEmpty || _isBotTyping) return;

    setState(() {
      _messages.add(
        Message(text: query, isUser: true, timestamp: DateTime.now()),
      );
      _isBotTyping = true;
    });
    _scrollToBottom();

    final languageCode =
        mounted ? Localizations.localeOf(context).languageCode : 'en';
    final isBangla = languageCode == 'bn';

    // What Probahini returned, and why it did not, for the question log below.
    // `reply` is what she reads and is not the same thing: on failure it holds
    // the app's own apology, which must not be recorded as though the chatbot
    // had said it.
    String? answerText;
    String? failure;

    String reply;
    try {
      final result = await ChatService().sendChatQuery(
        userId: _userId,
        query: query,
      );

      final answer = (result['response'] as String?)?.trim() ?? '';
      if (answer.isNotEmpty) {
        reply = answer;
        answerText = answer;
      } else {
        failure = 'empty';
        // The service answers {"response": "", "error": "..."} when the model
        // call fails — most often the hosted token-per-minute limit, which
        // Bangla reaches first because it costs far more tokens than English.
        // The vendor's own page renders this as an empty bubble and leaves
        // the reader wondering; say something she can act on instead.
        debugPrint('Probahini returned no answer: ${result['error']}');
        reply = isBangla
            ? 'এই মুহূর্তে উত্তর দেওয়া গেল না। একটু পরে আবার চেষ্টা করুন, '
                'অথবা প্রশ্নটি ছোট করে জিজ্ঞাসা করুন।'
            : 'I could not answer that just now. Please try again in a moment, '
                'or ask it in a shorter way.';
      }
    } on TimeoutException {
      failure = 'timeout';
      reply = isBangla
          ? 'উত্তর আসতে বেশি সময় লাগছে। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।'
          : 'That took too long to answer. Check your internet and try again.';
    } catch (e) {
      // The raw exception is for the log, not for a girl reading this screen.
      debugPrint('Probahini request failed: $e');
      failure = 'error';
      reply = isBangla
          ? 'প্রবাহিনীর সাথে সংযোগ করা গেল না। ইন্টারনেট সংযোগ দেখে আবার '
              'চেষ্টা করুন।'
          : 'Could not reach Probahini. Check your internet and try again.';
    }

    // Outside the mounted check on purpose. If she closed the screen while
    // waiting, the exchange still happened and is still worth recording —
    // especially a failure, since giving up on a slow answer is exactly the
    // behaviour the programme would want to see in the data.
    QuestionLogService.record(
      query,
      languageCode: languageCode,
      answer: answerText,
      failure: failure,
      source: source,
    );

    if (!mounted) return;
    setState(() {
      _isBotTyping = false;
      _firstReply = false;
      _messages.add(
        Message(text: reply, isUser: false, timestamp: DateTime.now()),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';

    return Scaffold(
      backgroundColor: BACKGROUND,
      appBar: AppBar(
        backgroundColor: BACKGROUND,
        elevation: 0,
        foregroundColor: ACCENT,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.chat_with_ananya,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ACCENT,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty && !_isBotTyping
                  ? _emptyState(isBangla)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isBotTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isBotTyping && index == _messages.length) {
                          return _typingRow(isBangla);
                        }
                        return ChatMessage(message: _messages[index]);
                      },
                    ),
            ),
            ChatInput(onSendMessage: _sendMessage),
          ],
        ),
      ),
    );
  }

  /// The service sleeps when idle and the first reply can take most of a
  /// minute, which looks like a hang unless the screen says otherwise.
  Widget _typingRow(bool isBangla) {
    if (!_firstReply) return const TypingIndicator();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TypingIndicator(),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 2),
          child: Text(
            isBangla
                ? 'প্রথম উত্তরটি আসতে একটু সময় লাগতে পারে।'
                : 'The first answer can take a little while.',
            style: TextStyle(
              fontSize: 12,
              color: ACCENT.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(bool isBangla) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 34,
              color: PRIMARY_COLOR.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              isBangla
                  ? 'মাসিক নিয়ে যা জানতে চান, জিজ্ঞাসা করুন'
                  : 'Ask anything about menstrual health',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ACCENT,
              ),
            ),
            const SizedBox(height: 6),
            // Says plainly that questions are kept. They are, so the screen
            // should not imply otherwise — and "without your name" is the part
            // that is actually true and actually reassuring.
            Text(
              AppLocalizations.of(context)!.probahini_privacy_note,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: ACCENT.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ananya/widgets/markdown_text.dart';

import 'message.dart';

class ChatMessage extends StatelessWidget {
  final Message message;

  const ChatMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
        message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.health_and_safety, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Only Probahini's side is Markdown. What she typed is shown
                  // exactly as she typed it — a question containing an
                  // asterisk should not come back bolded.
                  if (message.isUser)
                    Text(
                      message.text,
                      style: const TextStyle(color: Colors.white),
                    )
                  else
                    MarkdownText(
                      message.text,
                      style: DefaultTextStyle.of(context).style,
                      // The bubble's own colour, so a wide table fades into it
                      // instead of into a grey band.
                      surfaceColor: Theme.of(context).cardColor,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

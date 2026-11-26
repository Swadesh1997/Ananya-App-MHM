import 'package:flutter/material.dart';

const Color PRIMARY_COLOR = Color(0xFFEA2249);
const Color SECONDARY_COLOR = Color(0xFF006BD9);
const Color ACCENT = Color(0xFF151435);
const Color DISABLE = Color(0xFFAEBEBF);
const Color TEXT = Color(0xFF020D07);
const Color BACKGROUND = Color(0xFFF8F0E4);
const Color BORDER_COLOR = Color(0xFFBEC5D1);
const Color SECONDARY_BACKGROUND = Color(0xFF9CA3AF);
const Color INCORRECT = Colors.red;
const Color RATING_FILL = Color(0xFFFFA432);

// const String baseUri = "http://192.168.0.7:8000/";
// const String baseUri = "http://192.168.0.102:8000/";
// const String baseUri = "http://10.0.2.2:8000/";
const String baseUri = "https://wateraid-ananya-32ao.onrender.com/";
// const String baseUri = "http://192.168.0.100:8000/";

/// Probahini, the chatbot. A separate service on a separate host — not the
/// Ananya backend, and not covered by its authentication.
///
/// The address this used to point at (probahini-groq-model-backend) went off
/// the air, and its source was never in any repository we have, so it could
/// not simply be restarted. This service replaces it: same contract — POST
/// /chat with {user_id, query}, back comes {"response": "..."} — but built
/// from the chatbot vendor's own repository, on the `api` branch, running the
/// same Chain.get_response() as their Streamlit page. Two front doors, one
/// chatbot, so the app's answers cannot drift from the web one.
///
/// The Streamlit page (ananya-chatbot.onrender.com) is still up and is still
/// a browser-only service: it speaks HTML over a WebSocket and answers a plain
/// POST with 405. It is deliberately not used here — an app that embeds it in
/// a WebView gets someone else's interface, in English, instead of this one.
const String probahiniBaseUri = "https://ananya-chatbot-api.onrender.com/";

class Constant {
  static String apiUri = '';
}

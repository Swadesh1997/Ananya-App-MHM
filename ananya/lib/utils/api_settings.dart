import 'package:ananya/utils/constants.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

/// Hard ceiling on every backend call. The hosted backend sleeps when idle
/// and can take 30-60s to wake; without a ceiling the UI waits forever.
const Duration _apiTimeout = Duration(seconds: 15);

/// Probahini answers with a language model behind a service that also sleeps,
/// so a reply legitimately takes far longer than a database read. Long, but
/// still finite — the previous code had no ceiling at all here, so a stalled
/// request left the chat spinner turning until the user killed the app.
///
/// 120s rather than 60s because of what the first message after a cold start
/// actually costs: the free instance takes roughly 50s to wake, then Chroma
/// downloads its 79MB embedding model (the container is destroyed on sleep,
/// so this recurs), and only then does the model answer. 60s timed that out
/// and showed a failure for a request that was going to succeed.
const Duration _chatTimeout = Duration(seconds: 120);

/// One HTTP client for every service the app talks to.
///
/// This used to be two near-identical classes in two files. They drifted: the
/// timeout added to this one never reached the other, so the chat screen kept
/// the one behaviour the timeout existed to prevent. Anything that differs
/// between services is a constructor argument now, so there is no second copy
/// to forget.
class ApiSettings {
  final String endPoint;
  final String baseUrl;
  final Duration timeout;

  /// Whether to attach the signed-in user's Ananya token.
  ///
  /// A bearer token is only meaningful to the service that issued it. Sending
  /// it anywhere else hands that host a working credential for the health API,
  /// so this is opt-in per service rather than something every request does by
  /// default.
  final bool sendsAuthToken;

  String get uri => baseUrl + endPoint;

  /// The Ananya backend.
  ApiSettings({required this.endPoint})
      : baseUrl = baseUri,
        timeout = _apiTimeout,
        sendsAuthToken = true;

  /// Some other service, on some other host.
  ApiSettings.forService({
    required this.endPoint,
    required this.baseUrl,
    required this.timeout,
    this.sendsAuthToken = false,
  });

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    return token;
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final headers = <String, String>{
      if (json) 'Content-Type': 'application/json',
    };
    if (sendsAuthToken) {
      final token = await _getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> postMethod(String data) async {
    try {
      final response = await http
          .post(
            Uri.parse(uri),
            headers: await _headers(json: true),
            body: data,
          )
          .timeout(timeout);
      return response;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<http.Response> postMethodWithoutToken(String data) async {
    try {
      final response = await http
          .post(
            Uri.parse(uri),
            headers: {
              'Content-Type': 'application/json',
            },
            body: data,
          )
          .timeout(timeout);
      return response;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<http.Response> getMethod() async {
    try {
      final response = await http
          .get(Uri.parse(uri), headers: await _headers())
          .timeout(timeout);
      return response;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<http.Response> getMethodWithDiffEndPoint(String ep) async {
    try {
      final response = await http
          .get(Uri.parse(baseUrl + ep), headers: await _headers())
          .timeout(timeout);
      return response;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<http.Response> putMethod(String data) async {
    try {
      final response = await http
          .put(
            Uri.parse(uri),
            headers: await _headers(json: true),
            body: data,
          )
          .timeout(timeout);
      return response;
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}

/// The Probahini chatbot service.
class ProbahiniApiSettings extends ApiSettings {
  ProbahiniApiSettings({required super.endPoint})
      : super.forService(
          baseUrl: probahiniBaseUri,
          timeout: _chatTimeout,
          // Off. This was left on only because the service's source was not
          // in any repository we had, so nobody could say whether the header
          // mattered. It now is: app/api.py on the chatbot repo's `api`
          // branch reads user_id and query and nothing else — no auth, no
          // headers. So the Ananya bearer token was being handed to a third
          // party that has no use for it, which is exactly what not to do
          // with a credential.
          sendsAuthToken: false,
        );
}

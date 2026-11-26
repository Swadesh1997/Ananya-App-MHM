import 'dart:convert';
import 'package:ananya/utils/api_settings.dart';


class ChatService {
  final ProbahiniApiSettings _apiSettings = ProbahiniApiSettings(endPoint: 'chat');

  Future<Map<String, dynamic>> sendChatQuery({
    required String userId,
    required String query,
  }) async {
    final data = jsonEncode({
      'user_id': userId,
      'query': query,
    });

    final response = await _apiSettings.postMethod(data);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Server error ${response.statusCode}');
    }
  }
}

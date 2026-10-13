import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=AIzaSyBS9M4qwGBXLZsGxlqcvdRmBBhBH5T4Y-k';
  final body = jsonEncode({
    'contents': [
      {
        'parts': [
          {'text': 'Hello'}
        ]
      }
    ]
  });

  try {
    print('Sending request...');
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse(url));
    request.headers.set('Content-Type', 'application/json');
    request.write(body);
    final response = await request.close();
    print('Status Code: ${response.statusCode}');
    final responseBody = await response.transform(utf8.decoder).join();
    print('Response Body: $responseBody');
    client.close();
  } catch (e) {
    print('Error: $e');
  }
}

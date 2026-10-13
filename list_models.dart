import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://generativelanguage.googleapis.com/v1beta/models?key=AIzaSyBS9M4qwGBXLZsGxlqcvdRmBBhBH5T4Y-k';

  try {
    print('Fetching models...');
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    print('Status Code: ${response.statusCode}');
    final responseBody = await response.transform(utf8.decoder).join();
    print('Response Body: $responseBody');
    client.close();
  } catch (e) {
    print('Error: $e');
  }
}

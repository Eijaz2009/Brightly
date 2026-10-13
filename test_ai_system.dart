import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  try {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: 'AIzaSyBS9M4qwGBXLZsGxlqcvdRmBBhBH5T4Y-k',
      systemInstruction: Content.system('You are a helpful assistant.'),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 800,
      ),
    );
    
    final chat = model.startChat(
      history: [
        Content.model([TextPart('Siap!')]),
      ],
    );
    print('Success');
  } catch (e) {
    print('Error: $e');
  }
}

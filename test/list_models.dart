import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../lib/core/secrets.dart';

void main() async {
  final apiKey = Secrets.geminiApiKeys.first; // Use the first key
  final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);

  print('Using API Key: ${apiKey.substring(0, 5)}...');

  try {
    // There isn't a direct "listModels" method exposed on the GenerativeModel class in this version easily accessible via a simple call in some versions,
    // but looking at the package source or documentation is better. 
    // Actually, `GenerativeModel` doesn't have a list method. I need to use the REST API manually to list models
    // OR just try to use the model the user asked for.
    // However, the user ASKED me to "do the list models".
    // I will write a raw HTTP request to list models.
    
    // REST API endpoint: https://generativelanguage.googleapis.com/v1beta/models?key=API_KEY
    
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(uri);
    final response = await request.close();
    
    final responseBody = await response.transform(SystemEncoding().decoder).join();
    
    print('Response Status: ${response.statusCode}');
    print(responseBody);
    
  } catch (e) {
    print('Error: $e');
  }
}

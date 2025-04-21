import 'dart:convert';
import 'package:http/http.dart' as http;

class GiftSuggestion {
  final String idea;
  final String explanation;
  final String approximatePrice;

  GiftSuggestion({
    required this.idea,
    required this.explanation,
    required this.approximatePrice,
  });

  // Clean the gift idea by removing any numbers, bullet points, or prices
  String get cleanIdea {
    return idea
        .replaceAll(RegExp(r'^\d+\.\s*'), '') // Remove leading numbers and dots
        .replaceAll(RegExp(r'\([^)]*\)'), '') // Remove anything in parentheses
        .replaceAll(RegExp(r'\$\d+'), '') // Remove dollar amounts
        .replaceAll(RegExp(r'^\s*[-•]\s*'), '') // Remove bullet points
        .trim(); // Remove extra whitespace
  }

  @override
  String toString() {
    return '• $idea - $explanation (Around $approximatePrice)';
  }
}

class OpenAIService {
  final String apiKey;
  static const String _baseUrl = 'https://api.openai.com/v1';

  OpenAIService({required this.apiKey});

  Future<List<GiftSuggestion>> generateGiftSuggestions({
    required String firstName,
    required List<String> likes,
    required List<String> dislikes,
    required String priceRange,
    String? relationship,
    String? gender,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a creative gift suggestion assistant specializing in unique and personalized gift ideas.
              Each time you're asked, provide completely different and innovative suggestions.
              Focus on diverse categories and avoid common or generic gifts.
              Format each suggestion as: GIFT IDEA | EXPLANATION | PRICE'''
            },
            {
              'role': 'user',
              'content': '''
                Generate 5 unique and creative birthday gift ideas for my ${relationship ?? 'friend'} named $firstName.
                ${gender != null ? 'They identify as $gender.' : ''}
                Things they like: ${likes.join(', ')}
                Things they dislike: ${dislikes.join(', ')}
                Price range: $priceRange
                
                Important:
                - Provide diverse suggestions across different categories
                - Avoid generic or common gifts
                - Each suggestion should be unique and creative
                - Consider their specific interests and preferences
                
                Format each suggestion as: GIFT IDEA | EXPLANATION | PRICE
                Example: Personalized Star Map of Their Birth Date | A unique way to commemorate their birthday with a custom constellation map | \$45
              '''
            }
          ],
          'temperature': 0.9,  // Increased for more creativity
          'max_tokens': 500,   // Increased for more detailed responses
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        
        // Parse the formatted response into GiftSuggestion objects
        final suggestions = content
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) {
              final parts = line.replaceAll('• ', '').split('|');
              if (parts.length == 3) {
                return GiftSuggestion(
                  idea: parts[0].trim(),
                  explanation: parts[1].trim(),
                  approximatePrice: parts[2].trim(),
                );
              }
              return null;
            })
            .where((suggestion) => suggestion != null)
            .cast<GiftSuggestion>()
            .toList();

        return suggestions;
      } else {
        throw Exception('Failed to generate gift suggestions: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error generating gift suggestions: $e');
    }
  }

  Future<String> generateBirthdayMessage({
    required String firstName,
    required String relationship,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a thoughtful message writer who creates personalized birthday messages.'
            },
            {
              'role': 'user',
              'content': 'Write a warm and heartfelt birthday message for my $relationship named $firstName.'
            }
          ],
          'temperature': 0.7,
          'max_tokens': 150,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('Failed to generate birthday message: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error generating birthday message: $e');
    }
  }
}
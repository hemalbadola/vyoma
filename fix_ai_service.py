import re

with open('lib/core/ai_service.dart', 'r') as f:
    text = f.read()

# For Gemini
gemini_target = "      final msg = error['error']?['message'] ?? 'Unknown Gemini API error';"
gemini_replacement = "      final msg = error['error'] is String\n          ? error['error']\n          : error['error']?['message'] ?? 'Unknown Gemini API error';"
text = text.replace(gemini_target, gemini_replacement)

# For Nvidia, if similar? Let's check how Nvidia throws. In _callNvidia:
# throw Exception('Nvidia Failed [${response.statusCode}]: ${response.body}');
# So Nvidia works perfectly and doesn't get type error since it just prints body.

# Same for Grok in _callGrok? Wait, _callGrok:
# throws Exception('Grok Failed ... ${response.body}') -> Ah, looking at the logs:
# flutter: Grok Error: Exception: Grok Failed [500] for model grok-3-mini: {"error":"Internal Server Error"}
# So ONLY Gemini attempts to parse `error['error']['message']`!

with open('lib/core/ai_service.dart', 'w') as f:
    f.write(text)

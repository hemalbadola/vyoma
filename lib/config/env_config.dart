class EnvConfig {
  static const String vyomaDesktopClientSecret =
      String.fromEnvironment('VYOMA_DESKTOP_CLIENT_SECRET', defaultValue: '');
  static const String vyomaDesktopClientId =
      String.fromEnvironment('VYOMA_DESKTOP_CLIENT_ID', defaultValue: '');
  static const String vyomaIosClientId =
      String.fromEnvironment('VYOMA_IOS_CLIENT_ID', defaultValue: '');
  static const String vyomaAndroidClientId =
      String.fromEnvironment('VYOMA_ANDROID_CLIENT_ID', defaultValue: '');
  static const String vyomaWebClientId =
      String.fromEnvironment('VYOMA_WEB_CLIENT_ID', defaultValue: '');
  static const String vyomaNvidiaApiKeys =
      String.fromEnvironment('VYOMA_NVIDIA_API_KEYS', defaultValue: '');
  static const String vyomaGrokApiKeys =
      String.fromEnvironment('VYOMA_GROK_API_KEYS', defaultValue: '');
  static const String vyomaGeminiApiKeys =
      String.fromEnvironment('VYOMA_GEMINI_API_KEYS', defaultValue: '');
  static const String vyomaSupermemoryApiKey =
      String.fromEnvironment('VYOMA_SUPERMEMORY_API_KEY', defaultValue: '');

  static String get(String key) {
    switch (key) {
      case 'VYOMA_DESKTOP_CLIENT_SECRET':
        return vyomaDesktopClientSecret.trim();
      case 'VYOMA_DESKTOP_CLIENT_ID':
        return vyomaDesktopClientId.trim();
      case 'VYOMA_IOS_CLIENT_ID':
        return vyomaIosClientId.trim();
      case 'VYOMA_ANDROID_CLIENT_ID':
        return vyomaAndroidClientId.trim();
      case 'VYOMA_WEB_CLIENT_ID':
        return vyomaWebClientId.trim();
      case 'VYOMA_NVIDIA_API_KEYS':
        return vyomaNvidiaApiKeys.trim();
      case 'VYOMA_GROK_API_KEYS':
        return vyomaGrokApiKeys.trim();
      case 'VYOMA_GEMINI_API_KEYS':
        return vyomaGeminiApiKeys.trim();
      case 'VYOMA_SUPERMEMORY_API_KEY':
        return vyomaSupermemoryApiKey.trim();
      default:
        return '';
    }
  }
}

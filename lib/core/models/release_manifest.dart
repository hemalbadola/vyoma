class PlatformRelease {
  final String label;
  final String url;
  final bool available;
  final String? fileName;

  const PlatformRelease({
    required this.label,
    required this.url,
    required this.available,
    this.fileName,
  });

  factory PlatformRelease.fromJson(Map<String, dynamic> json) {
    return PlatformRelease(
      label: json['label'] as String? ?? '',
      url: json['url'] as String? ?? '',
      available: json['available'] as bool? ?? false,
      fileName: json['fileName'] as String?,
    );
  }
}

class ReleaseManifest {
  final String appVersion;
  final String webVersion;
  final String releasedAt;
  final String releaseNotes;
  final bool mandatory;
  final Map<String, PlatformRelease> platforms;

  const ReleaseManifest({
    required this.appVersion,
    required this.webVersion,
    required this.releasedAt,
    required this.releaseNotes,
    required this.mandatory,
    required this.platforms,
  });

  String get version => appVersion;

  factory ReleaseManifest.fromJson(Map<String, dynamic> json) {
    final rawPlatforms = json['platforms'] as Map<String, dynamic>? ?? {};
    final platforms = <String, PlatformRelease>{};
    rawPlatforms.forEach((key, value) {
      platforms[key] = PlatformRelease.fromJson(value as Map<String, dynamic>);
    });

    final legacy = json['version'] as String? ?? '0.0.0';
    final appVer = json['appVersion'] as String? ?? legacy;
    final webVer = json['webVersion'] as String? ?? legacy;

    return ReleaseManifest(
      appVersion: appVer,
      webVersion: webVer,
      releasedAt: json['releasedAt'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
      platforms: platforms,
    );
  }

  PlatformRelease? platform(String id) => platforms[id];
}

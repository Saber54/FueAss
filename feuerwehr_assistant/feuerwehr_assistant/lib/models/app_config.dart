class AppConfig {
  final bool isDarkMode;
  final String serverIp;
  final List<String> hazmatCategories;

  AppConfig({
    required this.isDarkMode,
    required this.serverIp,
    required this.hazmatCategories,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      isDarkMode: json['isDarkMode'] ?? false,
      serverIp: json['serverIp'] ?? '192.168.1.1',
      hazmatCategories: List<String>.from(json['hazmatCategories'] ?? []),
    );
  }
}
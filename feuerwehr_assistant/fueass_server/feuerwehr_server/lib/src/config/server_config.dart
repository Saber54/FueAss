import 'dart:io';

class ServerConfig {
  final String host;
  final int port;
  final String dbConnectionString;
  final List<String> apiKeys;
  final String mapTileCachePath;
  final String vpnConfigPath;

  ServerConfig({
    required this.host,
    required this.port,
    required this.dbConnectionString,
    required this.apiKeys,
    required this.mapTileCachePath,
    required this.vpnConfigPath,
  });

  factory ServerConfig.fromEnv() {
    return ServerConfig(
      host: _getEnv('SERVER_HOST', '0.0.0.0'),
      port: int.parse(_getEnv('SERVER_PORT', '8080')),
      dbConnectionString: _getEnv('DB_CONNECTION_STRING'),
      apiKeys: _getEnv('API_KEYS', '').split(','),
      mapTileCachePath: _getEnv('MAP_CACHE_PATH', '/var/cache/osm'),
      vpnConfigPath: _getEnv('VPN_CONFIG_PATH', '/etc/wireguard/wg0.conf'),
    );
  }

  static String _getEnv(String key, [String? defaultValue]) {
    final value = Platform.environment[key];
    if (value == null && defaultValue == null) {
      throw Exception('Environment variable $key is required');
    }
    return value ?? defaultValue!;
  }
}
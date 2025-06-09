import 'dart:io';
import 'package:logging/logging.dart';

class VPNService {
  final Logger _logger = Logger('VPNService');
  final String _configPath;
  final String _interfaceName;

  VPNService({
    String configPath = '/etc/wireguard/wg0.conf',
    String interfaceName = 'wg0'
  }) : _configPath = configPath, _interfaceName = interfaceName;

  Future<void> ensureRunning() async {
    if (!await _isActive()) {
      await _startVPN();
    }
  }

  Future<bool> _isActive() async {
    try {
      final result = Platform.isLinux 
          ? await Process.run('ip', ['a', 'show', _interfaceName])
          : await Process.run('netsh', ['interface', 'show', 'interface', _interfaceName]);
      
      return result.stdout.toString().contains(_interfaceName);
    } catch (e) {
      _logger.severe('VPN Check failed', e);
      return false;
    }
  }

  Future<void> _startVPN() async {
    _logger.info('Starting VPN interface...');
    try {
      if (Platform.isLinux) {
        await Process.run('wg-quick', ['up', _configPath], runInShell: true);
      } else {
        await Process.run('wireguard', ['/installtunnelservice', _configPath], runInShell: true);
      }
      _logger.info('VPN successfully started');
    } catch (e, stack) {
      _logger.severe('Failed to start VPN', e, stack);
      throw Exception('VPN Start failed: $e');
    }
  }

  Future<void> addClient(String publicKey, String ip) async {
    final config = '''
[Peer]
PublicKey = $publicKey
AllowedIPs = $ip/32
''';
    await File(_configPath).writeAsString(config, mode: FileMode.append);
    await _reloadConfig();
  }

  Future<void> _reloadConfig() async {
    await Process.run('wg', ['syncconf', _interfaceName, _configPath]);
  }
}
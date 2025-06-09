class AppLogger {
  static void log(
    String message, {
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stack,
  }) {
    final prefix = _levelPrefixes[level]!;
    final timestamp = DateTime.now().toIso8601String();
    
    print('[$timestamp] $prefix $message');
    
    if (error != null) {
      print('Error: $error');
    }
    if (stack != null) {
      print('Stack: $stack');
    }
  }

  static const _levelPrefixes = {
    LogLevel.debug: 'DEBUG',
    LogLevel.info: 'INFO',
    LogLevel.warning: 'WARN',
    LogLevel.error: 'ERROR',
  };
}
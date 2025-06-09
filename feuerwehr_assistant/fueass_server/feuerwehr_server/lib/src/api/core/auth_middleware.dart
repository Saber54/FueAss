import 'package:shelf/shelf.dart';

class AuthMiddleware {
  final Set<String> _validApiKeys;

  AuthMiddleware(List<String> apiKeys) : _validApiKeys = apiKeys.toSet();

  Middleware get middleware => (Handler innerHandler) {
    return (Request request) async {
      final apiKey = request.headers['x-api-key'] ?? request.url.queryParameters['api_key'];
      
      if (apiKey == null || !_validApiKeys.contains(apiKey)) {
        return Response.forbidden(
          jsonEncode({'error': 'Invalid or missing API key'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return await innerHandler(request);
    };
  };
}
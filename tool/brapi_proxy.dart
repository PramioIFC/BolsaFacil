import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final token = await _readToken();
  if (token.isEmpty) {
    stderr.writeln('BRAPI_TOKEN não foi preenchido no arquivo .env.');
    exitCode = 1;
    return;
  }

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  stdout.writeln('Proxy da brapi ativo em http://localhost:8080');
  await for (final request in server) {
    await _handle(request, token);
  }
}

Future<String> _readToken() async {
  final file = File('.env');
  if (!await file.exists()) return '';
  for (final line in await file.readAsLines()) {
    final trimmed = line.trim();
    if (trimmed.startsWith('BRAPI_TOKEN=')) {
      return trimmed.substring('BRAPI_TOKEN='.length).trim();
    }
  }
  return '';
}

Future<void> _handle(HttpRequest request, String token) async {
  _cors(request.response);
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  if (!request.uri.path.startsWith('/api/')) {
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
    return;
  }

  final target = Uri.https(
    'brapi.dev',
    request.uri.path,
    request.uri.queryParameters,
  );
  final client = HttpClient();
  try {
    final upstream = await client.getUrl(target);
    upstream.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    upstream.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await upstream.close();
    request.response.statusCode = response.statusCode;
    request.response.headers.contentType = ContentType.json;
    await response.pipe(request.response);
  } catch (error) {
    request.response.statusCode = HttpStatus.badGateway;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': 'Falha ao consultar a brapi.'}));
    await request.response.close();
  } finally {
    client.close();
  }
}

void _cors(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
}

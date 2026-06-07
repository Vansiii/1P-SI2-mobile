import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TileCacheHttpClient extends http.BaseClient {
  final http.Client _inner;
  Directory? _cacheDir;

  TileCacheHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method.toUpperCase() != 'GET') {
      return _inner.send(request);
    }

    final cacheFile = await _resolveCacheFile(request.url);
    final cachedResponse = await _readCachedResponse(request, cacheFile);

    try {
      final response = await _inner.send(request);
      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        await cacheFile.parent.create(recursive: true);
        await cacheFile.writeAsBytes(bytes, flush: true);
        return http.StreamedResponse(
          http.ByteStream.fromBytes(bytes),
          response.statusCode,
          contentLength: bytes.length,
          request: request,
          headers: response.headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
        );
      }

      if (cachedResponse != null) {
        return cachedResponse;
      }

      return response;
    } catch (_) {
      if (cachedResponse != null) {
        return cachedResponse;
      }
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }

  Future<Directory> _ensureCacheDir() async {
    if (_cacheDir != null) {
      return _cacheDir!;
    }

    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'map_tile_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  Future<File> _resolveCacheFile(Uri uri) async {
    final cacheDir = await _ensureCacheDir();
    final host = uri.host.isEmpty ? 'tiles' : uri.host;
    final segments = <String>[
      cacheDir.path,
      host,
      ...uri.pathSegments.where((segment) => segment.isNotEmpty),
    ];
    return File(
      p.joinAll(segments),
    );
  }

  Future<http.StreamedResponse?> _readCachedResponse(
    http.BaseRequest request,
    File cacheFile,
  ) async {
    if (!await cacheFile.exists()) {
      return null;
    }

    final bytes = await cacheFile.readAsBytes();
    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      200,
      contentLength: bytes.length,
      request: request,
      headers: const {'content-type': 'image/png', 'x-cache': 'disk'},
    );
  }
}

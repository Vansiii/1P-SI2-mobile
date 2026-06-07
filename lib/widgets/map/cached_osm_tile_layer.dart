import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/services/tile_cache_http_client.dart';

class CachedOsmTileLayer extends StatefulWidget {
  const CachedOsmTileLayer({
    super.key,
    this.urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.userAgentPackageName = 'com.mecanicoYa.app',
  });

  final String urlTemplate;
  final String userAgentPackageName;

  @override
  State<CachedOsmTileLayer> createState() => _CachedOsmTileLayerState();
}

class _CachedOsmTileLayerState extends State<CachedOsmTileLayer> {
  late final NetworkTileProvider _tileProvider = NetworkTileProvider(
    httpClient: TileCacheHttpClient(),
    silenceExceptions: true,
  );

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: widget.urlTemplate,
      userAgentPackageName: widget.userAgentPackageName,
      tileProvider: _tileProvider,
    );
  }
}

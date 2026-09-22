import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/app_colors.dart';

/// Виджет карты бегового маршрута (для Live-трекинга и итогового отчета)
/// Поддерживает автоматическую темную (Obsidian) и светлую (Porcelain) палитру тайлов.
class RunRouteMapWidget extends StatefulWidget {
  final List<LatLng> points;
  final LatLng? currentPosition;
  final bool isLive;
  final double initialZoom;
  final bool interactive;
  final MapController? mapController;

  const RunRouteMapWidget({
    super.key,
    required this.points,
    this.currentPosition,
    this.isLive = false,
    this.initialZoom = 15.5,
    this.interactive = true,
    this.mapController,
  });

  @override
  State<RunRouteMapWidget> createState() => _RunRouteMapWidgetState();
}

class _RunRouteMapWidgetState extends State<RunRouteMapWidget> with SingleTickerProviderStateMixin {
  late final MapController _controller;
  late final AnimationController _pulseController;

  // Координаты по умолчанию (Алматы / Бишкек), если GPS еще не зафиксировал точку
  static const LatLng _defaultCenter = LatLng(43.238949, 76.889709);

  @override
  void initState() {
    super.initState();
    _controller = widget.mapController ?? MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant RunRouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && widget.currentPosition != null && widget.currentPosition != oldWidget.currentPosition) {
      try {
        _controller.move(widget.currentPosition!, _controller.camera.zoom);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  LatLng get _center {
    if (widget.currentPosition != null) return widget.currentPosition!;
    if (widget.points.isNotEmpty) return widget.points.last;
    return _defaultCenter;
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // CartoDB Dark Matter / Positron
    final tileUrl = isDark
        ? 'https://a.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png'
        : 'https://a.basemaps.cartocdn.com/rastertiles/light_all/{z}/{x}/{y}.png';

    final routePoints = widget.points.isNotEmpty
        ? widget.points
        : (widget.currentPosition != null ? [widget.currentPosition!] : <LatLng>[]);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initialZoom,
              interactionOptions: InteractionOptions(
                flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'sport.kalkan.bio',
                maxZoom: 19,
                subdomains: const ['a', 'b', 'c', 'd'],
                errorTileCallback: (tile, error, stackTrace) {},
              ),
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    // Контурная тень трека
                    Polyline(
                      points: routePoints,
                      strokeWidth: 6.5,
                      color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black12,
                    ),
                    // Основная линия трека (Amber в темной теме, Sage/Sapphire в светлой)
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.5,
                      color: isDark ? AppColors.amber : const Color(0xFF2563EB),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Стартовая точка (если трек начат)
                  if (routePoints.isNotEmpty)
                    Marker(
                      point: routePoints.first,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.sage,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.play_arrow, size: 14, color: Colors.white),
                        ),
                      ),
                    ),

                  // Финишная точка (для итогового отчета)
                  if (!widget.isLive && routePoints.length >= 2)
                    Marker(
                      point: routePoints.last,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.rose,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.sports_score, size: 16, color: Colors.white),
                        ),
                      ),
                    ),

                  // Живая точка бегуна (для live-трекинга)
                  if (widget.isLive && widget.currentPosition != null)
                    Marker(
                      point: widget.currentPosition!,
                      width: 44,
                      height: 44,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulseController.value * 0.35);
                          final opacity = (1.0 - _pulseController.value * 0.5).clamp(0.0, 1.0);
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (isDark ? AppColors.amber : const Color(0xFF2563EB))
                                        .withValues(alpha: 0.25 * opacity),
                                  ),
                                ),
                              ),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? AppColors.amber : const Color(0xFF2563EB),
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.directions_run, size: 12, color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Тонкая окантовка карты в стиле KALKAN
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.hairline, width: 1.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

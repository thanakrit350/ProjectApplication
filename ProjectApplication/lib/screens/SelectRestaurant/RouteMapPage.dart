import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:newproject/model/Restaurant.dart';

class RouteMapPage extends StatefulWidget {
  final Restaurant restaurant;
  const RouteMapPage({super.key, required this.restaurant});

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  final MapController _map = MapController();

  LatLng? _origin;        // ตำแหน่งเรา (เรียลไทม์)
  late LatLng? _dest;     // ปลายทาง: ร้าน
  List<LatLng> _route = [];
  double? _distanceKm;    // ระยะทางถนน
  double? _durationMin;   // เวลาโดยประมาณ
  bool _loadingRoute = false;

  StreamSubscription<Position>? _posSub;
  LatLng? _lastRoutedOrigin;
  DateTime? _lastRoutedAt;

  @override
  void initState() {
    super.initState();
    _dest = _parseDest(widget.restaurant);
    _initLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  LatLng? _parseDest(Restaurant r) {
    final lat = double.tryParse(r.latitude ?? '');
    final lon = double.tryParse(r.longitude ?? '');
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _origin = LatLng(pos.latitude, pos.longitude);
      if (mounted) setState(() {});
      await _ensureRoute();

      // อัปเดตเรียลไทม์ (ขยับ >20m หรือเวลาผ่านไป ~20s ค่อยคำนวณใหม่)
      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen((p) async {
        _origin = LatLng(p.latitude, p.longitude);
        if (mounted) setState(() {});
        await _ensureRoute();
      });
    } catch (_) {
      // เงียบไว้ ใช้ได้แม้ไม่มีเส้นทาง
    }
  }

  Future<void> _ensureRoute() async {
    if (_origin == null || _dest == null) return;

    final now = DateTime.now();
    final movedFar = _lastRoutedOrigin == null
        ? true
        : _distanceMeters(_lastRoutedOrigin!, _origin!) > 40;
    final timedOut = _lastRoutedAt == null || now.difference(_lastRoutedAt!).inSeconds > 20;

    if (!movedFar && !timedOut) return;

    await _fetchOsrmRoute(_origin!, _dest!);
    _lastRoutedOrigin = _origin;
    _lastRoutedAt = DateTime.now();

    _fitToRoute();
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    double dLat = _deg2rad(b.latitude - a.latitude);
    double dLon = _deg2rad(b.longitude - a.longitude);
    double s = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(a.latitude)) * math.cos(_deg2rad(b.latitude)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
    return R * c;
  }

  double _deg2rad(double d) => d * (math.pi / 180.0);

  Future<void> _fetchOsrmRoute(LatLng origin, LatLng dest) async {
    setState(() => _loadingRoute = true);
    try {
      // OSRM route API (public): พิกัดเป็น lon,lat
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson&alternatives=false&steps=false'
      );

      final resp = await http.get(url);
      if (resp.statusCode != 200) return;

      final data = json.decode(resp.body);
      if (data['code'] != 'Ok') return;

      final routes = data['routes'] as List;
      if (routes.isEmpty) return;

      final r = routes.first;
      final geom = r['geometry']; // GeoJSON LineString
      final coords = (geom['coordinates'] as List).cast<List>();
      final pts = <LatLng>[];
      for (final c in coords) {
        // GeoJSON: [lon, lat]
        pts.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
      }

      final meters = (r['distance'] as num).toDouble();
      final seconds = (r['duration'] as num).toDouble();

      setState(() {
        _route = pts;
        _distanceKm = meters / 1000.0;
        _durationMin = seconds / 60.0;
      });
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _fitToRoute() {
    if (_route.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(_route);
      _fitBounds(bounds);
      return;
    }

    // ไม่มีเส้นทาง → ซูมให้เห็น origin + dest
    if (_origin != null && _dest != null) {
      final bounds = LatLngBounds.fromPoints([_origin!, _dest!]); // ✅ ใช้ fromPoints
      _fitBounds(bounds);
    } else if (_dest != null) {
      _map.move(_dest!, 15);
    }
  }

  void _fitBounds(LatLngBounds bounds) {
    try {
      _map.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
      );
    } catch (_) {
      // fallback manual
      final center = LatLng(
        (bounds.north + bounds.south) / 2,
        (bounds.east + bounds.west) / 2,
      );
      _map.move(center, 13);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dest = _dest;

    return Scaffold(
      appBar: AppBar(title: const Text('แผนที่ & เส้นทาง')),
      body: dest == null
          ? const Center(child: Text('ไม่มีพิกัดปลายทางของร้านนี้'))
          : Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    center: dest,
                    zoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.project',
                    ),
                    if (_route.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _route,
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // ปลายทาง
                        Marker(
                          point: dest,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                        // ตำแหน่งเรา
                        if (_origin != null)
                          Marker(
                            point: _origin!,
                            width: 36,
                            height: 36,
                            child: const Icon(Icons.radio_button_checked, size: 28),
                          ),
                      ],
                    ),
                  ],
                ),

                // แผ่นข้อมูลระยะทาง/เวลา
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_car, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _distanceKm != null && _durationMin != null
                                ? '${_distanceKm!.toStringAsFixed(_distanceKm! >= 10 ? 0 : 1)} กม • '
                                  '${_durationMin!.round()} นาที'
                                : (_loadingRoute ? 'กำลังคำนวณเส้นทาง...' : 'พร้อมนำทาง'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ปุ่มลอย: ซูมเส้นทาง / ฉัน / ปลายทาง
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'fitRoute',
                            onPressed: _fitToRoute,
                            child: const Icon(Icons.alt_route),
                          ),
                          const SizedBox(height: 10),
                          FloatingActionButton.small(
                            heroTag: 'myLoc',
                            onPressed: () {
                              if (_origin != null) _map.move(_origin!, 16);
                            },
                            child: const Icon(Icons.my_location),
                          ),
                          const SizedBox(height: 10),
                          FloatingActionButton.small(
                            heroTag: 'dest',
                            onPressed: () => _map.move(dest, 16),
                            child: const Icon(Icons.flag),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

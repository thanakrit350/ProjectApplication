// imports เดิมทั้งหมด
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:newproject/controller/RestaurantController.dart';
import 'package:newproject/model/Restaurant.dart';

class AddBasicRestaurantPage extends StatefulWidget {
  const AddBasicRestaurantPage({super.key});

  @override
  State<AddBasicRestaurantPage> createState() => _AddBasicRestaurantPageState();
}

class _AddBasicRestaurantPageState extends State<AddBasicRestaurantPage> {
  // ===== form / input =====
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  final TextEditingController _placeSearchController = TextEditingController();
  final FocusNode _placeFocus = FocusNode();

  final MapController mapController = MapController();

  // ศูนย์กลาง (fallback: เชียงใหม่)
  LatLng _center = const LatLng(18.7883, 98.9853);

  // ตำแหน่งฉันแบบเรียลไทม์
  LatLng? _myLoc;
  StreamSubscription<Position>? _posSub;

  // ปลายทางเดี่ยวที่เลือก
  LatLng? _dest;

  // DB ทั้งหมด
  List<Restaurant> _dbRestaurants = [];

  // รายการแนะนำ (กรณี non-near)
  final List<_Suggestion> _merged = [];
  Timer? _debounce;
  bool _searching = false;

  // โหมดใกล้ฉัน + ผลลัพธ์หลายร้าน
  bool _nearMode = false;

  // ✅ รายการสถานที่รอบตัว/ที่จะปักหมุด
  List<_PlaceSuggestion> _nearby = [];

  // ✅ โหมด “ปักหมุดอย่างเดียว (ซ่อนลิสต์)”
  bool _pinsOnly = false;

  // ✅ ตัวเลือกช่วงค้นหา
  final List<_RangeOpt> _rangeOptions = const [
    _RangeOpt.radius(2),
    _RangeOpt.radius(5),
    _RangeOpt.radius(10),
    _RangeOpt.province(), // ทั้งจังหวัด
  ];
  _RangeOpt _selectedRange = const _RangeOpt.radius(5);

  // ร้านจากฐานข้อมูลที่เลือก
  Restaurant? _selectedDBRestaurant;
  bool get _usingExisting => _selectedDBRestaurant != null;

  // เส้นทาง/ระยะ/เวลา
  List<LatLng> _route = [];
  double? _distanceKm;
  double? _durationMin;
  bool _loadingRoute = false;
  LatLng? _lastRoutedOrigin;
  LatLng? _lastRoutedDest;
  DateTime? _lastRoutedAt;

  // ล็อกชื่อเมื่อผู้ใช้พิมพ์เอง
  bool _nameLockedByUser = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _initLocation();
    _placeFocus.addListener(() {
      if (!_placeFocus.hasFocus) {
        setState(() => _merged.clear());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _placeFocus.dispose();
    _nameFocus.dispose();
    _placeSearchController.dispose();
    _nameController.dispose();
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      _dbRestaurants = await RestaurantController().getAllRestaurants();
    } catch (_) {
      _dbRestaurants = [];
    }
    if (mounted) setState(() {});
  }

  // -------------------- Location --------------------
  Future<void> _initLocation() async {
    try {
      final svc = await Geolocator.isLocationServiceEnabled();
      if (!svc) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _myLoc = LatLng(pos.latitude, pos.longitude);
      _center = _myLoc!;
      if (mounted) setState(() {});
      mapController.move(_center, 15);

      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
      ).listen((p) async {
        _myLoc = LatLng(p.latitude, p.longitude);
        if (mounted) setState(() {});
        await _ensureRoute();
      });
    } catch (_) {
      // ใช้ center เดิม
    }
  }

  // -------------------- Helpers --------------------
  double _deg2rad(double d) => d * (math.pi / 180.0);
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  LatLng? _safeParseLL(String? latS, String? lonS) {
    final la = double.tryParse(latS ?? '');
    final lo = double.tryParse(lonS ?? '');
    if (la == null || lo == null) return null;
    if (la.abs() <= 90 && lo.abs() <= 180) return LatLng(la, lo);
    if (lo.abs() <= 90 && la.abs() <= 180) return LatLng(lo, la); // สลับ
    return null;
  }

  // -------------------- Search (OSM/Local) --------------------
  Future<List<_PlaceSuggestion>> _searchOSM(String query) async {
    if (query.trim().isEmpty) return [];
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=${Uri.encodeComponent(query)}"
      "&format=json&limit=8&addressdetails=1&countrycodes=th",
    );
    final res =
        await http.get(url, headers: {'User-Agent': 'yourapp/1.0 (contact: your-email@example.com)'});
    if (res.statusCode != 200) return [];
    final List data = jsonDecode(res.body);

    return data.map<_PlaceSuggestion>((e) {
      final display = (e['display_name'] ?? '') as String;
      final addr = e['address'] as Map?;
      String title = (display.split(',').first).trim();
      for (final k in [
        'name','shop','restaurant','amenity','building','road','neighbourhood','hamlet','village','suburb'
      ]) {
        final v = addr?[k];
        if (v is String && v.trim().isNotEmpty) {
          title = v.trim();
          break;
        }
      }
      final lat = double.tryParse('${e['lat']}') ?? 0;
      final lon = double.tryParse('${e['lon']}') ?? 0;
      final subtitle = _composeAddr(addr) ?? display;
      return _PlaceSuggestion(
          source: _Source.osm, title: title, subtitle: subtitle, lat: lat, lon: lon);
    }).toList();
  }

  Future<List<_PlaceSuggestion>> _searchOSMNearby(
      String term, LatLng center, double radiusKm) async {
    final d = radiusKm / 111.0;
    final minLat = center.latitude - d;
    final maxLat = center.latitude + d;
    final minLon = center.longitude - d;
    final maxLon = center.longitude + d;

    final q = term.trim().isEmpty ? 'restaurant' : term;
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=${Uri.encodeComponent(q)}&format=json&limit=20&addressdetails=1&countrycodes=th"
      "&viewbox=$minLon,$minLat,$maxLon,$maxLat&bounded=1",
    );

    final res =
        await http.get(url, headers: {'User-Agent': 'yourapp/1.0 (contact: your-email@example.com)'});
    if (res.statusCode != 200) return [];
    final List data = jsonDecode(res.body);

    return data.map<_PlaceSuggestion>((e) {
      final display = (e['display_name'] ?? '') as String;
      final addr = e['address'] as Map?;
      String title = (display.split(',').first).trim();
      for (final k in [
        'name','shop','restaurant','amenity','building','road','neighbourhood','hamlet','village','suburb'
      ]) {
        final v = addr?[k];
        if (v is String && v.trim().isNotEmpty) {
          title = v.trim();
          break;
        }
      }
      final lat = double.tryParse('${e['lat']}') ?? 0;
      final lon = double.tryParse('${e['lon']}') ?? 0;
      final subtitle = _composeAddr(addr) ?? display;
      return _PlaceSuggestion(
          source: _Source.osm, title: title, subtitle: subtitle, lat: lat, lon: lon);
    }).toList();
  }

  String? _composeAddr(Map? addr) {
    if (addr == null) return null;
    final parts = <String>[];
    void add(String k) {
      final v = addr[k];
      if (v is String && v.trim().isNotEmpty) parts.add(v.trim());
    }

    add('house_number'); add('road'); add('neighbourhood'); add('hamlet'); add('village');
    add('suburb'); add('town'); add('city'); add('county'); add('state'); add('postcode'); add('country');
    return parts.isEmpty ? null : parts.join(' • ');
  }

  List<_PlaceSuggestion> _searchLocal(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    bool like(String? s) => (s ?? '').toLowerCase().contains(q);

    final results = <_PlaceSuggestion>[];
    for (final r in _dbRestaurants) {
      if (like(r.restaurantName) ||
          like(r.subdistrict) ||
          like(r.district) ||
          like(r.province) ||
          like(r.description)) {
        final ll = _safeParseLL(r.latitude, r.longitude);
        results.add(
          _PlaceSuggestion(
            source: _Source.local,
            title: r.restaurantName ?? 'ไม่ระบุชื่อ',
            subtitle: [
              if ((r.subdistrict ?? '').isNotEmpty) r.subdistrict,
              if ((r.district ?? '').isNotEmpty) r.district,
              if ((r.province ?? '').isNotEmpty) r.province,
            ].whereType<String>().join(' • '),
            lat: ll?.latitude ?? 0,
            lon: ll?.longitude ?? 0,
            restaurant: r,
          ),
        );
      }
    }
    return results.take(8).toList();
  }

  List<_PlaceSuggestion> _searchLocalNearby(String query, LatLng center, double radiusKm) {
    final q = query.toLowerCase().trim();
    bool like(String? s) => q.isEmpty ? true : (s ?? '').toLowerCase().contains(q);

    final out = <_PlaceSuggestion>[];
    for (final r in _dbRestaurants) {
      if (!(like(r.restaurantName) || like(r.description) || like(r.restaurantType?.typeName))) {
        continue;
      }
      final ll = _safeParseLL(r.latitude, r.longitude);
      if (ll == null) continue;
      final dist = _haversineKm(center.latitude, center.longitude, ll.latitude, ll.longitude);
      if (dist <= radiusKm) {
        out.add(_PlaceSuggestion(
          source: _Source.local,
          title: r.restaurantName ?? 'ไม่ระบุชื่อ',
          subtitle: [
            if ((r.subdistrict ?? '').isNotEmpty) r.subdistrict,
            if ((r.district ?? '').isNotEmpty) r.district,
            if ((r.province ?? '').isNotEmpty) r.province,
          ].whereType<String>().join(' • '),
          lat: ll.latitude,
          lon: ll.longitude,
          restaurant: r,
        ));
      }
    }
    return out;
  }

  // ===== Province helpers =====
  Future<_BBox?> _fetchProvinceBBoxFrom(LatLng p) async {
    final addr = await _reverseAddress(p);
    final prov = addr['province'];
    if (prov == null || prov.isEmpty) return null;

    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=${Uri.encodeComponent('$prov, Thailand')}"
      "&format=json&limit=1&countrycodes=th",
    );
    final res =
        await http.get(url, headers: {'User-Agent': 'yourapp/1.0 (contact: your-email@example.com)'});
    if (res.statusCode != 200) return null;
    final List list = jsonDecode(res.body);
    if (list.isEmpty) return null;

    final bb = (list.first['boundingbox'] as List).cast<String>();
    final south = double.tryParse(bb[0]) ?? 0;
    final north = double.tryParse(bb[1]) ?? 0;
    final west = double.tryParse(bb[2]) ?? 0;
    final east = double.tryParse(bb[3]) ?? 0;
    return _BBox(south: south, north: north, west: west, east: east);
  }

  Future<List<_PlaceSuggestion>> _searchOSMInBBox(String term, _BBox bbox) async {
    final q = term.trim().isEmpty ? 'restaurant' : term;
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=${Uri.encodeComponent(q)}&format=json&limit=30&addressdetails=1&countrycodes=th"
      "&viewbox=${bbox.toViewbox()}&bounded=1",
    );
    final res =
        await http.get(url, headers: {'User-Agent': 'yourapp/1.0 (contact: your-email@example.com)'});
    if (res.statusCode != 200) return [];
    final List data = jsonDecode(res.body);

    return data.map<_PlaceSuggestion>((e) {
      final display = (e['display_name'] ?? '') as String;
      final addr = e['address'] as Map?;
      String title = (display.split(',').first).trim();
      for (final k in [
        'name','shop','restaurant','amenity','building','road','neighbourhood','hamlet','village','suburb'
      ]) {
        final v = addr?[k];
        if (v is String && v.trim().isNotEmpty) {
          title = v.trim();
          break;
        }
      }
      final lat = double.tryParse('${e['lat']}') ?? 0;
      final lon = double.tryParse('${e['lon']}') ?? 0;
      final subtitle = _composeAddr(addr) ?? display;
      return _PlaceSuggestion(
          source: _Source.osm, title: title, subtitle: subtitle, lat: lat, lon: lon);
    }).toList();
  }

  List<_PlaceSuggestion> _searchLocalInProvince(String query, _BBox? bbox, String? provName) {
    final q = query.toLowerCase().trim();
    bool like(String? s) => q.isEmpty ? true : (s ?? '').toLowerCase().contains(q);

    String norm(String? s) =>
        (s ?? '').replaceAll(RegExp(r'^(จังหวัด)\s*'), '').trim().toLowerCase();

    final pvNorm = norm(provName);

    final out = <_PlaceSuggestion>[];
    for (final r in _dbRestaurants) {
      if (!(like(r.restaurantName) || like(r.description) || like(r.restaurantType?.typeName))) {
        continue;
      }
      final ll = _safeParseLL(r.latitude, r.longitude);
      bool inScope = false;
      if (ll != null && bbox != null) {
        inScope = bbox.contains(ll);
      } else {
        inScope = norm(r.province) == pvNorm && pvNorm.isNotEmpty;
      }
      if (!inScope) continue;

      out.add(_PlaceSuggestion(
        source: _Source.local,
        title: r.restaurantName ?? 'ไม่ระบุชื่อ',
        subtitle: [
          if ((r.subdistrict ?? '').isNotEmpty) r.subdistrict,
          if ((r.district ?? '').isNotEmpty) r.district,
          if ((r.province ?? '').isNotEmpty) r.province,
        ].whereType<String>().join(' • '),
        lat: ll?.latitude ?? 0,
        lon: ll?.longitude ?? 0,
        restaurant: r,
      ));
    }
    return out;
  }

  String _cleanAdminName(String? s) {
    if (s == null) return '';
    var t = s.trim();
    t = t.replaceAll(RegExp(r'^(จังหวัด|อำเภอ|เขต|ตำบล|แขวง)\s*'), '');
    return t;
  }

  Future<Map<String, String>> _reverseAddress(LatLng p) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/reverse"
      "?lat=${p.latitude}&lon=${p.longitude}&format=json&addressdetails=1&zoom=14",
    );
    final res =
        await http.get(url, headers: {'User-Agent': 'yourapp/1.0 (contact: your-email@example.com)'});
    if (res.statusCode != 200) return {};
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final addr = (data['address'] ?? {}) as Map<String, dynamic>;

    final province = _cleanAdminName((addr['province'] ?? addr['state'])?.toString());
    final district =
        _cleanAdminName((addr['district'] ?? addr['county'] ?? addr['city_district'])?.toString());
    final subdistrict = _cleanAdminName(
        (addr['subdistrict'] ?? addr['township'] ?? addr['suburb'] ?? addr['village'])?.toString());

    return {'province': province, 'district': district, 'subdistrict': subdistrict};
  }

  // -------------------- UI search handlers (realtime) --------------------
  void _onQueryChanged(String text) {
    _selectedDBRestaurant = null;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;

      final norm = text.replaceAll(RegExp(r'\s+'), ' ').toLowerCase().trim();
      final isNearKeyword = norm.contains('ใกล้ฉัน') || norm.contains('near me');

      if (text.trim().isEmpty) {
        setState(() {
          _merged.clear();
          _nearby.clear();
          _nearMode = false;
          _pinsOnly = false;
          _dest = null;
          _route.clear();
          _distanceKm = null;
          _durationMin = null;
        });
        return;
      }

      if (isNearKeyword || _myLoc != null) {
        setState(() {
          _searching = true;
          _nearMode = true;
          _pinsOnly = false;
          _nearby.clear();
        });
        await _searchNearby(text);
        if (!mounted) return;
        setState(() => _searching = false);
        return;
      }

      // fallback (ยังไม่มีพิกัดฉันเลย)
      setState(() => _searching = true);
      final local = _searchLocal(text);
      final osm = await _searchOSM(text);
      if (!mounted) return;
      setState(() {
        _nearMode = false;
        _pinsOnly = false;
        _nearby.clear();
        _merged
          ..clear()
          ..addAll(_asSuggestionList('จากฐานข้อมูลของเรา', local, showEmpty: true))
          ..addAll(_asSuggestionList('จากแผนที่ OpenStreetMap', osm, showEmpty: false));
        _searching = false;
      });
    });
  }

  // -------------------- NEW: Pin all shown results (Enter / ไอคอนส่ง) --------------------
  Future<void> _pinAllShownResults() async {
    final rawQ = _placeSearchController.text.trim();
    if (rawQ.isEmpty) return;

    // 1) เอารายการที่ "กำลังแสดงอยู่" ในจอ
    List<_PlaceSuggestion> items = [];
    if (_nearMode) {
      items = List.of(_nearby);
    } else if (_merged.isNotEmpty) {
      items = _merged.where((s) => !s.isHeader).map((s) => s.item!).toList();
    }

    // 2) ถ้ายังว่าง (เช่น ผู้ใช้พิมพ์แล้วกด Enter เร็วมาก) → เก็บผลลัพธ์ใหม่
    if (items.isEmpty) {
      final norm = rawQ.replaceAll(RegExp(r'\s+'), ' ').toLowerCase().trim();
      final isNearKeyword = norm.contains('ใกล้ฉัน') || norm.contains('near me');
      final center = _myLoc ?? _center;

      if (isNearKeyword || _myLoc != null) {
        if (_selectedRange.radiusKm == null) {
          final bbox = await _fetchProvinceBBoxFrom(center);
          if (bbox != null) {
            final addr = await _reverseAddress(center);
            final local = _searchLocalInProvince(rawQ, bbox, addr['province']);
            final osm = await _searchOSMInBBox(rawQ, bbox);
            items = [...local, ...osm];
          }
        } else {
          final local = _searchLocalNearby(rawQ, center, _selectedRange.radiusKm!);
          final osm = await _searchOSMNearby(rawQ, center, _selectedRange.radiusKm!);
          items = [...local, ...osm];
        }
      } else {
        final local = _searchLocal(rawQ);
        final osm = await _searchOSM(rawQ);
        items = [...local, ...osm];
      }
    }

    // 3) Dedup + sort by distance (ถ้ามีพิกัดฉัน)
    final center = _myLoc ?? _center;
    final dedup = <String, _PlaceSuggestion>{};
    for (final s in items) {
      final key = '${s.title}_${s.lat.toStringAsFixed(5)}_${s.lon.toStringAsFixed(5)}';
      dedup.putIfAbsent(key, () => s);
    }
    final list = dedup.values.toList();
    list.sort((a, b) {
      final da = _haversineKm(center.latitude, center.longitude, a.lat, a.lon);
      final db = _haversineKm(center.latitude, center.longitude, b.lat, b.lon);
      return da.compareTo(db);
    });

    // 4) เข้าสู่โหมด “ปักหมุดอย่างเดียว”
    setState(() {
      _pinsOnly = true;
      _nearMode = false;      // ซ่อน UI รายการใกล้ฉัน
      _merged.clear();        // ซ่อนลิสต์ realtime
      _nearby = list;         // ใช้รายการนี้เป็นหมุดทั้งหมด
      _dest = null;
      _route.clear();
      _distanceKm = null;
      _durationMin = null;
    });

    // 5) ซูมให้เห็นทุกหมุด
    if (list.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(
        list.map((e) => LatLng(e.lat, e.lon)).toList()..add(center),
      );
      _fitBounds(bounds);
    }
  }

  Future<void> _searchNearby(String raw) async {
    var term = raw.replaceAll('ใกล้ฉัน', '').replaceAll('near me', '').trim();
    if (term.isEmpty) term = 'restaurant';

    final center = _myLoc ?? _center;

    // ✅ ทั้งจังหวัด
    if (_selectedRange.radiusKm == null) {
      final bbox = await _fetchProvinceBBoxFrom(center);
      if (bbox == null) {
        final backupLocal = _searchLocalNearby(term, center, 10);
        final backupOsm = await _searchOSMNearby(term, center, 10);
        _applyNearbyResults(center, [...backupLocal, ...backupOsm]);
        return;
      }

      final addr = await _reverseAddress(center);
      final local = _searchLocalInProvince(term, bbox, addr['province']);
      final osm = await _searchOSMInBBox(term, bbox);

      final combined = <String, _PlaceSuggestion>{};
      for (final s in [...local, ...osm]) {
        final key = '${s.title}_${s.lat.toStringAsFixed(5)}_${s.lon.toStringAsFixed(5)}';
        combined.putIfAbsent(key, () => s);
      }
      final list = combined.values.toList();
      list.sort((a, b) {
        final da = _haversineKm(center.latitude, center.longitude, a.lat, a.lon);
        final db = _haversineKm(center.latitude, center.longitude, b.lat, b.lon);
        return da.compareTo(db);
      });

      setState(() {
        _nearby = list;
        _merged.clear();
        _dest = null;
        _pinsOnly = false;
        _route.clear();
        _distanceKm = null;
        _durationMin = null;
      });
      mapController.move(center, 9.5);
      return;
    }

    // โหมดรัศมี (2/5/10 กม.)
    final local = _searchLocalNearby(term, center, _selectedRange.radiusKm!);
    final osm = await _searchOSMNearby(term, center, _selectedRange.radiusKm!);
    _applyNearbyResults(center, [...local, ...osm]);
  }

  void _applyNearbyResults(LatLng center, List<_PlaceSuggestion> items) {
    final combined = <String, _PlaceSuggestion>{};
    for (final s in items) {
      final key = '${s.title}_${s.lat.toStringAsFixed(5)}_${s.lon.toStringAsFixed(5)}';
      combined.putIfAbsent(key, () => s);
    }
    final list = combined.values.toList();
    list.sort((a, b) {
      final da = _haversineKm(center.latitude, center.longitude, a.lat, a.lon);
      final db = _haversineKm(center.latitude, center.longitude, b.lat, b.lon);
      return da.compareTo(db);
    });

    setState(() {
      _nearby = list;
      _merged.clear();
      _pinsOnly = false;
      _dest = null;
      _route.clear();
      _distanceKm = null;
      _durationMin = null;
    });
    mapController.move(center, 14.5);
  }

  List<_Suggestion> _asSuggestionList(String header, List<_PlaceSuggestion> items,
      {required bool showEmpty}) {
    if (items.isEmpty && !showEmpty) return [];
    return [_Suggestion.header(header), ...items.map(_Suggestion.item)];
  }

  Future<void> _selectSuggestion(_PlaceSuggestion s) async {
    // จาก DB
    if (s.source == _Source.local && s.restaurant != null) {
      _selectedDBRestaurant = s.restaurant;
      final r = s.restaurant!;
      final ll = _safeParseLL(r.latitude, r.longitude) ?? LatLng(s.lat, s.lon);

      setState(() {
        _dest = ll;
        _placeSearchController.text = r.restaurantName ?? s.title;
        if (!_nameLockedByUser) _nameController.text = r.restaurantName ?? s.title;
        _merged.clear();
        _nearMode = false;
        _pinsOnly = false; // ออกจากโหมด pins-only
        _nearby.clear();
      });
      mapController.move(ll, 17.0);
      await _ensureRoute(force: true);
      return;
    }

    // ไม่ใช่ DB ⇒ ปลายทางใหม่
    _selectedDBRestaurant = null;
    final ll = LatLng(s.lat, s.lon);
    setState(() {
      _dest = ll;
      _placeSearchController.text = s.title;
      if (!_nameLockedByUser) _nameController.text = s.title;
      _merged.clear();
      _nearMode = false;
      _pinsOnly = false; // ออกจากโหมด pins-only
      _nearby.clear();
    });
    mapController.move(ll, 17.0);
    await _ensureRoute(force: true);
  }

  // -------------------- Route (OSRM) --------------------
  Future<void> _ensureRoute({bool force = false}) async {
    if (_myLoc == null || _dest == null) return;

    final now = DateTime.now();
    final movedFar = _lastRoutedOrigin == null ? true : _distanceMeters(_lastRoutedOrigin!, _myLoc!) > 40;
    final timedOut = _lastRoutedAt == null || now.difference(_lastRoutedAt!).inSeconds > 20;
    final destChanged = _lastRoutedDest == null || _lastRoutedDest != _dest;

    if (!(force || destChanged || movedFar || timedOut)) return;

    await _fetchOsrmRoute(_myLoc!, _dest!);
    _lastRoutedOrigin = _myLoc;
    _lastRoutedDest = _dest;
    _lastRoutedAt = DateTime.now();
    _fitToRoute();
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    double dLat = _deg2rad(b.latitude - a.latitude);
    double dLon = _deg2rad(b.longitude - a.longitude);
    double s = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(a.latitude)) *
            math.cos(_deg2rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
    return R * c;
  }

  Future<void> _fetchOsrmRoute(LatLng origin, LatLng dest) async {
    setState(() => _loadingRoute = true);
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson&alternatives=false&steps=false',
      );

      final resp = await http.get(url);
      if (resp.statusCode != 200) return;

      final data = json.decode(resp.body);
      if (data['code'] != 'Ok') return;

      final routes = data['routes'] as List;
      if (routes.isEmpty) return;

      final r = routes.first;
      final geom = r['geometry'];
      final coords = (geom['coordinates'] as List).cast<List>();
      final pts = <LatLng>[];
      for (final c in coords) {
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
    if (_myLoc != null && _dest != null) {
      final bounds = LatLngBounds.fromPoints([_myLoc!, _dest!]);
      _fitBounds(bounds);
    } else if (_dest != null) {
      mapController.move(_dest!, 15);
    }
  }

  void _fitBounds(LatLngBounds bounds) {
    try {
      mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
      );
    } catch (_) {
      final center = LatLng((bounds.north + bounds.south) / 2, (bounds.east + bounds.west) / 2);
      mapController.move(center, 13);
    }
  }

  void _clearRoute() {
    setState(() {
      _dest = null;
      _route.clear();
      _distanceKm = null;
      _durationMin = null;
      _lastRoutedDest = null;
      _pinsOnly = false;
    });
    if (_myLoc != null) {
      mapController.move(_myLoc!, 15);
    } else {
      mapController.move(_center, 15);
    }
  }

  // ---------- VALIDATOR: ชื่อร้าน ----------
  String? _validateRestaurantName(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'กรุณากรอกชื่อร้านอาหาร';
  if (s.length < 3 || s.length > 50) return 'ความยาวต้องอยู่ระหว่าง 3–50 ตัวอักษร';

  // ✅ อนุญาต ไทย/อังกฤษ/ตัวเลข/ช่องว่าง และอักขระพบบ่อยในชื่อร้าน
  final reg = RegExp(r"^[A-Za-z0-9\u0E00-\u0E7F\s&'\-.\#()!_/]+$");
  if (!reg.hasMatch(s)) {
    return "อนุญาตเฉพาะ ไทย/อังกฤษ/ตัวเลข ช่องว่าง และ (& - . # ( ) ! _ / ')";
  }
  return null;
}


  // -------------------- Submit --------------------
  void _submitBasicRestaurant() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      FocusScope.of(context).requestFocus(_nameFocus);
      return;
    }

    if (_usingExisting) {
      final r = _selectedDBRestaurant!;
      final ll = _safeParseLL(r.latitude, r.longitude) ?? _dest;
      if (!mounted) return;
      Navigator.pop(context, {
        'restaurant': r.toJson(),
        'lat': (ll ?? _dest ?? _myLoc ?? _center).latitude,
        'lon': (ll ?? _dest ?? _myLoc ?? _center).longitude,
      });
      return;
    }

    final name = _nameController.text.trim();
    final ll = _dest ?? _myLoc ?? _center;

    final addr = await _reverseAddress(ll);
    final province = addr['province'] ?? '';
    final district = addr['district'] ?? '';
    final subdistrict = addr['subdistrict'] ?? '';

    final newRestaurant = await RestaurantController().addBasicRestaurant(
      restaurantName: name,
      latitude: ll.latitude.toString(),
      longitude: ll.longitude.toString(),
      restaurantTypeName: 'ร้านอาหาร',
      province: province,
      district: district,
      subdistrict: subdistrict,
    );

    if (newRestaurant != null && mounted) {
      Navigator.pop(context, {
        'restaurant': newRestaurant.toJson(),
        'lat': ll.latitude,
        'lon': ll.longitude,
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("เกิดข้อผิดพลาดในการบันทึก")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final h = MediaQuery.of(context).size.height;
    final mapHeight = math.max(220.0, (keyboard > 0 ? h * 0.30 : h * 0.42));

    final markers = <Marker>[
      if (_myLoc != null)
        Marker(point: _myLoc!, width: 32, height: 32, child: const Icon(Icons.my_location, size: 24)),
      if ((_nearMode || _pinsOnly) && _nearby.isNotEmpty)
        ..._nearby.map(
          (s) => Marker(
            point: LatLng(s.lat, s.lon),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _selectSuggestion(s),
              child: const Icon(Icons.location_on, color: Colors.red, size: 36),
            ),
          ),
        ),
      if (!_nearMode && !_pinsOnly && _dest != null)
        Marker(
          point: _dest!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text("เพิ่มสถานที่ร้านอาหาร"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            tooltip: "ล้างเส้นทาง",
            onPressed: _clearRoute,
            icon: const Icon(Icons.clear_all),
          ),
          IconButton(
            tooltip: "ใช้พิกัดปัจจุบัน",
            onPressed: () async {
              await _initLocation();
              if (_myLoc != null) mapController.move(_myLoc!, 15);
            },
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              // ชื่อร้าน
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocus,
                autovalidateMode: AutovalidateMode.disabled,
                validator: _validateRestaurantName,
                onChanged: (v) {
                  _nameLockedByUser = v.trim().isNotEmpty;
                  if (_usingExisting) setState(() => _selectedDBRestaurant = null);
                },
                decoration: _boxInput("ชื่อร้านอาหาร", prefix: Icons.edit),
              ),
              const SizedBox(height: 12),

              // ค้นหา (พิมพ์ → realtime, Enter/ไอคอนส่ง → ปักหมุดทั้งหมด)
              TextField(
                controller: _placeSearchController,
                focusNode: _placeFocus,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _pinAllShownResults(),
                decoration: _boxInput(
                  "ค้นหา",
                  prefix: Icons.search,
                  suffix: _searching
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.grey.shade600),
                          ),
                        )
                      : IconButton(icon: const Icon(Icons.send), onPressed: _pinAllShownResults),
                ),
              ),

              if (_usingExisting) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE9F3FF), borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF2F80ED)),
                      SizedBox(width: 8),
                      Expanded(child: Text('กำลังใช้ร้านที่มีอยู่แล้ว • จะไม่สร้างร้านใหม่')),
                    ],
                  ),
                ),
              ],

              // แสดงลิสต์เฉพาะตอนพิมพ์ (realtime) หรือโหมดใกล้ฉันทั่วไป
              if (!_pinsOnly && !_nearMode && _merged.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: h * 0.34),
                  child: Material(
                    elevation: 1,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: _merged.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = _merged[i];
                        if (s.isHeader) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                            child: Text(s.header!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                          );
                        }
                        final item = s.item!;
                        final isLocal = item.source == _Source.local;
                        return ListTile(
                          leading: Icon(isLocal ? Icons.store_mall_directory : Icons.place,
                              color: isLocal ? Colors.teal : Colors.redAccent),
                          title: Text(item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle:
                              Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _selectSuggestion(item),
                        );
                      },
                    ),
                  ),
                ),
              ],

              if (!_pinsOnly && _nearMode) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("ผลลัพธ์รอบตัว", style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    DropdownButton<_RangeOpt>(
                      value: _selectedRange,
                      underline: const SizedBox(),
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _selectedRange = v);
                        await _searchNearby(_placeSearchController.text);
                      },
                      items: _rangeOptions.map((opt) {
                        return DropdownMenuItem(
                          value: opt,
                          child: Text(opt.label),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                if (_nearby.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('ไม่พบผลลัพธ์ในรัศมีที่กำหนด/ทั้งจังหวัด'),
                  )
                else
                  Material(
                    elevation: 1,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _nearby.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = _nearby[i];
                        final base = _myLoc ?? _center;
                        final dist = _haversineKm(base.latitude, base.longitude, s.lat, s.lon);
                        return ListTile(
                          leading: const Icon(Icons.place, color: Colors.redAccent),
                          title: Text(s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              "${s.subtitle}\n~ ${dist.toStringAsFixed(dist >= 10 ? 0 : 1)} กม.",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          isThreeLine: true,
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    ),
                  ),
              ],

              const SizedBox(height: 14),
              const Text("ตำแหน่ง & เส้นทาง", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: mapHeight,
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      center: _myLoc ?? _center,
                      zoom: 15.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _dest = point;
                          _merged.clear();
                          _nearMode = false;
                          _pinsOnly = false;
                          _nearby.clear();
                          _selectedDBRestaurant = null;
                        });
                        _ensureRoute(force: true);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: 'com.example.project',
                        evictErrorTileStrategy: EvictErrorTileStrategy.none,
                      ),
                      if (_route.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(points: _route, strokeWidth: 5),
                          ],
                        ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              if (_myLoc != null && _dest != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _distanceKm != null && _durationMin != null
                          ? '${_distanceKm!.toStringAsFixed(_distanceKm! >= 10 ? 0 : 1)} กม • ${_durationMin!.round()} นาที'
                          : (_loadingRoute ? 'กำลังคำนวณเส้นทาง...' : 'พร้อมนำทาง'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitBasicRestaurant,
                      style: _softPrimaryBtn(),
                      child: const Text("เพิ่มสถานที่"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {'clear': true}),
                      style: _softPrimaryBtn(),
                      child: const Text("ไม่ระบุสถานที่"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- UI helpers --------------------
  InputDecoration _boxInput(String hint, {IconData? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefix != null ? Icon(prefix) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFF2F80ED), width: 1.2),
      ),
    );
  }

  ButtonStyle _softPrimaryBtn() => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE9F3FF),
        foregroundColor: const Color(0xFF2F80ED),
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      );
}

// ===== helper classes =====
enum _Source { local, osm }

class _RangeOpt {
  final double? radiusKm; // null = ทั้งจังหวัด
  const _RangeOpt.radius(this.radiusKm);
  const _RangeOpt.province() : radiusKm = null;
  String get label => radiusKm == null ? 'ทั้งจังหวัด' : 'รัศมี ${radiusKm!.toStringAsFixed(0)} กม.';
}

class _BBox {
  final double south, north, west, east;
  const _BBox({required this.south, required this.north, required this.west, required this.east});
  String toViewbox() => '$west,$south,$east,$north';
  bool contains(LatLng p) =>
      p.latitude >= south && p.latitude <= north && p.longitude >= west && p.longitude <= east;
}

class _PlaceSuggestion {
  final _Source source;
  final String title;
  final String subtitle;
  final double lat;
  final double lon;
  final Restaurant? restaurant;

  _PlaceSuggestion({
    required this.source,
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lon,
    this.restaurant,
  });
}

class _Suggestion {
  final String? header;
  final _PlaceSuggestion? item;
  bool get isHeader => header != null;

  _Suggestion.header(this.header) : item = null;
  _Suggestion.item(this.item) : header = null;
}

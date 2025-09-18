import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:newproject/boxs/userlog.dart';
import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/controller/SelectRestaurant.dart';
import 'package:newproject/controller/RestaurantController.dart';
import 'package:newproject/controller/RestaurantTypeController.dart';
import 'package:newproject/model/Activity.dart';
import 'package:newproject/model/Member.dart';
import 'package:newproject/model/Restaurant.dart';
import 'package:newproject/screens/Restaurant/ViewRestaurantPage.dart';

class SelectRestaurantPage extends StatefulWidget {
  final Activity activity;
  const SelectRestaurantPage({super.key, required this.activity});

  @override
  State<SelectRestaurantPage> createState() => _SelectRestaurantPageState();
}

class _SelectRestaurantPageState extends State<SelectRestaurantPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  // ---------- data ----------
  List<Restaurant> _all = [];
  List<Restaurant> _results = [];
  List<Map<String, dynamic>> _typeOptions = [];

  int? _selectedTypeId;           // ใช้ภายใน (ไม่มี dropdown แล้ว)
  late final int? _defaultTypeId; // ประเภทจากกิจกรรม

  bool _loading = true;
  bool _saving = false;

  // ---------- geo (fallback: Chiang Mai) ----------
  double _myLat = 18.7883;
  double _myLon = 98.9853;
  bool _usingFallback = true;
  StreamSubscription<Position>? _posSub;

  // ---------- road distance ----------
  final Map<int, double> _roadKmCache = {}; // restaurantId -> km
  bool _usingRoadDistance = false;
  final bool _preferOsrmIfNoKey = true;
  final String _googleKey = const String.fromEnvironment('GMAPS_KEY', defaultValue: '');
  DateTime? _lastRoadFetchAt;
  double? _roadOriginLat, _roadOriginLon;

  // ---------- voting window ----------
  bool get isSelectionOpen {
    final invite = widget.activity.inviteDate;
    if (invite == null) return false;
    final closeAt = invite.subtract(const Duration(hours: 2));
    return DateTime.now().isBefore(closeAt);
  }

  Map<int, int> get voteCountByRestaurantId {
    final map = <int, int>{};
    for (final am in widget.activity.activityMembers) {
      final rid = am.selectRestaurant?.restaurant.restaurantId;
      if (rid != null) map[rid] = (map[rid] ?? 0) + 1;
    }
    return map;
  }

  List<Restaurant> get sortedByVotes {
    final voteMap = voteCountByRestaurantId;
    final list = [..._results];
    list.sort((a, b) {
      final av = voteMap[a.restaurantId ?? -1] ?? 0;
      final bv = voteMap[b.restaurantId ?? -1] ?? 0;
      return bv.compareTo(av);
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _defaultTypeId = widget.activity.restaurantType?.restaurantTypeId
        ?? widget.activity.restaurant?.restaurantType?.restaurantTypeId;
    _selectedTypeId = _defaultTypeId;

    _initPage();
    _initLocation(); // ขอพิกัด + subscribe อัปเดต

    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), _applyFilter);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _posSub?.cancel();
    super.dispose();
  }

  // ---------- init ----------
  Future<void> _initPage() async {
    try {
      setState(() => _loading = true);
      _typeOptions = await RestaurantTypeController().getAllTypesWithId();
      _all = await RestaurantController().getAllRestaurants();
      _applyFilter();
      // หลังจากมีรายการร้านแล้ว ลองดึงระยะทางตามถนน
      await _maybeUpdateDistancesByRoad(force: true);
    } catch (e) {
      if (!mounted) return;
      _all = [];
      _results = [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _initLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _myLat = pos.latitude;
      _myLon = pos.longitude;
      _usingFallback = false;

      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 30,
        ),
      ).listen((p) async {
        _myLat = p.latitude;
        _myLon = p.longitude;
        _usingFallback = false;
        // ไม่มีผลกับการกรอง แต่มีผลกับการแสดงระยะทาง
        setState(() {});
        await _maybeUpdateDistancesByRoad(); // throttle ภายใน
      });
    } catch (_) {
      // คง fallback
    }
  }

  // ---------- filter ----------
  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final usingTypeId = _selectedTypeId ?? _defaultTypeId;

    final filtered = _all.where((r) {
      final matchType = usingTypeId == null
          ? true
          : r.restaurantType?.restaurantTypeId == usingTypeId;
      if (!matchType) return false;

      if (q.isEmpty) return true;

      bool like(String? s) => (s ?? '').toLowerCase().contains(q);
      return like(r.restaurantName) ||
          like(r.subdistrict) || like(r.district) || like(r.province) ||
          like(r.description);
    }).toList();

    setState(() => _results = filtered);
  }

  // ---------- vote ----------
  Future<void> _pickRestaurant(Restaurant r) async {
    if (!isSelectionOpen) { _snack('ปิดการเลือกร้านแล้ว'); return; }
    final memberId = UserLog().member?.memberId;
    final activityId = widget.activity.activityId;
    final restaurantId = r.restaurantId;

    if (memberId == null) { _snack('กรุณาเข้าสู่ระบบ'); return; }
    if (activityId == null) { _snack('กิจกรรมยังไม่พร้อมสำหรับการโหวต'); return; }
    if (restaurantId == null) { _snack('ข้อมูลร้านไม่สมบูรณ์'); return; }

    final ok = await _confirmPickDialog(r.restaurantName ?? 'ร้านอาหาร');
    if (ok != true) return;

    try {
      setState(() => _saving = true);
      final updated = await ActivitySelectionController().selectRestaurantForActivity(
        activityId: activityId,
        memberId: memberId,
        restaurantId: restaurantId,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      _snack('เลือกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<bool?> _confirmPickDialog(String name) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ยืนยันการเลือกร้าน', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('ต้องการเลือกร้าน “$name” ใช่ไหม?'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก'))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยืนยัน'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- header helpers ----------
  String get _headerDateText {
    final invite = widget.activity.inviteDate;
    if (invite == null) return '-';
    return DateFormat("วันEEEE d MMMM y • HH:mm", 'th').format(invite);
  }

  String get _deadlineText {
    final invite = widget.activity.inviteDate;
    if (invite == null) return '-';
    final closeAt = invite.subtract(const Duration(hours: 2));
    return DateFormat("เลือกได้ถึง d MMM y • HH:mm", 'th').format(closeAt);
  }

  double _progressValue() {
    final invite = widget.activity.inviteDate;
    if (invite == null) return 0;
    final end = invite.subtract(const Duration(hours: 2));
    final start = end.subtract(const Duration(hours: 12));
    final now = DateTime.now();
    if (now.isBefore(start)) return 0;
    if (now.isAfter(end)) return 1;
    final total = end.difference(start).inSeconds;
    final passed = now.difference(start).inSeconds;
    return (passed / total).clamp(0, 1).toDouble();
  }

  // ---------- image & voters ----------
  String? _coverImageUrl(Restaurant r) {
    final raw = r.restaurantImg?.trim();
    if (raw == null || raw.isEmpty) return null;
    String path;
    if (raw.startsWith('[')) {
      try {
        final list = (json.decode(raw) as List).map((e) => e.toString()).toList();
        path = list.isNotEmpty ? list.first : '';
      } catch (_) {
        path = raw;
      }
    } else {
      path = raw.split(RegExp(r'\s*[,|]\s*')).first;
    }
    if (path.isEmpty) return null;
    return baseURL + path;
  }

  List<Member> _votersFor(Restaurant r) {
    final id = r.restaurantId;
    if (id == null) return const [];
    return widget.activity.activityMembers
        .where((am) => am.selectRestaurant?.restaurant.restaurantId == id)
        .map((am) => am.member)
        .toList();
  }

  // ---------- distance helpers ----------
  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  double? _parseDouble(String? s) {
    if (s == null) return null;
    return double.tryParse(s.trim());
  }

  List<double>? _safeParseLatLon(String? latS, String? lonS) {
    final lat0 = _parseDouble(latS);
    final lon0 = _parseDouble(lonS);
    if (lat0 == null || lon0 == null) return null;
    if (lat0.abs() > 90 && lon0.abs() <= 180) return [lon0, lat0]; // สลับ
    if (lon0.abs() > 180 && lat0.abs() <= 90) return [lat0, lon0]; // ปกติ
    return [lat0, lon0];
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    return _haversineKm(lat1, lon1, lat2, lon2) * 1000.0;
  }

  String? _distanceText(Restaurant r) {
    // ถ้ามีระยะทางตามถนนแล้ว ให้ใช้ก่อน
    if (_usingRoadDistance && r.restaurantId != null && _roadKmCache.containsKey(r.restaurantId)) {
      final km = _roadKmCache[r.restaurantId]!;
      final text = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
      return '$text กม';
    }
    // ไม่งั้น fallback เส้นตรง (ถ้าได้พิกัดของเรา)
    if (_usingFallback) return null;
    final ll = _safeParseLatLon(r.latitude, r.longitude);
    if (ll == null) return null;
    final km = _haversineKm(_myLat, _myLon, ll[0], ll[1]);
    final text = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
    return '$text กม';
  }

  Future<void> _maybeUpdateDistancesByRoad({bool force = false}) async {
    if (_all.isEmpty || _usingFallback) return;

    final now = DateTime.now();
    final last = _lastRoadFetchAt;
    final movedFar = (_roadOriginLat != null && _roadOriginLon != null)
        ? _distanceMeters(_roadOriginLat!, _roadOriginLon!, _myLat, _myLon) > 300
        : true;
    final timedOut = last == null || now.difference(last).inSeconds > 120;

    if (!force && !movedFar && !timedOut) return;

    try {
      if (_googleKey.isNotEmpty) {
        await _updateDistancesByRoadGoogle();
      } else if (_preferOsrmIfNoKey) {
        await _updateDistancesByRoadOsrm();
      } else {
        return;
      }
      _usingRoadDistance = true;
      _roadOriginLat = _myLat;
      _roadOriginLon = _myLon;
      _lastRoadFetchAt = DateTime.now();
      if (mounted) setState(() {});
    } catch (_) {
      // fallback เส้นตรงอย่างเดิม
    }
  }

  // Google Distance Matrix (1 x N)
  Future<void> _updateDistancesByRoadGoogle() async {
    const int chunkSize = 25; // จำกัดปลายทางต่อ request
    final dests = _all.where((r) => r.restaurantId != null).toList();

    for (int i = 0; i < dests.length; i += chunkSize) {
      final batch = dests.sublist(i, math.min(i + chunkSize, dests.length));

      final destParam = batch.map((r) {
        final ll = _safeParseLatLon(r.latitude, r.longitude);
        if (ll == null) return null;
        return '${ll[0]},${ll[1]}'; // lat,lon
      }).whereType<String>().join('|');

      if (destParam.isEmpty) continue;

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=$_myLat,$_myLon'
        '&destinations=$destParam'
        '&mode=driving&language=th'
        '&key=$_googleKey',
      );

      final resp = await http.get(url);
      if (resp.statusCode != 200) continue;

      final data = json.decode(resp.body);
      if (data['status'] != 'OK') continue;

      final elements = (data['rows'] as List).first['elements'] as List;
      int idx = 0;
      for (final r in batch) {
        final el = elements[idx++];
        if (el['status'] == 'OK') {
          final meters = (el['distance']['value'] as num).toDouble();
          _roadKmCache[r.restaurantId!] = meters / 1000.0;
        }
      }
    }
  }

  // OSRM Table API (public; ใช้ lon,lat)
  Future<void> _updateDistancesByRoadOsrm() async {
    const int chunkSize = 90;
    final originLonLat = '$_myLon,$_myLat';

    final dests = _all
        .where((r) => r.restaurantId != null)
        .map((r) {
          final ll = _safeParseLatLon(r.latitude, r.longitude);
          if (ll == null) return null;
          return {
            'id': r.restaurantId!,
            'lon': ll[1],
            'lat': ll[0],
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    for (int i = 0; i < dests.length; i += chunkSize) {
      final batch = dests.sublist(i, math.min(i + chunkSize, dests.length));

      final coords = StringBuffer(originLonLat);
      for (final d in batch) {
        coords.write(';${d['lon']},${d['lat']}');
      }

      final url = Uri.parse(
        'https://router.project-osrm.org/table/v1/driving/${coords.toString()}'
        '?sources=0&annotations=distance',
      );

      final resp = await http.get(url);
      if (resp.statusCode != 200) continue;

      final data = json.decode(resp.body);
      if (data['code'] != 'Ok') continue;

      final distances = (data['distances'] as List).first as List; // แถวของ source index 0
      for (int j = 0; j < batch.length; j++) {
        final meters = distances[j + 1];
        if (meters == null) continue;
        final m = (meters as num).toDouble();
        if (m >= 0) {
          _roadKmCache[batch[j]['id'] as int] = m / 1000.0;
        }
      }
    }
  }

  // ---------- avatar stack ----------
  Widget _avatarStack(List<Member> members) {
    const double size = 20;
    const double overlap = 14;
    final show = members.take(3).toList();
    final double width = show.isEmpty ? size : size + overlap * (show.length - 1);

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < show.length; i++)
            Positioned(
              left: i * overlap,
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: (size / 2) - 1.6,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: (show[i].profileImage != null && show[i].profileImage!.isNotEmpty)
                      ? NetworkImage(baseURL + show[i].profileImage!)
                      : null,
                  child: (show[i].profileImage == null || show[i].profileImage!.isEmpty)
                      ? const Icon(Icons.person, size: 12, color: Colors.white)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = sortedByVotes;
    final voteMap = voteCountByRestaurantId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกร้านอาหาร'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                isSelectionOpen ? 'เปิดโหวต' : 'ปิดโหวต',
                style: TextStyle(
                  color: isSelectionOpen ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.activity.activityName ?? '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(_headerDateText, style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.timer, size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(_deadlineText, style: const TextStyle(color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: _progressValue(),
                          minHeight: 6,
                          backgroundColor: Colors.blue.shade50,
                        ),
                      ],
                    ),
                  ),
                ),
                // ช่องค้นหา
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'ค้นหาชื่อร้าน / ที่อยู่',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                if (list.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('ไม่พบร้านตามเงื่อนไขค้นหา')),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final r = list[i];
                        final votes = voteMap[r.restaurantId ?? -1] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _restaurantCard(r, votes),
                        );
                      },
                      childCount: list.length,
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: _saving ? 0 : 16)),
              ],
            ),
      bottomNavigationBar: _saving
          ? const LinearProgressIndicator(minHeight: 2)
          : null,
    );
  }

  Widget _restaurantCard(Restaurant r, int votes) {
    final img = _coverImageUrl(r);
    final voters = _votersFor(r);
    final distanceText = _distanceText(r);

    return InkWell(
      onTap: () async {
        final updatedActivity = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewRestaurantPage(
              restaurant: r,
              isLoggedIn: UserLog().isLoggedIn,
              fromActivity: true,
              activity: widget.activity,
            ),
          ),
        );
        if (updatedActivity is Activity && mounted) {
          Navigator.pop(context, updatedActivity);
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: img != null
                  ? Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.restaurant, size: 40),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.restaurant, size: 40),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _restaurantInfo(r, votes, voters, distanceText)),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isSelectionOpen ? () => _pickRestaurant(r) : null,
                    child: const Text('เลือก'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restaurantInfo(Restaurant r, int votes, List<Member> voters, String? distanceText) {
    final typeName = r.restaurantType?.typeName ?? 'ไม่ระบุประเภท';
    final addr = [
      r.subdistrict ?? '',
      r.district ?? '',
      r.province ?? '',
    ].where((e) => e.isNotEmpty).join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r.restaurantName ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),

        // ประเภทอาหาร • ระยะทาง (ถ้ามี)
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.restaurant_menu, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(typeName, style: const TextStyle(color: Colors.black54)),
              ],
            ),
            if (distanceText != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.near_me, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(distanceText, style: const TextStyle(color: Colors.black54)),
                ],
              ),
          ],
        ),

        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.place, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                addr.isEmpty ? 'ไม่ระบุที่อยู่' : addr,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // รูปคนโหวต + จำนวนโหวต
        Row(
          children: [
            _avatarStack(voters),
            const SizedBox(width: 8),
            Text('$votes โหวต', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

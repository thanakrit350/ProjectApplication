import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:newproject/boxs/userlog.dart';
import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/controller/RestaurantController.dart';
import 'package:newproject/controller/RestaurantTypeController.dart';
import 'package:newproject/model/Restaurant.dart';
import 'package:newproject/model/RestaurantType.dart';

import 'package:newproject/screens/Activity/AddPostActivityPage.dart';
import 'package:newproject/screens/Member/ViewProfilePage.dart';
import 'package:newproject/screens/Restaurant/ViewRestaurantPage.dart';
import 'package:newproject/screens/SelectRestaurant/SearchRestaurantPage.dart';

enum _Mode { all, near }

double _deg2rad(double deg) => deg * (math.pi / 180.0);

List<double>? _safeParseLatLon(String? latS, String? lonS) {
  final lat0 = double.tryParse(latS ?? '');
  final lon0 = double.tryParse(lonS ?? '');
  if (lat0 == null || lon0 == null) return null;
  if (lat0.abs() > 90 && lon0.abs() <= 180) return [lon0, lat0]; // swap
  if (lon0.abs() > 180 && lat0.abs() <= 90) return [lon0, lat0]; // swap
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

class ListRestaurant extends StatefulWidget {
  const ListRestaurant({super.key});
  @override
  State<ListRestaurant> createState() => _ListRestaurantState();
}

class _ListRestaurantState extends State<ListRestaurant> {
  // ---------- mode / filter ----------
  _Mode _mode = _Mode.all;
  final List<RestaurantType> _types = [];
  String _selectedTypeName = 'ทุกประเภทอาหาร';
  int? _selectedTypeId;

  // ---------- paging ----------
  final _scroll = ScrollController();
  final List<Restaurant> _items = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  final int _size = 30;

  // ---------- geo ----------
  double _myLat = 18.7883;
  double _myLon = 98.9853;
  bool _usingFallback = true;
  StreamSubscription<Position>? _posSub;

  // รัศมี (เฉพาะโหมด near)
  double _radiusKm = 5;
  final List<double> _radiusOptions = const [2, 5, 10];

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        _loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      // ✅ ใช้ประเภทที่ "มีร้านจริง" จาก backend
      List<Map<String, dynamic>> typesMap;
      try {
        typesMap = await RestaurantTypeController().getNonEmptyTypesWithId();
      } catch (_) {
        // fallback ถ้ายังไม่ได้อัปเดต controller ฝั่ง Flutter
        typesMap = await RestaurantTypeController().getAllTypesWithId();
      }

      _types
        ..clear()
        ..addAll(typesMap.map((e) => RestaurantType(
              restaurantTypeId: e['id'],
              typeName: e['name'],
            )));

      await _initLocation();
      await _reloadFromFirstPage();
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _myLat = pos.latitude;
      _myLon = pos.longitude;
      _usingFallback = false;

      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 60),
      ).listen((p) {
        _myLat = p.latitude;
        _myLon = p.longitude;
        _usingFallback = false;
        if (_mode == _Mode.near) _reloadFromFirstPage();
      });
    } catch (_) {
      // keep fallback
    }
  }

  Future<void> _reloadFromFirstPage() async {
    _page = 0;
    _hasMore = true;
    _items.clear();
    setState(() {});
    await _loadNextPage();
  }

  bool _typeMatch(Restaurant r) {
    if (_selectedTypeId == null) return true;
    final rid = r.restaurantType?.restaurantTypeId;
    return rid != null && rid == _selectedTypeId;
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    setState(() {});

    try {
      if (_mode == _Mode.all) {
        final paged = await RestaurantController().fetchPaged(
          q: '',
          typeId: _selectedTypeId,
          page: _page,
          size: _size,
        );
        _items.addAll(paged.items);
        _hasMore = !paged.last;
        _page += 1;
      } else {
        int pagesFetched = 0;
        bool lastHasMore = true;
        final List<Restaurant> bucket = [];

        final (list, hasMore) = await RestaurantController().fetchNear(
          lat: _myLat,
          lon: _myLon,
          radiusKm: _radiusKm,
          page: _page,
          size: _size,
        );
        pagesFetched += 1;
        lastHasMore = hasMore;
        final filtered = _selectedTypeId == null ? list : list.where(_typeMatch).toList();
        bucket.addAll(filtered);

        if (bucket.isEmpty && lastHasMore) {
          final (list2, hasMore2) = await RestaurantController().fetchNear(
            lat: _myLat,
            lon: _myLon,
            radiusKm: _radiusKm,
            page: _page + 1,
            size: _size,
          );
          pagesFetched += 1;
          lastHasMore = hasMore2;
          final filtered2 = _selectedTypeId == null ? list2 : list2.where(_typeMatch).toList();
          bucket.addAll(filtered2);
        }

        _items.addAll(bucket);
        _page += pagesFetched;
        _hasMore = _items.isEmpty ? false : lastHasMore;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')),
        );
      }
    } finally {
      _loadingMore = false;
      if (mounted) setState(() {});
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isLoggedIn = UserLog().isLoggedIn;
    final member = UserLog().member;
    final username = member?.firstName ?? '';
    final hasImage = isLoggedIn && (member?.profileImage?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text('ร้านอาหาร - ${isLoggedIn ? username : 'ผู้ใช้'}'),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'ค้นหา',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchRestaurantPage()),
              );
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _reloadFromFirstPage,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'โปรไฟล์',
            onPressed: () {
              if (isLoggedIn) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ViewProfilePage()),
                ).then((_) => setState(() {}));
              } else {
                Navigator.pushNamed(context, '/login');
              }
            },
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white24,
              backgroundImage: hasImage ? NetworkImage(baseURL + member!.profileImage!) : null,
              child: !hasImage ? const Icon(Icons.person, color: Colors.white) : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersBar(),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reloadFromFirstPage,
              child: _initialLoading
                  ? _skeletonList()
                  : (_items.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          controller: _scroll,
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i >= _items.length) return _loadingTile();
                            final r = _items[i];
                            final dist = _calcDistanceText(r);
                            return _RestaurantCard(
                              restaurant: r,
                              isLoggedIn: isLoggedIn,
                              distanceText: dist,
                            );
                          },
                        )),
            ),
          ),
        ],
      ),
    );
  }

  // ====== ฟิลเตอร์บาร์ ======
  Widget _buildFiltersBar() {
    final surface = Theme.of(context).colorScheme.surface;
    final border = Colors.grey.shade300;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // แถวบน: โหมด + ประเภทอาหาร
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildModeChips(),

                  // Dropdown ประเภทอาหาร
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 190,
                      maxWidth: math.max(190, constraints.maxWidth - 140),
                    ),
                    child: DropdownButtonFormField<String>(
                      isDense: true,
                      isExpanded: true,
                      value: _selectedTypeName,
                      icon: const Icon(Icons.expand_more),
                      decoration: InputDecoration(
                        labelText: 'ประเภทอาหาร',
                        prefixIcon: const Icon(Icons.restaurant_menu_outlined),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: border),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: <String>[
                        'ทุกประเภทอาหาร',
                        ..._types.map((t) => t.typeName ?? '').where((e) => e.isNotEmpty),
                      ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        _selectedTypeName = v;
                        _selectedTypeId = null;
                        if (v != 'ทุกประเภทอาหาร') {
                          final ty = _types.firstWhere(
                            (t) => (t.typeName ?? '') == v,
                            orElse: () => RestaurantType(),
                          );
                          _selectedTypeId = ty.restaurantTypeId;
                        }
                        await _reloadFromFirstPage();
                      },
                    ),
                  ),
                ],
              ),

              // แถวล่าง: รัศมี + สถานะพิกัด (เฉพาะโหมดใกล้ฉัน)
              if (_mode == _Mode.near) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('รัศมี', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    ..._radiusOptions.map((v) {
                      final selected = _radiusKm == v;
                      return ChoiceChip(
                        label: Text('${v.toStringAsFixed(0)} กม.'),
                        selected: selected,
                        onSelected: (_) async {
                          setState(() => _radiusKm = v);
                          await _reloadFromFirstPage();
                        },
                        selectedColor: Colors.cyan,
                        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                        backgroundColor: Colors.white,
                        shape: StadiumBorder(side: BorderSide(color: border)),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        _usingFallback ? 'ใช้พิกัดเริ่มต้น: เชียงใหม่' : 'ใช้พิกัดจริงของคุณ',
                        style: TextStyle(
                          color: _usingFallback ? Colors.orange : Colors.green,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ====== สวิตช์โหมด ======
  Widget _buildModeChips() {
    final border = Colors.grey.shade300;

    Widget chip({
      required bool selected,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : Colors.black87),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selectedColor: Colors.cyan,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
        shape: StadiumBorder(side: BorderSide(color: border)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        chip(
          selected: _mode == _Mode.all,
          icon: Icons.apps_rounded,
          label: 'ทั้งหมด',
          onTap: () async {
            if (_mode != _Mode.all) {
              setState(() => _mode = _Mode.all);
              await _reloadFromFirstPage();
            }
          },
        ),
        chip(
          selected: _mode == _Mode.near,
          icon: Icons.near_me_rounded,
          label: 'ใกล้ฉัน',
          onTap: () async {
            if (_mode != _Mode.near) {
              setState(() => _mode = _Mode.near);
              await _reloadFromFirstPage();
            }
          },
        ),
      ],
    );
  }

  // ====== states & misc ======
  Widget _emptyState() {
    final whereText = _mode == _Mode.near
        ? 'ในรัศมี ${_radiusKm.toStringAsFixed(0)} กม.'
        : 'ตามตัวกรองที่เลือก';
    final typeText = (_selectedTypeId == null) ? '' : ' สำหรับประเภท "${_selectedTypeName}"';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.search_off, size: 64, color: Colors.grey.shade500),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'ไม่พบร้าน $whereText$typeText',
            style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'ลองเปลี่ยนประเภทอาหารหรือเพิ่มรัศมีอีกนิดนะ',
            style: TextStyle(fontSize: 13, color: Colors.black45),
          ),
        ),
        const SizedBox(height: 160),
      ],
    );
  }

  Widget _loadingTile() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );

  Widget _skeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        height: 150,
      ),
    );
  }

  String _calcDistanceText(Restaurant r) {
    final ll = _safeParseLatLon(r.latitude, r.longitude);
    if (ll == null) return '';
    final km = _haversineKm(_myLat, _myLon, ll[0], ll[1]);
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} กม';
  }
}

class _RestaurantCard extends StatefulWidget {
  final Restaurant restaurant;
  final bool isLoggedIn;
  final String distanceText;

  const _RestaurantCard({
    required this.restaurant,
    required this.isLoggedIn,
    required this.distanceText,
  });

  @override
  State<_RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<_RestaurantCard> {
  int _page = 0;

  List<String> _images() {
    final raw = widget.restaurant.restaurantImg;
    if (raw == null || raw.trim().isEmpty) return [];
    List<String> parts;
    final t = raw.trim();
    if (t.startsWith('[')) {
      try {
        final arr = json.decode(t) as List;
        parts = arr.map((e) => e.toString()).toList();
      } catch (_) {
        parts = [t];
      }
    } else {
      parts = t.split(RegExp(r'\s*[,|]\s*'));
    }
    return parts.where((p) => p.isNotEmpty).map((p) => baseURL + p).toList();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images();
    final addr = '${widget.restaurant.province ?? ''} ${widget.restaurant.district ?? ''}'.trim();
    final typeName = widget.restaurant.restaurantType?.typeName ?? 'ไม่ระบุประเภท';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewRestaurantPage(
              restaurant: widget.restaurant,
              isLoggedIn: UserLog().isLoggedIn,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: images.isEmpty
                          ? Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
                            )
                          : PageView.builder(
                              itemCount: images.length,
                              onPageChanged: (i) => setState(() => _page = i),
                              itemBuilder: (_, i) => Image.network(
                                images[i],
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (widget.distanceText.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(widget.distanceText, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          images.length,
                          (i) => Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _page ? Colors.white : Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.restaurant.restaurantName ?? 'ไม่พบชื่อร้าน',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(child: Text(typeName, style: const TextStyle(color: Colors.grey))),
                  if (widget.distanceText.isNotEmpty)
                    Text(widget.distanceText, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 2),
              if (addr.isNotEmpty) Text(addr, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.isLoggedIn
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddPostActivityPage(restaurant: widget.restaurant),
                            ),
                          );
                        }
                      : () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("สร้างปาร์ตี้", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

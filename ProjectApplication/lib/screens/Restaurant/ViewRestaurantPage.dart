import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:newproject/boxs/userlog.dart';
import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/controller/SelectRestaurant.dart';
import 'package:newproject/model/Activity.dart';
import 'package:newproject/model/Member.dart';
import 'package:newproject/model/Restaurant.dart';
import 'package:newproject/screens/Activity/AddPostActivityPage.dart';
import 'package:newproject/screens/SelectRestaurant/RouteMapPage.dart';

class ViewRestaurantPage extends StatefulWidget {
  final Restaurant restaurant;
  final bool isLoggedIn;

  // โหมดเข้าจากกิจกรรมเพื่อโหวต
  final bool fromActivity;
  final Activity? activity;

  const ViewRestaurantPage({
    super.key,
    required this.restaurant,
    required this.isLoggedIn,
    this.fromActivity = false,
    this.activity,
  });

  @override
  State<ViewRestaurantPage> createState() => _ViewRestaurantPageState();
}

class _ViewRestaurantPageState extends State<ViewRestaurantPage> {
  // ====== สี & สไตล์ ======
  static const _bg = Color(0xFFF7F7FA);
  static const _titleColor = Colors.black87;
  static const _subtle = Color(0xFF7A7F87);
  static const _pill = Color(0xFF20C6B2); // สีปุ่มมิ้นท์

  // pageview
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------
  List<String> _imageUrls(Restaurant r) {
    final raw = r.restaurantImg?.trim();
    if (raw == null || raw.isEmpty) return [];

    List<String> parts;
    if (raw.startsWith('[')) {
      try {
        final arr = (json.decode(raw) as List).map((e) => e.toString()).toList();
        parts = arr;
      } catch (_) {
        parts = [raw];
      }
    } else {
      parts = raw.split(RegExp(r'\s*[,|]\s*'));
    }
    return parts.where((p) => p.isNotEmpty).map((p) => baseURL + p).toList();
  }

  String _timeRange(Restaurant r) {
    // ถ้ามีฟิลด์ formatted ใช้ก่อน
    final fOpen = (r.formattedOpenTime ?? '').trim();
    final fClose = (r.formattedCloseTime ?? '').trim();
    if (fOpen.isNotEmpty || fClose.isNotEmpty) {
      return '${fOpen.isEmpty ? '-' : fOpen} - ${fClose.isEmpty ? '-' : fClose}';
    }
    // fallback: openTime/closeTime ที่อาจเป็น "HH:mm" หรือ "HH:mm:ss"
    String fmt(String? t) {
      if (t == null || t.trim().isEmpty) return '-';
      final s = t.trim();
      final mm = RegExp(r'^\d{1,2}:\d{2}').stringMatch(s);
      return mm ?? s;
    }
    return '${fmt(widget.restaurant.openTime)} - ${fmt(widget.restaurant.closeTime)}';
  }

  String _addressLine(Restaurant r) {
    final parts = <String>[
      (r.subdistrict ?? '').trim(),
      (r.district ?? '').trim(),
      (r.province ?? '').trim(),
    ].where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? 'ไม่ระบุที่อยู่' : parts.join(' • ');
  }

  bool _hasCoord(Restaurant r) =>
      (r.latitude ?? '').trim().isNotEmpty && (r.longitude ?? '').trim().isNotEmpty;

  bool get _canPick {
    if (!widget.fromActivity || widget.activity?.inviteDate == null) return false;
    final closeAt = widget.activity!.inviteDate!.subtract(const Duration(hours: 2));
    return DateTime.now().isBefore(closeAt);
    }

  int get _votes {
    if (widget.activity == null) return 0;
    final rid = widget.restaurant.restaurantId;
    if (rid == null) return 0;
    return widget.activity!.activityMembers
        .where((am) => am.selectRestaurant?.restaurant.restaurantId == rid)
        .length;
  }

  List<Member> get _voters {
    final act = widget.activity;
    final rid = widget.restaurant.restaurantId;
    if (act == null || rid == null) return const [];
    return act.activityMembers
        .where((am) => am.selectRestaurant?.restaurant.restaurantId == rid)
        .map((am) => am.member)
        .toList();
  }

  String get _closeText {
    if (widget.activity?.inviteDate == null) return '-';
    final closeAt = widget.activity!.inviteDate!.subtract(const Duration(hours: 2));
    return DateFormat("เลือกได้ถึง d MMM y • HH:mm", 'th').format(closeAt);
  }

  Future<void> _pick(BuildContext context) async {
    final memberId = UserLog().member?.memberId;
    final activityId = widget.activity?.activityId;
    final restaurantId = widget.restaurant.restaurantId;

    if (memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเข้าสู่ระบบ')));
      return;
    }
    if (activityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ข้อมูลกิจกรรมไม่สมบูรณ์')));
      return;
    }
    if (restaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ข้อมูลร้านไม่สมบูรณ์')));
      return;
    }

    try {
      final updated = await ActivitySelectionController().selectRestaurantForActivity(
        activityId: activityId,
        memberId: memberId,
        restaurantId: restaurantId,
      );
      if (context.mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เลือกไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _goCreateParty(BuildContext context) async {
    if (!widget.isLoggedIn && !UserLog().isLoggedIn) {
      await Navigator.pushNamed(context, '/login');
      if (!UserLog().isLoggedIn) return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddPostActivityPage(restaurant: widget.restaurant)),
    );
    if (result != null && context.mounted) {
      Navigator.pop(context, result);
    }
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _subtle),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: _subtle)),
      ],
    );
  }

  // avatar stack (กว้างพอให้ซ้อน 3 รูป)
  Widget _avatarStack(List<Member> members) {
    const double size = 24;
    const double overlap = 16;
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
                      ? const Icon(Icons.person, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // บล็อกที่อยู่ “แตะเพื่อดูเส้นทาง”
  Widget _addressBlock(BuildContext context) {
    final addr = _addressLine(widget.restaurant);
    final hasCoord = _hasCoord(widget.restaurant);
    final lat = (widget.restaurant.latitude ?? '').trim();
    final lon = (widget.restaurant.longitude ?? '').trim();

    return InkWell(
      onTap: hasCoord
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RouteMapPage(restaurant: widget.restaurant)),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.place, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ที่ตั้งร้านอาหาร', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(addr, style: const TextStyle(color: Colors.black87)),
                  if (hasCoord) ...[
                    const SizedBox(height: 2),
                    Text('พิกัด: $lat, $lon', style: const TextStyle(color: Colors.black87)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    hasCoord ? 'แตะเพื่อดูเส้นทาง' : 'ไม่มีพิกัดสำหรับเปิดเส้นทาง',
                    style: TextStyle(color: hasCoord ? Colors.blue : Colors.blue.shade300),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: hasCoord ? Colors.blue : Colors.blue.shade200),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeRange = _timeRange(widget.restaurant);
    final images = _imageUrls(widget.restaurant);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('รายละเอียดร้านอาหาร'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () {
              // TODO: share logic
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // รูปหลัก (PageView + จุดบอกหน้า)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      // ภาพ
                      if (images.isEmpty)
                        Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.restaurant, size: 56, color: Colors.grey),
                          ),
                        )
                      else
                        PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (_, i) => Image.network(
                            images[i],
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.restaurant, size: 56, color: Colors.grey),
                            ),
                          ),
                        ),

                      // จุดบอกหน้า
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
                ),
              ),
            ),

            // การ์ดรายละเอียด
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ประเภท
                    Text(
                      widget.restaurant.restaurantType?.typeName ?? 'ไม่ระบุประเภท',
                      style: const TextStyle(
                        color: _subtle,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ชื่อร้าน
                    Text(
                      widget.restaurant.restaurantName ?? 'ชื่อร้าน',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // chips เวลาเปิด-ปิด
                    _infoChip(Icons.access_time_rounded, timeRange),

                    const SizedBox(height: 18),
                    const Text(
                      'เกี่ยวกับ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (widget.restaurant.description ?? 'ไม่มีรายละเอียด'),
                      style: const TextStyle(color: Colors.black87, height: 1.4),
                    ),

                    const SizedBox(height: 18),
                    // ที่อยู่แบบแตะได้ -> RouteMapPage
                    _addressBlock(context),

                    if ((widget.restaurant.restaurantPhone ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.call_outlined, size: 18, color: _subtle),
                            const SizedBox(width: 8),
                            Text(
                              widget.restaurant.restaurantPhone!.trim(),
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                      ),

                    if (widget.fromActivity && widget.activity != null) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _avatarStack(_voters),
                          const SizedBox(width: 8),
                          Text('$_votes โหวต', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(_closeText, style: const TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ปุ่มล่าง
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.fromActivity ? (_canPick ? () => _pick(context) : null)
                                          : () => _goCreateParty(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.fromActivity ? Colors.cyan : _pill,
              disabledBackgroundColor: _pill.withOpacity(0.35),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: Text(widget.fromActivity ? 'เลือกร้านอาหาร' : 'สร้างปาร์ตี้'),
          ),
        ),
      ),
    );
  }
}

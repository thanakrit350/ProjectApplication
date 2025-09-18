import 'dart:async';
import 'dart:convert'; // <-- ต้องมีเพื่อ parse JSON ของรูป
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/controller/ActivityController.dart';
import 'package:newproject/model/Activity.dart';
import 'package:newproject/model/ActivityMember.dart';
import 'package:newproject/model/Restaurant.dart';

import 'RouteMapPage.dart';

class VotingResultPage extends StatefulWidget {
  final Activity activity;
  const VotingResultPage({super.key, required this.activity});

  @override
  State<VotingResultPage> createState() => _VotingResultPageState();
}

class _VotingResultPageState extends State<VotingResultPage> {
  late Activity _activity;
  Timer? _timer;
  bool _loading = false;

  bool get isSelectionOpen {
    final invite = _activity.inviteDate;
    if (invite == null) return false;
    final closeAt = invite.subtract(const Duration(hours: 2));
    return DateTime.now().isBefore(closeAt);
  }

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final id = _activity.activityId;
    if (id == null) return;
    try {
      setState(() => _loading = true);
      final updated = await ActivityController().getActivityById(id);
      if (updated != null && mounted) setState(() => _activity = updated);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ==== Vote grouping / pick winner ====
  List<_VoteGroup> _buildGroups() {
    final Map<int, _VoteGroup> map = {};
    for (final ActivityMember am in _activity.activityMembers) {
      final rid = am.selectRestaurant?.restaurant.restaurantId;
      final r = am.selectRestaurant?.restaurant;
      if (rid == null || r == null) continue;
      map.putIfAbsent(rid, () => _VoteGroup(restaurant: r, voters: []));
      map[rid]!.voters.add(am.member);
    }
    return map.values.toList();
  }

  int _stableSeed() {
    final a = _activity.activityId ?? 0;
    final b = _activity.inviteDate?.millisecondsSinceEpoch ?? 0;
    final c = _activity.postDate?.millisecondsSinceEpoch ?? 0;
    return (a ^ b ^ c) & 0x7FFFFFFF;
  }

  String _formatInvite() {
    final d = _activity.inviteDate;
    if (d == null) return '-';
    return DateFormat('วันEEEE d MMMM y • HH:mm', 'th').format(d);
  }

  // ---------- Image helpers ----------
  String _joinUrl(String p) {
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    final a = baseURL.endsWith('/') ? baseURL.substring(0, baseURL.length - 1) : baseURL;
    final b = p.startsWith('/') ? p.substring(1) : p;
    return '$a/$b';
  }

  List<String> _imageUrls(Restaurant r) {
    final raw = r.restaurantImg?.trim();
    if (raw == null || raw.isEmpty) return [];
    List<String> parts;
    if (raw.startsWith('[')) {
      try {
        parts = (json.decode(raw) as List).map((e) => e.toString()).toList();
      } catch (_) {
        parts = [raw];
      }
    } else {
      parts = raw.split(RegExp(r'\s*[,|]\s*'));
    }
    return parts.where((p) => p.isNotEmpty).map(_joinUrl).toList();
  }

  String? _coverImage(Restaurant r) {
    final list = _imageUrls(r);
    return list.isEmpty ? null : list.first;
  }

  // ---------- Helpers: หาเจ้าของกิจกรรมและร้านที่เจ้าของเลือก ----------
  int? _safeMemberId(ActivityMember am) {
    try {
      return am.member.memberId;
    } catch (_) {
      return null;
    }
  }

  int? _safeSelectedRestaurantId(ActivityMember am) {
    try {
      return am.selectRestaurant?.restaurant.restaurantId;
    } catch (_) {
      return null;
    }
  }

  /// หา memberId ของ "ผู้สร้างกิจกรรม" จาก activityMembers โดยดู field memberStatus
  int? _creatorMemberId() {
    for (final am in _activity.activityMembers) {
      final status = (am.memberStatus ?? '');
      if (status.contains('เจ้าของ')) {
        return _safeMemberId(am);
      }
    }
    return null;
  }

  /// หา restaurantId ที่ "ผู้สร้าง" เลือก (ถ้าเลือก)
  int? _creatorSelectedRestaurantId() {
    final cid = _creatorMemberId();
    if (cid == null) return null;
    for (final am in _activity.activityMembers) {
      final mid = _safeMemberId(am);
      if (mid == cid) {
        return _safeSelectedRestaurantId(am);
      }
    }
    return null;
  }

  // ---------- เลือกผู้ชนะ: ถ้าเสมอ → ให้สิทธิ์ผู้สร้างก่อน, ไม่งั้นสุ่มแบบ deterministic ----------
  _VoteGroup? _pickTopGroupDeterministic() {
    final groups = _buildGroups();
    if (groups.isEmpty) return null;

    // หาคะแนนมากสุด
    int maxVotes = 0;
    for (final g in groups) {
      if (g.voters.length > maxVotes) maxVotes = g.voters.length;
    }

    final tops = groups.where((g) => g.voters.length == maxVotes).toList();
    if (tops.length == 1) return tops.first;

    // เสมอหลายร้าน → ให้ร้านที่ "ผู้สร้าง" โหวตไว้ก่อน (ถ้ามีและอยู่ในกลุ่มที่เสมอ)
    final creatorPickId = _creatorSelectedRestaurantId();
    if (creatorPickId != null) {
      final picked = tops.where((g) => g.restaurant.restaurantId == creatorPickId);
      if (picked.isNotEmpty) return picked.first; // ✅ ผู้สร้างมาก่อน
    }

    // ผู้สร้างไม่ได้เลือก / เลือกไม่อยู่ในกลุ่มที่เสมอ → สุ่มแบบ deterministic
    final rnd = math.Random(_stableSeed());
    return tops[rnd.nextInt(tops.length)];
  }

  // ==== UI ====
  @override
  Widget build(BuildContext context) {
    final top = _pickTopGroupDeterministic();
    final totalParticipants = _activity.activityMembers.length;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),
          appBar: AppBar(
            centerTitle: true,
            title: const Text('ผลโหวตร้านอาหาร'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0.5,
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // หัวเรื่องกิจกรรม
                Center(
                  child: Column(
                    children: [
                      Text(
                        _activity.activityName ?? '-',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _InfoChip(
                        icon: Icons.event,
                        label: _formatInvite(),
                      ),
                      const SizedBox(height: 12),
                      // ผู้เข้าร่วม
                      _ParticipantsRow(
                        count: totalParticipants,
                        members: _activity.activityMembers.map((e) => e.member).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const _SectionHeader(text: 'ผลโหวตร้านอาหาร'),

                const SizedBox(height: 8),
                if (top == null)
                  _EmptyCard(isSelectionOpen: isSelectionOpen)
                else
                  _ResultCard(
                    group: top,
                    coverUrl: _coverImage(top.restaurant), // ✅ ส่งรูปที่ parse แล้วเข้าไป
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),

        // overlay loading
        if (_loading)
          Container(
            color: Colors.black12,
            child: const Center(
              child: SizedBox(
                width: 38, height: 38,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
      ],
    );
  }
}

// ======== Widgets ========

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(thickness: 1.2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const Expanded(child: Divider(thickness: 1.2)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ParticipantsRow extends StatelessWidget {
  final int count;
  final List<dynamic> members; // Member
  const _ParticipantsRow({required this.count, required this.members});

  @override
  Widget build(BuildContext context) {
    final maxShown = math.min(members.length, 8);
    final stackWidth = (maxShown == 0) ? 32.0 : 32.0 + (maxShown - 1) * 20.0;

    return Column(
      children: [
        Text(
          '$count คนเข้าร่วม',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          width: stackWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < maxShown; i++)
                Positioned(
                  left: i * 20.0,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: (members[i].profileImage != null &&
                              members[i].profileImage!.isNotEmpty)
                          ? NetworkImage(baseURL + members[i].profileImage!)
                          : null,
                      child: (members[i].profileImage == null ||
                              members[i].profileImage!.isEmpty)
                          ? const Icon(Icons.person, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final bool isSelectionOpen;
  const _EmptyCard({required this.isSelectionOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isSelectionOpen
                  ? 'ยังไม่มีการโหวต เริ่มโหวตและกลับมาดูผลได้แบบเรียลไทม์'
                  : 'หมดเวลาการโหวตแล้ว และยังไม่มีผลโหวต',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final _VoteGroup group;
  final String? coverUrl; // ✅ รับรูปจาก state (ที่ parse แล้ว)
  const _ResultCard({required this.group, required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final r = group.restaurant;
    final votes = group.voters.length;
    final typeName = r.restaurantType?.typeName ?? 'ไม่ระบุประเภท';
    final addr = [r.subdistrict ?? '', r.district ?? '', r.province ?? '']
        .where((e) => e.isNotEmpty)
        .join(' ');

    final maxShown = math.min(group.voters.length, 5);
    final stackWidth = (maxShown == 0) ? 28.0 : 28.0 + (maxShown - 1) * 20.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // รูป + ป้าย “ชนะ”
          Stack(
            children: [
              SizedBox(
                height: 170,
                width: double.infinity,
                child: (coverUrl != null)
                    ? Image.network(
                        coverUrl!,
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
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.25), blurRadius: 8)],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.emoji_events, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('ร้านที่ถูกเลือก',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ชื่อ + ฝั่งขวา
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        r.restaurantName ?? '-',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$votes คน',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(typeName, style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ผู้โหวต
                Row(
                  children: [
                    SizedBox(
                      height: 28,
                      width: stackWidth,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (int i = 0; i < maxShown; i++)
                            Positioned(
                              left: i * 20.0,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: (group.voters[i].profileImage != null &&
                                          group.voters[i].profileImage!.isNotEmpty)
                                      ? NetworkImage(baseURL + group.voters[i].profileImage!)
                                      : null,
                                  child: (group.voters[i].profileImage == null ||
                                          group.voters[i].profileImage!.isEmpty)
                                      ? const Icon(Icons.person, size: 12, color: Colors.white)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('โหวต', style: TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 12),

                // เวลาเปิด-ปิด
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${r.formattedOpenTime ?? '-'} - ${r.formattedCloseTime ?? '-'}',
                      style:
                          const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (addr.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(child: Text(addr, style: const TextStyle(color: Colors.black87))),
                    ],
                  ),
                if ((r.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(r.description!, style: const TextStyle(color: Colors.black87)),
                ],

                const SizedBox(height: 12),

                // แผนที่ย่อ
                _MiniMap(restaurant: r),

                const SizedBox(height: 14),

                // ปุ่มแผนที่เต็ม
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RouteMapPage(restaurant: r)),
                      );
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('ดูแผนที่ & เส้นทาง'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMap extends StatelessWidget {
  final Restaurant restaurant;
  const _MiniMap({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse(restaurant.latitude ?? '');
    final lon = double.tryParse(restaurant.longitude ?? '');
    if (lat == null || lon == null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('ไม่มีพิกัดร้านอาหาร', style: TextStyle(color: Colors.black54)),
      );
    }
    final center = LatLng(lat, lon);
    return SizedBox(
      height: 140,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            center: center,
            zoom: 15,
            interactiveFlags: InteractiveFlag.none,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.project',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteGroup {
  final Restaurant restaurant;
  final List<dynamic> voters; // Member
  _VoteGroup({required this.restaurant, required this.voters});
}

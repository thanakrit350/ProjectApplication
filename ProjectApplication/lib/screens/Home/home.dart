import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:newproject/boxs/userlog.dart';
import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/controller/ActivityController.dart';
import 'package:newproject/controller/ActivityInviteController.dart';
import 'package:newproject/model/Activity.dart';
import 'package:newproject/model/Member.dart';
import 'package:newproject/screens/Activity/AddPostActivityPage.dart';
import 'package:newproject/screens/Activity/ViewPostActivityPage.dart';
import 'package:newproject/screens/Member/LoginMemberPage.dart';
import 'package:newproject/screens/Member/ViewProfilePage.dart';
import 'package:newproject/screens/Restaurant/ListRestuarant.dart';

class HomeScreens extends StatefulWidget {
  const HomeScreens({super.key});

  @override
  State<HomeScreens> createState() => _HomeScreensState();
}

class _HomeScreensState extends State<HomeScreens> {
  int _selectedIndex = 0;
  final GlobalKey<_HomeContentState> _homeContentKey = GlobalKey<_HomeContentState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeContent(key: _homeContentKey),
      const ListRestaurant(),
    ];
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Home Tab
            Expanded(
              child: GestureDetector(
                onTap: () => _onItemTapped(0),
                child: Container(
                  height: 70,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 0
                            ? Colors.cyan.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        size: 28,
                        color: _selectedIndex == 0 ? Colors.cyan : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Center Add Button (Floating)
            Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.cyan, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () async {
                    if (UserLog().isLoggedIn) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddPostActivityPage()),
                      );
                      if (!mounted) return;
                      _homeContentKey.currentState?.refreshActivities();
                      setState(() => _selectedIndex = 0);
                    } else {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginMemberPage()),
                      );
                      if (!mounted) return;
                      _homeContentKey.currentState?.refreshActivities();
                    }
                  },
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),

            // Restaurant Tab
            Expanded(
              child: GestureDetector(
                onTap: () => _onItemTapped(1),
                child: Container(
                  height: 70,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 1
                            ? Colors.cyan.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 28,
                        color: _selectedIndex == 1 ? Colors.cyan : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with AutomaticKeepAliveClientMixin {
  // ดาต้าดิบทั้งหมด
  List<Activity> _allMyActivities = [];
  List<Activity> _allInvitedActivities = [];

  // state
  bool _isLoading = true;

  // ตัวกรอง
  String _searchText = '';
  String? _selectedTypeName; // ชื่อประเภทอาหารที่เลือก
  DateTime? _selectedDate;   // วันที่นัดหมายที่กรอง

  // ตัวเลือกประเภท (ดึงจากข้อมูลกิจกรรมที่โหลดมา)
  List<String> _typeOptions = [];

  // สำหรับดึงรีเฟรช
  void refreshActivities() => _loadActivities();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      setState(() => _isLoading = true);

      final currentUserId = UserLog().member?.memberId;
      final allActivities = await ActivityController().getAllActivities();

      // กิจกรรมที่เราเข้าร่วมหรือเป็นเจ้าของ
      final myJoinedActivities = allActivities.where((a) {
        for (final am in a.activityMembers) {
          final mid = am.member?.memberId;
          final status = am.memberStatus;
          if (mid == currentUserId && (status == 'เข้าร่วม' || status == 'เจ้าของกิจกรรม')) {
            return true;
          }
        }
        return false;
      }).toList();

      // เรียงตามวันที่โพสต์ใหม่ก่อน
      myJoinedActivities.sort((a, b) {
        final aPost = a.postDate;
        final bPost = b.postDate;
        if (aPost == null && bPost == null) return 0;
        if (aPost == null) return 1;
        if (bPost == null) return -1;
        return bPost.compareTo(aPost);
      });

      // คำเชิญ
      final invitedActivities =
          await ActivityInviteController().getInvitedActivities(currentUserId ?? 0);

      // เรียงคำเชิญตามวันที่เชิญล่าสุดสำหรับ user นี้
      invitedActivities.sort((a, b) {
        final aJoin = _joinDateOf(a, currentUserId);
        final bJoin = _joinDateOf(b, currentUserId);
        if (aJoin == null && bJoin == null) return 0;
        if (aJoin == null) return 1;
        if (bJoin == null) return -1;
        return bJoin.compareTo(aJoin);
      });

      // สร้างตัวเลือกประเภทจากกิจกรรมทั้งหมด (ไม่ยิง API เพิ่ม)
      final Set<String> typeSet = {};
      for (final a in [...myJoinedActivities, ...invitedActivities]) {
        final name = _typeNameOf(a);
        if (name != null && name.isNotEmpty) typeSet.add(name);
      }
      final types = typeSet.toList()..sort();

      setState(() {
        _allMyActivities = myJoinedActivities;
        _allInvitedActivities = invitedActivities;
        _typeOptions = types;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('load activities failed: $e');
      setState(() {
        _allMyActivities = [];
        _allInvitedActivities = [];
        _typeOptions = [];
        _isLoading = false;
      });
    }
  }

  DateTime? _joinDateOf(Activity a, int? userId) {
    if (userId == null) return null;
    for (final am in a.activityMembers) {
      if (am.member?.memberId == userId) return am.joinDate;
    }
    return null;
  }

  String? _typeNameOf(Activity a) {
    final n1 = a.restaurant?.restaurantType?.typeName;
    if (n1 != null && n1.isNotEmpty) return n1;
    final n2 = a.restaurantType?.typeName;
    if (n2 != null && n2.isNotEmpty) return n2;
    return null;
  }

  // ---------- Avatar helpers : กัน 404 และทำ fallback เป็นไอคอน ----------
  ImageProvider? _netAvatar(String? path) {
    if (path == null) return null;
    final p = path.trim();
    if (p.isEmpty) return null;

    final url = p.startsWith('http') ? p : (baseURL + p);
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    return NetworkImage(url);
  }

  Widget _avatar(String? path, {double radius = 12, IconData icon = Icons.person}) {
    final img = _netAvatar(path);
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: img,
      child: img == null ? Icon(icon, size: radius, color: Colors.white) : null,
    );
  }
  // ----------------------------------------------------------------------

  // ---------- FILTER ----------
  bool _matchesFilters(Activity a) {
    // คำค้นหาชื่อกิจกรรม
    if (_searchText.trim().isNotEmpty) {
      final name = (a.activityName ?? '').toLowerCase();
      if (!name.contains(_searchText.trim().toLowerCase())) return false;
    }
    // ประเภทอาหาร
    if (_selectedTypeName != null && _selectedTypeName!.isNotEmpty) {
      final typeName = _typeNameOf(a) ?? '';
      if (typeName != _selectedTypeName) return false;
    }
    // วันที่นัดหมาย (เทียบเฉพาะวัน)
    if (_selectedDate != null && a.inviteDate != null) {
      final d1 = DateTime(a.inviteDate!.year, a.inviteDate!.month, a.inviteDate!.day);
      final d2 = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      if (d1 != d2) return false;
    }
    return true;
  }

  List<Activity> get _myActivitiesFiltered =>
      _allMyActivities.where(_matchesFilters).toList();

  List<Activity> get _invitedActivitiesFiltered =>
      _allInvitedActivities.where(_matchesFilters).toList();

  // ---------- Pickers ----------
  Future<void> _openTypeSheet() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26, borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedTypeName = null);
                        Navigator.pop(ctx);
                      },
                      child: const Text('ล้างตัวกรอง'),
                    ),
                    const Spacer(),
                    const Text('เลือกประเภท', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('เสร็จ'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_typeOptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('ยังไม่มีข้อมูลประเภทจากกิจกรรม', style: TextStyle(color: Colors.black54)),
                  )
                else
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _typeOptions.map((t) {
                      final selected = _selectedTypeName == t;
                      return ChoiceChip(
                        label: Text(t),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _selectedTypeName = t);
                          Navigator.pop(ctx);
                        },
                        selectedColor: Colors.cyan,
                        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDateSheet() async {
    final now = DateTime.now();
    DateTime temp = _selectedDate ?? now;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black26, borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedDate = null);
                            Navigator.pop(ctx);
                          },
                          child: const Text('ล้างวันที่'),
                        ),
                        const Spacer(),
                        const Text('เลือกวันที่นัดหมาย', style: TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedDate = temp);
                            Navigator.pop(ctx);
                          },
                          child: const Text('เสร็จ'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        maximumDate: DateTime(now.year + 2, now.month, now.day),
                        minimumDate: DateTime(1900),
                        initialDateTime: temp,
                        onDateTimeChanged: (d) => setLocal(() => temp = d),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final member = UserLog().member;

    final dateLabel = _selectedDate == null
        ? 'เลือกวันที่'
        : DateFormat('d MMM yyyy', 'th_TH').format(_selectedDate!);

    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // แถวบน: ค้นหา + ตัวกรอง + โปรไฟล์
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  // กล่องค้นหา
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'ค้นหาชื่อกิจกรรม...',
                                border: InputBorder.none,
                              ),
                              onChanged: (s) => setState(() => _searchText = s),
                            ),
                          ),
                          if (_searchText.isNotEmpty)
                            GestureDetector(
                              onTap: () => setState(() => _searchText = ''),
                              child: const Icon(Icons.close, color: Colors.grey, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ปุ่มประเภทอาหาร
                  InkWell(
                    onTap: _openTypeSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            _selectedTypeName == null ? 'ประเภท' : _selectedTypeName!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ปุ่มเลือกวันที่
                  InkWell(
                    onTap: _openDateSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.grey, size: 18),
                          const SizedBox(width: 6),
                          Text(dateLabel, style: const TextStyle(fontSize: 13)),
                          if (_selectedDate != null) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setState(() => _selectedDate = null),
                              child: const Icon(Icons.close, color: Colors.grey, size: 16),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // โปรไฟล์ (ไปหน้าโปรไฟล์/ล็อกอิน)
                  GestureDetector(
                    onTap: () async {
                      if (UserLog().isLoggedIn) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ViewProfilePage()),
                        );
                        if (!mounted) return;
                        setState(() {});
                        await _loadActivities();
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginMemberPage()),
                        );
                        if (!mounted) return;
                        setState(() {});
                        await _loadActivities();
                      }
                    },
                    child: _avatar(member?.profileImage, radius: 18, icon: Icons.person),
                  ),
                ],
              ),
            ),

            const TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [Tab(text: 'เข้าร่วม'), Tab(text: 'คำเชิญ')],
            ),

            Expanded(
              child: TabBarView(
                children: [
                  // รายการ "เข้าร่วม" พร้อมดึงลงรีเฟรช
                  RefreshIndicator(
                    onRefresh: _loadActivities,
                    child: _buildActivityList(_myActivitiesFiltered),
                  ),
                  // รายการ "คำเชิญ" พร้อมดึงลงรีเฟรช
                  RefreshIndicator(
                    onRefresh: _loadActivities,
                    child: _buildInvitationList(_invitedActivitiesFiltered),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList(List<Activity> activities) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (activities.isEmpty) return const Center(child: Text('ไม่มีกิจกรรม'));

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: activities.length,
      itemBuilder: (_, i) {
        final a = activities[i];
        final type = _typeNameOf(a) ?? 'ไม่ทราบประเภท';
        final dateTxt = a.inviteDate != null
            ? DateFormat('d MMM yyyy', 'th_TH').format(a.inviteDate!)
            : '-';
        final joined = a.activityMembers.length;

        return GestureDetector(
          onTap: () async {
            final changed = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ViewPostActivityPage(activity: a)),
            );
            if (changed == true) {
              await _loadActivities();
            }
          },
          child: Card(
            color: Colors.yellow.shade50,
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restaurant_menu, size: 16),
                      const SizedBox(width: 4),
                      Text(type, style: const TextStyle(fontSize: 14)),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(dateTxt, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.activityName ?? '',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (int i = 0; i < a.activityMembers.length && i < 4; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _avatar(a.activityMembers[i].member?.profileImage, radius: 12),
                        ),
                      Text('ผู้เข้าร่วม $joined คน'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvitationList(List<Activity> activities) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (activities.isEmpty) return const Center(child: Text('ไม่มีคำเชิญ'));

    final myId = UserLog().member?.memberId;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: activities.length,
      itemBuilder: (_, i) {
        final a = activities[i];

        // คนเชิญ = คนอื่นที่ไม่ใช่เราในสมาชิกกิจกรรมนี้
        Member? inviter;
        for (final am in a.activityMembers) {
          if (am.member?.memberId != myId) {
            inviter = am.member;
            break;
          }
        }

        final inviterName = inviter != null
            ? '${inviter.firstName ?? ''} ${inviter.lastName ?? ''}'.trim()
            : 'ไม่ทราบชื่อ';

        final inviterImg = inviter?.profileImage;

        final name = a.activityName ?? '';
        final dateTxt = a.inviteDate != null
            ? DateFormat('d MMM yyyy', 'th_TH').format(a.inviteDate!)
            : '-';
        final timeTxt = a.inviteDate != null
            ? DateFormat('HH:mm น.', 'th_TH').format(a.inviteDate!)
            : '-';

        return Card(
          color: Colors.yellow.shade50,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _avatar(inviterImg, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        inviterName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(dateTxt, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(timeTxt, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 16),
                // ---------- ปุ่มตอบรับคำเชิญ (กว้างเท่ากัน) ----------
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => _respondToInvite(a.activityId!, 'เข้าร่วม'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'เข้าร่วม',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => _respondToInvite(a.activityId!, 'ปฏิเสธ'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.grey.shade800,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'ปฏิเสธ',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // ----------------------------------------------
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _respondToInvite(int activityId, String response) async {
    final memberId = UserLog().member?.memberId;
    if (memberId == null) {
      // ยังไม่ล็อกอิน -> ให้ไปหน้า Login ก่อน
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginMemberPage()),
      );
      if (!mounted) return;
      await _loadActivities();
      return;
    }

    final ok = await ActivityInviteController().respondInvite(activityId, memberId, response);
    if (ok && mounted) {
      await _loadActivities();
    }
  }
}

import 'dart:async';
import 'dart:convert'; // <-- เพิ่มเพื่อ parse JSON รูป
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:newproject/boxs/userlog.dart';
import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/controller/ActivityController.dart';
import 'package:newproject/model/Activity.dart';
import 'package:newproject/screens/Activity/AddPostActivityPage.dart';
import 'package:newproject/screens/Activity/InviteFriendPage.dart';
import 'package:newproject/screens/SelectRestaurant/SelectRestaurantPage.dart';
import 'package:newproject/screens/SelectRestaurant/VotingResultPage.dart';
import 'package:newproject/screens/SelectRestaurant/RouteMapPage.dart';

class ViewPostActivityPage extends StatefulWidget {
  final Activity activity;
  const ViewPostActivityPage({Key? key, required this.activity}) : super(key: key);

  @override
  State<ViewPostActivityPage> createState() => _ViewPostActivityPageState();
}

class _ViewPostActivityPageState extends State<ViewPostActivityPage> {
  
  DateTime? _inviteLocal() => currentActivity.inviteDate; // จาก fromJson เป็น local แล้ว


  bool get isSelectionOpen {
    final invite = _inviteLocal();
    if (invite == null) return false;
    final closeAt = invite.subtract(const Duration(hours: 2));
    return DateTime.now().isBefore(closeAt);
  }

  bool get isFinished {
    final invite = _inviteLocal();
    if (invite == null) return false;
    return DateTime.now().isAfter(invite);
  }

  
  late Activity currentActivity;
  bool _changed = false;

  Timer? _statusTimer;
  bool _statusPushed = false;

  // ---------- carousel state ----------
  final PageController _imgCtrl = PageController();
  int _imgPage = 0;

  @override
  void initState() {
    super.initState();
    currentActivity = widget.activity;

    // ❌ ไม่เรียกทันที เพื่อลด false-finish ตอนเพิ่งเปิด
    // _maybeUpdateStatusToFinished();

    // ตั้ง timer ไว้ได้ แต่ให้ตัวมันเองเช็คเงื่อนไขละเอียด (ดูด้านล่าง)
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {}); // ให้ UI รีเพนต์
      _maybeUpdateStatusToFinished();
    });
  }


  @override
  void dispose() {
    _statusTimer?.cancel();
    _imgCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAlert(String message, {String title = 'แจ้งเตือน'}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ตกลง')),
        ],
      ),
    );
  }

  bool get isOwner {
    final currentUserId = UserLog().member?.memberId;
    return currentActivity.activityMembers.any(
      (am) => am.member.memberId == currentUserId && am.memberStatus == "เจ้าของกิจกรรม",
    );
  }

  bool get hasSelectedRestaurant => currentActivity.restaurant != null;


  bool get hasVoted {
    final uid = UserLog().member?.memberId;
    return currentActivity.activityMembers.any(
      (am) => am.member.memberId == uid && am.selectRestaurant != null,
    );
  }

  Future<void> _refreshActivity() async {
    if (currentActivity.activityId != null) {
      try {
        final updated = await ActivityController().getActivityById(currentActivity.activityId!);
        if (updated != null && mounted) {
          setState(() => currentActivity = updated);
        }
      } catch (e) {
        debugPrint('Failed to refresh activity: $e');
      }
    }
  }

    Future<void> _maybeUpdateStatusToFinished() async {
    final invite = _inviteLocal();
    if (invite == null) return;

    // Grace กันเวลาคลาดเคลื่อนเครื่องผู้ใช้/เซิร์ฟเวอร์
    const grace = Duration(seconds: 45);
    final shouldFinish = DateTime.now().isAfter(invite.add(grace));

    if (!shouldFinish) return;
    if (_statusPushed) return;
    if (currentActivity.statusPost == 'ดำเนินการเสร็จสิ้น') {
      _statusPushed = true;
      return;
    }

    try {
      final payload = Activity(
        activityId: currentActivity.activityId,
        activityName: currentActivity.activityName,
        descriptionActivity: currentActivity.descriptionActivity,
        inviteDate: currentActivity.inviteDate, // เก็บแบบเดิม (เรา serialize เป็น UTC อยู่แล้ว)
        postDate: currentActivity.postDate,
        statusPost: 'ดำเนินการเสร็จสิ้น',
        isOwnerSelect: currentActivity.isOwnerSelect,
        restaurantType: currentActivity.restaurantType,
        restaurant: currentActivity.restaurant,
        activityMembers: currentActivity.activityMembers,
      );
      final updated = await ActivityController()
          .updateActivity(currentActivity.activityId!, payload);
      if (updated != null && mounted) {
        setState(() {
          currentActivity = updated;
          _statusPushed = true;
        });
      }
    } catch (e) {
      debugPrint('status push failed: $e');
    }
  }


  // ---------- รูปของร้าน (parse ทั้ง JSON array, คั่น , หรือ |) ----------
  List<String> _imageUrls() {
    final r = currentActivity.restaurant;
    if (r == null) return [];
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

  @override
  Widget build(BuildContext context) {
    final statusText = isFinished
        ? 'ดำเนินการเสร็จสิ้น'
        : (currentActivity.statusPost ?? 'กำลังดำเนินอยู่');
    final statusColor = isFinished ? Colors.red : Colors.green;

    final String typeName = currentActivity.restaurant?.restaurantType?.typeName ??
        currentActivity.restaurantType?.typeName ??
        'ไม่ระบุประเภท';

    final images = _imageUrls();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isOwner ? "ปาร์ตี้ของฉัน" : currentActivity.activityName ?? "กิจกรรม"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: isOwner && !isFinished
              ? [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'invite') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InviteFriendPage(activity: currentActivity),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'invite', child: Text('เชิญเพื่อน')),
                    ],
                  )
                ]
              : null,
        ),
        body: RefreshIndicator(
          onRefresh: _refreshActivity,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasSelectedRestaurant) ...[
                  // ---------- Image Carousel (แทน Image.network เดิม) ----------
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: Stack(
                          children: [
                            if (images.isEmpty)
                              Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(Icons.restaurant, size: 56, color: Colors.grey),
                                ),
                              )
                            else
                              PageView.builder(
                                controller: _imgCtrl,
                                itemCount: images.length,
                                onPageChanged: (i) => setState(() => _imgPage = i),
                                itemBuilder: (_, i) => Image.network(
                                  images[i],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.restaurant, size: 56, color: Colors.grey),
                                  ),
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
                                        color: i == _imgPage ? Colors.white : Colors.white54,
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
                ],
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isOwner) ...[
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: _getCreatorImage(),
                              child: _getCreatorImage() == null
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _getCreatorName(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        currentActivity.activityName ?? 'ไม่มีชื่อกิจกรรม',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            currentActivity.inviteDate != null
                                ? DateFormat('d MMM y hh:mm', 'th').format(_inviteLocal()!)
                                : '-',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          const Icon(Icons.restaurant_menu),
                          const SizedBox(width: 8),
                          Text(typeName, style: const TextStyle(fontSize: 16)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withOpacity(0.25)),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if ((currentActivity.descriptionActivity ?? '').isNotEmpty) ...[
                        Text(currentActivity.descriptionActivity!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                      ],

                      if (hasSelectedRestaurant) _buildAddressSection(),

                      const SizedBox(height: 16),
                      Text(
                        "${currentActivity.activityMembers.length} ผู้ร่วม",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildMembersList(),
                      const SizedBox(height: 20),

                      if (isFinished) ...[
                        _safeActionsSection(),
                      ] else ...[
                        if (isOwner) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final updated = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddPostActivityPage(editActivity: currentActivity),
                                      ),
                                    );
                                    if (updated != null) {
                                      _changed = true;
                                      await _refreshActivity();
                                      if (!mounted) return;
                                      await _showAlert('บันทึกการแก้ไขสำเร็จ');
                                    }
                                  },
                                  icon: const Icon(Icons.edit, color: Colors.white),
                                  label: const Text("แก้ไขปาร์ตี้", style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyan,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDeleteConfirmDialog(context);
                                    if (confirm && currentActivity.activityId != null) {
                                      try {
                                        await ActivityController().deleteActivity(currentActivity.activityId!);
                                        if (!mounted) return;
                                        // (ลบ SnackBar “ลบกิจกรรมแล้ว” ออกตามที่ขอ)
                                        Navigator.pop(context, true);
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("ลบกิจกรรมไม่สำเร็จ: $e")),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  label: const Text("ลบปาร์ตี้", style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (!hasSelectedRestaurant) ...[
                          const SizedBox(height: 12),
                          if (hasVoted)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VotingResultPage(activity: currentActivity),
                                    ),
                                  );
                                  if (result is Activity) {
                                    setState(() {
                                      currentActivity = result;
                                      _changed = true;
                                    });
                                  } else {
                                    await _refreshActivity();
                                  }
                                },
                                child: const Text('ดูผลโหวตร้านอาหาร'),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isSelectionOpen ? () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SelectRestaurantPage(activity: currentActivity),
                                    ),
                                  );
                                  if (result is Activity) {
                                    setState(() {
                                      currentActivity = result;
                                      _changed = true;
                                    });
                                  } else {
                                    await _refreshActivity();
                                    _changed = true;
                                  }
                                } : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyan,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  isSelectionOpen ? "โหวตร้านอาหาร" : "ปิดการโหวตแล้ว",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- safe actions section ----------
  Widget _safeActionsSection() {
    // ซ่อนปุ่ม "ดูผลโหวตร้านอาหาร" ถ้า: ถึงเวลานัดแล้ว (isFinished) และมีร้านถูกเลือกแล้ว (hasSelectedRestaurant)
    final bool showVoteResultBtn = !(isFinished && hasSelectedRestaurant);

    return Column(
      children: [
        if (showVoteResultBtn)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.how_to_vote),
              label: const Text('ดูผลโหวตร้านอาหาร'),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VotingResultPage(activity: currentActivity),
                  ),
                );
                if (result is Activity) {
                  setState(() {
                    currentActivity = result;
                    _changed = true;
                  });
                } else {
                  await _refreshActivity();
                }
              },
            ),
          ),
        if (showVoteResultBtn) const SizedBox(height: 8),

        if (hasSelectedRestaurant &&
            (currentActivity.restaurant!.latitude ?? '').isNotEmpty &&
            (currentActivity.restaurant!.longitude ?? '').isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.directions),
              label: const Text('เปิดแผนที่/เส้นทาง'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RouteMapPage(restaurant: currentActivity.restaurant!),
                  ),
                );
              },
            ),
          ),

        if (isOwner) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDeleteConfirmDialog(context);
                if (confirm && currentActivity.activityId != null) {
                  try {
                    await ActivityController().deleteActivity(currentActivity.activityId!);
                    if (!mounted) return;
                    Navigator.pop(context, true);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("ลบกิจกรรมไม่สำเร็จ: $e")),
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text("ลบกิจกรรม", style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ],
    );
  }



  // ---------- Address Section ----------
  Widget _buildAddressSection() {
    final r = currentActivity.restaurant!;
    final province = r.province?.trim().isNotEmpty == true ? r.province!.trim() : 'ไม่ระบุจังหวัด';
    final district = r.district?.trim().isNotEmpty == true ? r.district!.trim() : 'ไม่ระบุอำเภอ';
    final subdistrict = r.subdistrict?.trim().isNotEmpty == true ? r.subdistrict!.trim() : 'ไม่ระบุตำบล';
    final lat = (r.latitude ?? '').trim();
    final lon = (r.longitude ?? '').trim();
    final hasCoord = lat.isNotEmpty && lon.isNotEmpty;

    return InkWell(
      onTap: hasCoord
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RouteMapPage(restaurant: r)),
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
                  _kv('จังหวัด', province),
                  _kv('อำเภอ', district),
                  _kv('ตำบล', subdistrict),
                  if (hasCoord) _kv('พิกัด', '$lat, $lon'),
                  const SizedBox(height: 6),
                  Text(
                    hasCoord ? 'แตะเพื่อดูเส้นทาง' : 'ไม่มีพิกัดสำหรับเปิดเส้นทาง',
                    style: const TextStyle(color: Colors.blue),
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

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: currentActivity.activityMembers.length,
      itemBuilder: (context, index) {
        final member = currentActivity.activityMembers[index].member;
        final memberStatus = currentActivity.activityMembers[index].memberStatus;

        return Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: member.profileImage != null && member.profileImage!.isNotEmpty
                  ? NetworkImage(baseURL + member.profileImage!)
                  : null,
              child: member.profileImage == null || member.profileImage!.isEmpty
                  ? const Icon(Icons.person, size: 25, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              member.firstName ?? "User ${index + 1}",
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              memberStatus == "เจ้าของกิจกรรม" ? "เจ้าของ" : "เข้าร่วม",
              style: TextStyle(
                fontSize: 10,
                color: memberStatus == "เจ้าของกิจกรรม" ? Colors.orange : Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  String _getCreatorName() {
    final creator = currentActivity.activityMembers
        .firstWhere(
          (am) => am.memberStatus == "เจ้าของกิจกรรม",
          orElse: () => currentActivity.activityMembers.first,
        )
        .member;

    return "${creator.firstName ?? ''} ${creator.lastName ?? ''}".trim();
  }

  ImageProvider? _getCreatorImage() {
    final creator = currentActivity.activityMembers
        .firstWhere(
          (am) => am.memberStatus == "เจ้าของกิจกรรม",
          orElse: () => currentActivity.activityMembers.first,
        )
        .member;

    if (creator.profileImage != null && creator.profileImage!.isNotEmpty) {
      return NetworkImage(baseURL + creator.profileImage!);
    }
    return null;
  }
}

Future<bool> showDeleteConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "ยืนยันการลบโพสต์",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "คุณต้องการลบโพสต์นี้หรือไม่?",
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ยกเลิก"))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("ยืนยัน", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

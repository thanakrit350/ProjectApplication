import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // สำหรับ inputFormatters
import 'package:newproject/boxs/userlog.dart';
import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/controller/ActivityController.dart';
import 'package:newproject/controller/ActivityInviteController.dart';
import 'package:newproject/model/Activity.dart';
import 'package:newproject/model/ActivityMember.dart';
import 'package:newproject/model/Member.dart';

enum InviteMode { none, email, phone }

class InviteFriendPage extends StatefulWidget {
  final Activity activity;

  const InviteFriendPage({Key? key, required this.activity}) : super(key: key);

  @override
  State<InviteFriendPage> createState() => _InviteFriendPageState();
}

class _InviteFriendPageState extends State<InviteFriendPage> {
  // ช่องกรอก
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // ประวัติ + ตัวเลือก
  List<InviteHistory> _inviteHistory = [];
  List<String> _selectedEmails = []; // เลือกจากประวัติ
  bool _isLoading = false;
  bool _isLoadingHistory = true;

  // โหมดสำหรับ "ล็อกเฉพาะช่องกรอก" แต่ไม่ล็อกรายการประวัติ
  InviteMode _mode = InviteMode.none;
  bool get _emailEnabled => _mode != InviteMode.phone;
  bool get _phoneEnabled => _mode != InviteMode.email;
  void _switchMode(InviteMode m) {
    if (_mode == m) return;
    setState(() => _mode = m);
  }

  // --- carousel state สำหรับรูปหัวกิจกรรม ---
  final PageController _imgCtrl = PageController();
  int _imgPage = 0;

  @override
  void initState() {
    super.initState();
    _loadCrossActivityInviteHistory();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _imgCtrl.dispose();
    super.dispose();
  }

  // ---------- VALIDATORS ----------
  String? _validatePhone(String p) {
    final s = p.trim();
    if (s.isEmpty) return "กรุณากรอกเบอร์โทรศัพท์";
    if (!RegExp(r'^\d+$').hasMatch(s)) return "กรุณากรอกเป็นตัวเลขเท่านั้น";
    if (s.length != 10) return "กรุณากรอกเบอร์ให้ครบ 10 หลัก";
    if (!s.startsWith('0')) return "หมายเลขต้องขึ้นต้นด้วย 0";
    return null;
  }

  String? _validateEmail(String e) {
    final s = e.trim();
    if (s.isEmpty) return "กรุณากรอกอีเมล";
    if (s.contains(' ')) return "อีเมลต้องไม่มีช่องว่าง";
    if (s.length < 5 || s.length > 50) return "กรุณากรอกอีเมล 5–50 ตัวอักษร";
    final ok = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$').hasMatch(s);
    if (!ok) return "รูปแบบอีเมลไม่ถูกต้อง";
    return null;
  }

  // โหลดประวัติการเชิญจากทุกกิจกรรมของผู้ใช้ (อิง email)
  Future<void> _loadCrossActivityInviteHistory() async {
    try {
      setState(() => _isLoadingHistory = true);

      final currentUserId = UserLog().member?.memberId;
      if (currentUserId == null) {
        setState(() => _isLoadingHistory = false);
        return;
      }

      final allActivities = await ActivityController().getAllActivities();
      final myOwnedActivities = allActivities.where((activity) {
        return activity.activityMembers.any((am) =>
            am.member.memberId == currentUserId &&
            am.memberStatus == "เจ้าของกิจกรรม");
      }).toList();

      final Map<String, InviteHistory> uniqueInvites = {};
      for (Activity activity in myOwnedActivities) {
        for (ActivityMember am in activity.activityMembers) {
          if (am.member.memberId == currentUserId ||
              am.memberStatus == "เจ้าของกิจกรรม") {
            continue;
          }

          final email = am.member.email;
          if (email == null || email.isEmpty) continue;

          final alreadyInCurrent = widget.activity.activityMembers.any(
              (currentAm) => currentAm.member.email == email);

          String status;
          if (alreadyInCurrent) {
            final st = widget.activity.activityMembers
                .firstWhere((m) => m.member.email == email)
                .memberStatus;
            status = (st == "เข้าร่วม") ? "เข้าร่วมแล้ว" : "เชิญแล้ว";
          } else {
            status = "ยังไม่ได้เชิญ";
          }

          if ((uniqueInvites[email]?.inviteDate ?? DateTime.fromMillisecondsSinceEpoch(0))
                .isBefore(am.joinDate)) {
            uniqueInvites[email] = InviteHistory(
              member: am.member,
              inviteDate: am.joinDate,
              status: status,
              activityName: activity.activityName ?? "ไม่มีชื่อกิจกรรม",
            );
          }
        }
      }

      final historyList = uniqueInvites.values.toList()
        ..sort((a, b) => b.inviteDate.compareTo(a.inviteDate));

      setState(() {
        _inviteHistory = historyList;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _inviteHistory = [];
        _isLoadingHistory = false;
      });
    }
  }

  // =============== ยืนยัน & ส่งเชิญ ===============
  Future<void> _sendInvites() async {
    final typedEmail = _emailController.text.trim();
    final typedPhone = _phoneController.text.trim();

    // อนุญาต "กรอกเบอร์ + เลือกอีเมลจากประวัติ" ได้พร้อมกัน
    if (_selectedEmails.isEmpty && typedEmail.isEmpty && typedPhone.isEmpty) {
      await _showAlert("กรุณาใส่อีเมล/เบอร์ หรือเลือกเพื่อนจากรายชื่อ", title: "แจ้งเตือน");
      return;
    }
    if (widget.activity.activityId == null) {
      await _showAlert("กิจกรรมไม่พร้อมสำหรับการเชิญ", title: "แจ้งเตือน");
      return;
    }

    // ตรวจรูปแบบเฉพาะที่มีการกรอก
    if (typedEmail.isNotEmpty) {
      final err = _validateEmail(typedEmail);
      if (err != null) {
        await _showAlert(err, title: "อีเมลไม่ถูกต้อง");
        return;
      }
    }
    if (typedPhone.isNotEmpty) {
      final err = _validatePhone(typedPhone);
      if (err != null) {
        await _showAlert(err, title: "เบอร์โทรไม่ถูกต้อง");
        return;
      }
    }

    // รวมอีเมล/เบอร์ที่จะเชิญ
    final Set<String> emailsToInvite = {};
    if (typedEmail.isNotEmpty) emailsToInvite.add(typedEmail);
    emailsToInvite.addAll(_selectedEmails);

    final Set<String> phonesToInvite = {};
    if (typedPhone.isNotEmpty) phonesToInvite.add(typedPhone);

    // เตือนซ้ำจากข้อมูลปัจจุบันใน activity
    final dupEmailsLocal = emailsToInvite.where(_isAlreadyInvitedEmail).toList();
    final dupPhonesLocal = phonesToInvite.where(_isAlreadyInvitedPhone).toList();
    if (dupEmailsLocal.isNotEmpty || dupPhonesLocal.isNotEmpty) {
      await _showDuplicateAlert(dupEmailsLocal, dupPhonesLocal);
      dupEmailsLocal.forEach(emailsToInvite.remove);
      dupPhonesLocal.forEach(phonesToInvite.remove);
      if (emailsToInvite.isEmpty && phonesToInvite.isEmpty) return;
    }

    // dialog ยืนยัน
    final previews = _buildInvitePreviews(emailsToInvite, phonesToInvite);
    final ok = await _showConfirmDialog(previews);
    if (ok != true) return;

    setState(() => _isLoading = true);

    int success = 0;
    final List<String> dupEmailsServer = [];
    final List<String> dupPhonesServer = [];
    final List<String> notFoundList = [];
    final List<String> otherErrors = [];

    // ส่งอีเมล
    for (final email in emailsToInvite) {
      try {
        final s = await ActivityInviteController()
            .inviteByEmail(widget.activity.activityId!, email);
        if (s) {
          success++;
        } else {
          otherErrors.add("อีเมล: $email");
        }
      } catch (e) {
        final msg = _prettyError(e.toString());
        if (msg.contains("เชิญอีเมลนี้ไปแล้ว") || msg.contains("เคยเชิญอีเมล")) {
          dupEmailsServer.add(email);
        } else if (msg.contains("ไม่พบสมาชิก")) {
          notFoundList.add("อีเมล: $email");
        } else {
          otherErrors.add("อีเมล: $email — $msg");
        }
      }
    }

    // ส่งเบอร์
    for (final phone in phonesToInvite) {
      try {
        final s = await ActivityInviteController()
            .inviteByPhone(widget.activity.activityId!, phone);
        if (s) {
          success++;
        } else {
          otherErrors.add("เบอร์: $phone");
        }
      } catch (e) {
        final msg = _prettyError(e.toString());
        if (msg.contains("เชิญเบอร์นี้ไปแล้ว") || msg.contains("เคยเชิญเบอร์")) {
          dupPhonesServer.add(phone);
        } else if (msg.contains("ไม่พบสมาชิก")) {
          notFoundList.add("เบอร์: $phone");
        } else {
          otherErrors.add("เบอร์: $phone — $msg");
        }
      }
    }

    setState(() => _isLoading = false);

    // สรุปผล
    if (success > 0) {
      await _showAlert("ส่งคำเชิญสำเร็จ $success รายการ", title: "สำเร็จ");
      _emailController.clear();
      _phoneController.clear();
      setState(() {
        _selectedEmails.clear();
        _mode = InviteMode.none;
      });
      _loadCrossActivityInviteHistory();
    }

    if (dupEmailsServer.isNotEmpty || dupPhonesServer.isNotEmpty) {
      await _showAlert(
        [
          if (dupEmailsServer.isNotEmpty)
            "อีเมลที่ถูกเชิญไปแล้ว:\n• ${dupEmailsServer.join("\n• ")}",
          if (dupPhonesServer.isNotEmpty)
            "เบอร์ที่ถูกเชิญไปแล้ว:\n• ${dupPhonesServer.join("\n• ")}",
        ].join("\n\n"),
        title: "พบรายการซ้ำ",
      );
    }

    if (notFoundList.isNotEmpty) {
      await _showAlert(
        "ไม่พบบัญชีผู้ใช้ในระบบสำหรับ:\n• ${notFoundList.join("\n• ")}",
        title: "ไม่พบผู้ใช้",
      );
    }

    if (otherErrors.isNotEmpty) {
      await _showAlert(
        "ไม่สามารถส่งคำเชิญบางรายการได้:\n• ${otherErrors.join("\n• ")}",
        title: "เกิดข้อผิดพลาด",
      );
    }
  }

  // ล้างข้อความ error ให้สั้น/อ่านง่าย
  String _prettyError(String raw) {
    var s = raw;
    s = s.replaceAll(RegExp(r'Exception:\s*'), '');
    s = s.replaceAll('เกิดข้อผิดพลาด:', '');
    s = s.trim();
    return s.isEmpty ? 'เกิดข้อผิดพลาด' : s;
  }

  // ตรวจว่า email/phone อยู่ใน activity อยู่แล้วหรือไม่
  bool _isAlreadyInvitedEmail(String email) =>
      widget.activity.activityMembers.any((am) => (am.member.email ?? '') == email);

  bool _isAlreadyInvitedPhone(String phone) =>
      widget.activity.activityMembers.any((am) => (am.member.phoneNumber ?? '') == phone);

  // แจ้งเตือนรายการซ้ำจากข้อมูลปัจจุบัน
  Future<void> _showDuplicateAlert(List<String> dupEmails, List<String> dupPhones) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("พบรายการที่ถูกเชิญไปแล้ว"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dupEmails.isNotEmpty) ...[
                const Text("อีเมล:", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...dupEmails.map((e) => Text("• $e")).toList(),
                const SizedBox(height: 10),
              ],
              if (dupPhones.isNotEmpty) ...[
                const Text("เบอร์โทร:", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...dupPhones.map((p) => Text("• $p")).toList(),
              ],
              const SizedBox(height: 12),
              const Text(
                "ระบบจะข้ามรายการที่ซ้ำ และส่งคำเชิญเฉพาะรายการใหม่เท่านั้น",
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ตกลง")),
        ],
      ),
    );
  }

  // แปลงอีเมล/เบอร์ให้เป็นโครงสำหรับแสดงใน dialog ยืนยัน
  List<_InvitePreview> _buildInvitePreviews(Set<String> emails, Set<String> phones) {
    final Map<String, InviteHistory> byEmail = {
      for (final h in _inviteHistory)
        if ((h.member.email ?? '').isNotEmpty) h.member.email!: h
    };

    final List<_InvitePreview> items = [];

    for (final e in emails) {
      final h = byEmail[e];
      items.add(
        _InvitePreview(
          email: e,
          fullName: h != null
              ? "${h.member.firstName ?? ''} ${h.member.lastName ?? ''}".trim()
              : null,
          imageUrl: h != null && (h.member.profileImage?.isNotEmpty ?? false)
              ? baseURL + h.member.profileImage!
              : null,
        ),
      );
    }

    for (final p in phones) {
      final h = _inviteHistory.firstWhere(
        (ih) => (ih.member.phoneNumber ?? '') == p,
        orElse: () => InviteHistory(
          member: Member(firstName: null, lastName: null, email: null, phoneNumber: null),
          inviteDate: DateTime.fromMillisecondsSinceEpoch(0),
          status: "ยังไม่ได้เชิญ",
          activityName: null,
        ),
      );
      final matched = (h.member.phoneNumber == p);
      items.add(
        _InvitePreview(
          phone: p,
          fullName: matched
              ? "${h.member.firstName ?? ''} ${h.member.lastName ?? ''}".trim()
              : null,
          imageUrl: matched && (h.member.profileImage?.isNotEmpty ?? false)
              ? baseURL + h.member.profileImage!
              : null,
        ),
      );
    }

    return items;
  }

  // กล่องยืนยันก่อนส่งจริง (แสดงรูป/ชื่อ/อีเมล/เบอร์)
  Future<bool?> _showConfirmDialog(List<_InvitePreview> previews) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "ยืนยันผู้ที่จะเชิญ",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("ทั้งหมด ${previews.length} รายการ",
                      style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: previews.isEmpty
                        ? const Center(child: Text("ไม่มีรายการเชิญ"))
                        : ListView.separated(
                            itemCount: previews.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = previews[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                                      ? NetworkImage(p.imageUrl!)
                                      : null,
                                  child: (p.imageUrl?.isEmpty ?? true)
                                    ? const Icon(Icons.person, color: Colors.white)
                                    : null,
                                ),
                                title: Text(
                                  (p.fullName?.isNotEmpty ?? false) ? p.fullName! : "ไม่ทราบชื่อ",
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (p.email != null && p.email!.isNotEmpty)
                                      Text(p.email!, style: const TextStyle(color: Colors.black54)),
                                    if (p.phone != null && p.phone!.isNotEmpty)
                                      Text(p.phone!, style: const TextStyle(color: Colors.black54)),
                                    if ((p.email == null || p.email!.isEmpty) &&
                                        (p.phone == null || p.phone!.isEmpty))
                                      const Text("—", style: TextStyle(color: Colors.black26)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("ยกเลิก"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: previews.isEmpty ? null : () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                          child: const Text("ยืนยัน", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Alert dialog ทั่วไป (แทน SnackBar)
  Future<void> _showAlert(String message, {String title = "แจ้งเตือน"}) async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ตกลง")),
        ],
      ),
    );
  }

  // ---------- แปลง restaurantImg เป็นลิสต์รูป ----------
  List<String> _imageUrls() {
    final raw = widget.activity.restaurant?.restaurantImg?.trim();
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

  // ---------- Header Image: Carousel ----------
  Widget _headerImage() {
    final images = _imageUrls();

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          children: [
            if (images.isEmpty)
              _noImageBanner()
            else
              PageView.builder(
                controller: _imgCtrl,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _imgPage = i),
                itemBuilder: (_, i) => Image.network(
                  images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => _noImageBanner(),
                ),
              ),
            if (images.length > 1)
              Positioned(
                bottom: 10,
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
    );
  }

  Widget _noImageBanner() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront, size: 64, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text('ไม่มีรูปภาพร้าน', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("เชิญเพื่อน", style: TextStyle(color: Colors.black)),
        actions: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: _getCurrentUserImage(),
            child: _getCurrentUserImage() == null
                ? const Icon(Icons.person, size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // รูปหัวกิจกรรม (Carousel)
          _headerImage(),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ช่องกรอกอีเมล (ล็อกเฉพาะช่อง เมื่อโหมดเป็น phone)
                  Container(
                    decoration: _boxDeco(),
                    child: TextField(
                      controller: _emailController,
                      enabled: _emailEnabled,
                      onChanged: (v) {
                        final t = v.trim();
                        if (t.isNotEmpty) {
                          _switchMode(InviteMode.email);
                        } else if (t.isEmpty && _phoneController.text.trim().isNotEmpty) {
                          _switchMode(InviteMode.phone);
                        } else if (t.isEmpty && _phoneController.text.trim().isEmpty) {
                          _switchMode(InviteMode.none);
                        }
                      },
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        LengthLimitingTextInputFormatter(50),
                      ],
                      decoration: InputDecoration(
                        hintText: "อีเมลเพื่อน (ตัวเลือก)",
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        suffixIcon: _mode == InviteMode.phone
                            ? const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(Icons.lock, size: 18, color: Colors.grey),
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ช่องกรอกเบอร์ (ล็อกเฉพาะช่อง เมื่อโหมดเป็น email)
                  Container(
                    decoration: _boxDeco(),
                    child: TextField(
                      controller: _phoneController,
                      enabled: _phoneEnabled,
                      onChanged: (v) {
                        final t = v.trim();
                        if (t.isNotEmpty) {
                          _switchMode(InviteMode.phone);
                        } else if (t.isEmpty && _emailController.text.trim().isNotEmpty) {
                          _switchMode(InviteMode.email);
                        } else if (t.isEmpty && _emailController.text.trim().isEmpty) {
                          _switchMode(InviteMode.none);
                        }
                      },
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        hintText: "เบอร์โทรเพื่อน (ตัวเลือก)",
                        prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        suffixIcon: _mode == InviteMode.email
                            ? const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(Icons.lock, size: 18, color: Colors.grey),
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ส่วนหัวรายการประวัติ
                  Row(
                    children: [
                      const Text(
                        "ประวัติการเชิญ",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      if (_isLoadingHistory)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // รายการประวัติ (ไม่ล็อก checkbox — เลือกได้เสมอถ้า status ยังไม่ได้เชิญ)
                  Expanded(
                    child: _isLoadingHistory
                        ? const Center(child: CircularProgressIndicator())
                        : _inviteHistory.isEmpty
                            ? const Center(
                                child: Text(
                                  "ยังไม่มีประวัติการเชิญ",
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _inviteHistory.length,
                                itemBuilder: (context, index) {
                                  final history = _inviteHistory[index];
                                  final isSelected =
                                      _selectedEmails.contains(history.member.email);
                                  final canSelect = history.status == "ยังไม่ได้เชิญ";

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      leading: CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.grey.shade300,
                                        backgroundImage: history.member.profileImage != null &&
                                                history.member.profileImage!.isNotEmpty
                                            ? NetworkImage(baseURL + history.member.profileImage!)
                                            : null,
                                        child: history.member.profileImage == null ||
                                                history.member.profileImage!.isEmpty
                                            ? const Icon(Icons.person, color: Colors.white)
                                            : null,
                                      ),
                                      title: Text(
                                        "${history.member.firstName ?? ''} ${history.member.lastName ?? ''}".trim(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            history.member.email ?? '',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(history.status)
                                                      .withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  history.status,
                                                  style: TextStyle(
                                                    color: _getStatusColor(history.status),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              if (history.activityName != null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  "จาก: ${history.activityName!}",
                                                  style: TextStyle(
                                                    color: Colors.grey.shade500,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: canSelect
                                          ? Checkbox(
                                              value: isSelected,
                                              onChanged: (bool? value) {
                                                setState(() {
                                                  if (value == true) {
                                                    final email = history.member.email ?? '';
                                                    if (email.isNotEmpty) {
                                                      _selectedEmails.add(email);
                                                    }
                                                    // ไม่เปลี่ยนโหมด เพื่อให้ยัง "กรอกเบอร์" ได้อยู่
                                                  } else {
                                                    _selectedEmails.remove(history.member.email);
                                                  }
                                                });
                                              },
                                              activeColor: Colors.cyan,
                                            )
                                          : Icon(
                                              _getStatusIcon(history.status),
                                              color: _getStatusColor(history.status),
                                              size: 20,
                                            ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),

          // ปุ่มเชิญ
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendInvites,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "เชิญเข้าร่วมกิจกรรม",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ helpers UI ============
  BoxDecoration _boxDeco() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(25),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "เข้าร่วมแล้ว":
        return Colors.green;
      case "เชิญแล้ว":
        return Colors.orange;
      case "ยังไม่ได้เชิญ":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case "เข้าร่วมแล้ว":
        return Icons.check_circle;
      case "เชิญแล้ว":
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  ImageProvider? _getCurrentUserImage() {
    final user = UserLog().member;
    if (user?.profileImage != null && user!.profileImage!.isNotEmpty) {
      return NetworkImage(baseURL + user.profileImage!);
    }
    return null;
  }
}

// ===== Model สำหรับเก็บประวัติการเชิญ =====
class InviteHistory {
  final Member member;
  final DateTime inviteDate;
  final String status;
  final String? activityName;

  InviteHistory({
    required this.member,
    required this.inviteDate,
    required this.status,
    this.activityName,
  });
}

// ===== ใช้สำหรับ Preview ใน Dialog =====
class _InvitePreview {
  final String? fullName;
  final String? imageUrl;
  final String? email;
  final String? phone;

  _InvitePreview({this.fullName, this.imageUrl, this.email, this.phone});
}

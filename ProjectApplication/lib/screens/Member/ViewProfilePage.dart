import 'package:flutter/material.dart';
import 'package:newproject/boxs/userlog.dart';
import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/screens/Member/EditProfilePage.dart';
import 'package:newproject/model/Member.dart';

class ViewProfilePage extends StatefulWidget {
  const ViewProfilePage({super.key});

  @override
  State<ViewProfilePage> createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  Member? member;

  @override
  void initState() {
    super.initState();
    member = UserLog().member;
  }

  @override
  Widget build(BuildContext context) {
    if (member == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("ข้อมูลผู้ใช้"),
          backgroundColor: Colors.cyan,
        ),
        body: const Center(child: Text("กรุณาเข้าสู่ระบบ")),
      );
    }

    final String? avatarUrl = (member!.profileImage != null && member!.profileImage!.isNotEmpty)
        ? (baseURL + member!.profileImage!)
        : null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("ข้อมูลผู้ใช้"),
        backgroundColor: Colors.cyan,
        actions: [
          IconButton(
            tooltip: 'แก้ไขโปรไฟล์',
            icon: const Icon(Icons.edit),
            onPressed: _editProfile,
          ),
          IconButton(
            tooltip: 'ออกจากระบบ',
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---------- Header สวย ๆ ----------
          _HeaderCard(
            avatarUrl: avatarUrl,
            name: "${member!.firstName ?? '-'} ${member!.lastName ?? ''}".trim(),
            email: member!.email ?? '-',
            onEdit: _editProfile,
            onLogout: _confirmLogout,
          ),

          const SizedBox(height: 12),

          // ---------- รายละเอียด ----------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _infoTile(
                  icon: Icons.person,
                  title: 'ชื่อ',
                  value: member!.firstName ?? '-',
                ),
                _infoTile(
                  icon: Icons.person_outline,
                  title: 'นามสกุล',
                  value: member!.lastName ?? '-',
                ),
                _infoTile(
                  icon: Icons.transgender,
                  title: 'เพศ',
                  value: member!.gender ?? '-',
                ),
                _infoTile(
                  icon: Icons.cake,
                  title: 'วันเกิด',
                  value: member!.birthDate ?? '-',
                ),
                _infoTile(
                  icon: Icons.email,
                  title: 'อีเมล',
                  value: member!.email ?? '-',
                ),
                _infoTile(
                  icon: Icons.phone,
                  title: 'เบอร์โทร',
                  value: member!.phoneNumber ?? '-',
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== Widgets =====
  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.cyan.withOpacity(0.12),
          child: Icon(icon, color: Colors.cyan),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(value, style: const TextStyle(color: Colors.black87)),
      ),
    );
  }

  // ===== Actions =====
  Future<void> _editProfile() async {
    final updatedMember = await Navigator.push<Member>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (updatedMember != null && mounted) {
      setState(() {
        member = updatedMember;
        UserLog().member = updatedMember; // sync กลับไปที่ UserLog
      });
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ออกจากระบบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      // เคลียร์สถานะผู้ใช้
      UserLog().member = null;
      // ถ้าแอพมี route '/login' ให้เด้งกลับหน้า Login
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}

// ===== Header Card =====
class _HeaderCard extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String email;
  final VoidCallback onEdit;
  final VoidCallback onLogout;

  const _HeaderCard({
    required this.avatarUrl,
    required this.name,
    required this.email,
    required this.onEdit,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: (avatarUrl != null) ? NetworkImage(avatarUrl!) : null,
                  child: (avatarUrl == null)
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
              ),
              // ปุ่มแก้ไขเล็ก ๆ ซ้อนมุม
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onEdit,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(6.0),
                    child: Icon(Icons.edit, size: 18, color: Colors.cyan),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name.isEmpty ? '-' : name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email.isEmpty ? '-' : email,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.settings),
                  label: const Text('แก้ไขโปรไฟล์'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.cyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('ออกจากระบบ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

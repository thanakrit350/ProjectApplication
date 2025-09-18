// LoginMemberPage.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:newproject/boxs/userlog.dart';
import 'package:newproject/controller/MemberController.dart';
import 'package:newproject/model/Member.dart';
import 'package:newproject/screens/Home/home.dart';
import 'package:newproject/screens/Member/register.dart';

class LoginMemberPage extends StatefulWidget {
  const LoginMemberPage({super.key});
  @override
  State<LoginMemberPage> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginMemberPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  /// ใช้ควบคุมว่าให้ฟอร์มเริ่ม validate หรือยัง
  /// จะสลับเป็น true ตอนกดปุ่ม "ลงชื่อเข้าใช้"
  bool _submitted = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ---------------- VALIDATORS ----------------
  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกอีเมล';
    if (s.contains(' ')) return 'อีเมลต้องไม่มีช่องว่าง';
    if (s.length < 5 || s.length > 50) return 'อีเมลต้องยาว 5–50 ตัวอักษร';
    // อนุญาต a-z A-Z 0-9 และ . _ % + - ก่อนเครื่องหมาย @ และโดเมนปกติ
    final ok = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$').hasMatch(s);
    if (!ok) return 'รูปแบบอีเมลไม่ถูกต้อง';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return 'กรุณากรอกรหัสผ่าน';
    if (s.contains(' ')) return 'รหัสผ่านต้องไม่มีช่องว่าง';
    if (s.length < 8 || s.length > 16) return 'รหัสผ่านต้องยาว 8–16 ตัวอักษร';
    // เงื่อนไข: อังกฤษ/ตัวเลขเท่านั้น
    final ok = RegExp(r'^[A-Za-z0-9]+$').hasMatch(s);
    if (!ok) return 'ใช้ได้เฉพาะตัวอักษรอังกฤษหรือตัวเลขเท่านั้น';
    return null;
  }

  // ---------------- ACTIONS ----------------
  Future<void> _handleLogin() async {
    // เปิดโหมด validate เมื่อผู้ใช้กดปุ่ม
    setState(() => _submitted = true);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final result = await MemberController()
          .loginMember(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (!mounted) return;

      if (result['status'] == true) {
        final Member member = result['member'];
        UserLog().member = member;

        // แจ้งสำเร็จด้วย AlertDialog
        await _showAlert(result['message'] ?? 'เข้าสู่ระบบสำเร็จ', title: 'สำเร็จ');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreens()),
        );
      } else {
        // แจ้งล้มเหลวด้วย AlertDialog
        await _showAlert(result['message'] ?? 'เข้าสู่ระบบไม่สำเร็จ', title: 'เกิดข้อผิดพลาด');
      }
    } catch (e) {
      if (!mounted) return;
      await _showAlert('ไม่สามารถเข้าสู่ระบบได้:\n$e', title: 'เกิดข้อผิดพลาด');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toRegister() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreens()));
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Form(
            key: _formKey,
            // แสดง error ใต้ช่องเมื่อกดปุ่มแล้วเท่านั้น
            autovalidateMode: _submitted
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', width: 80, height: 80),
                const SizedBox(height: 20),
                const Text('Login', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('ลงชื่อเข้าใช้เพื่อดำเนินการต่อ', style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 30),

                Align(alignment: Alignment.centerLeft, child: _label('Email')),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),  // ห้ามช่องว่าง
                    LengthLimitingTextInputFormatter(50),
                  ],
                  decoration: _inputDeco('อีเมล'),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),

                Align(alignment: Alignment.centerLeft, child: _label('Password')),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: !_isPasswordVisible,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),  // ห้ามช่องว่าง
                    LengthLimitingTextInputFormatter(16),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), // ตัวอักษร/ตัวเลขเท่านั้น
                  ],
                  decoration: _inputDeco('รหัสผ่าน').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('ลงชื่อเข้าใช้', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(onPressed: _toRegister, child: const Text('สมัครสมาชิก', style: TextStyle(fontSize: 16))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String s) => Text(s, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500));

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Future<void> _showAlert(String message, {String title = 'แจ้งเตือน'}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ตกลง'))],
      ),
    );
  }
}

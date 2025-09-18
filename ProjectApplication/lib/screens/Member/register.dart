// RegisterScreens.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:newproject/controller/MemberController.dart';

class RegisterScreens extends StatefulWidget {
  const RegisterScreens({super.key});
  @override
  State<RegisterScreens> createState() => _RegisterScreensState();
}

class _RegisterScreensState extends State<RegisterScreens> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final MemberController memberController = MemberController();

  String? _selectedGender;
  bool _acceptTerms = false;

  // ---------- VALIDATORS ----------
  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอก';
    if (s.contains(' ')) return 'ห้ามมีช่องว่าง';
    if (s.length < 3 || s.length > 20) return 'ต้องมีความยาว 3–20 ตัวอักษร';
    final ok = RegExp(r'^[A-Za-zก-ฮะ-์]+$').hasMatch(s);
    if (!ok) return 'ใช้ได้เฉพาะตัวอักษรไทยหรืออังกฤษเท่านั้น';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกอีเมล';
    if (s.contains(' ')) return 'อีเมลต้องไม่มีช่องว่าง';
    if (s.length < 5 || s.length > 50) return 'อีเมลต้องยาว 5–50 ตัวอักษร';
    final ok = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$').hasMatch(s);
    if (!ok) return 'รูปแบบอีเมลไม่ถูกต้อง';
    return null;
  }

  String? _validatePhone(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
  // ต้องเป็นตัวเลข 10 หลัก
  if (!RegExp(r'^\d{10}$').hasMatch(s)) return 'กรุณากรอกเป็นตัวเลข 10 หลัก';
  // ต้องขึ้นต้น 06 หรือ 08 หรือ 09
  if (!RegExp(r'^(06|08|09)').hasMatch(s)) return 'ต้องขึ้นต้นด้วย 06, 08 หรือ 09';
  return null;
}


  String? _validatePassword(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return 'กรุณากรอกรหัสผ่าน';
    if (s.contains(' ')) return 'รหัสผ่านต้องไม่มีช่องว่าง';
    if (s.length < 8 || s.length > 16) return 'รหัสผ่านต้องยาว 8–16 ตัวอักษร';
    final ok = RegExp(r'^[A-Za-z0-9!#_.]+$').hasMatch(s);
    if (!ok) return 'ใช้ได้เฉพาะตัวอักษร/ตัวเลข/สัญลักษณ์ ! # _ .';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (v == null || v.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
    if (v != _passwordController.text) return 'รหัสผ่านไม่ตรงกัน';
    return null;
  }

  /// ✅ อัปเดต: วันเกิดต้องอายุ ≥16 ปี และถ้า >80 ปี เตือนว่า "อายุควรเป็นจริง"
  String? _validateBirthDate(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณาเลือกวันเกิด';
    DateTime d;
    try {
      d = DateFormat('dd/MM/yyyy').parseStrict(s);
    } catch (_) {
      return 'รูปแบบวันเกิดไม่ถูกต้อง';
    }
    final now = DateTime.now();
    // คำนวณอายุแบบเทียบวันเกิดในปีนี้
    int age = now.year - d.year;
    final hasHadBirthdayThisYear =
        (now.month > d.month) || (now.month == d.month && now.day >= d.day);
    if (!hasHadBirthdayThisYear) age -= 1;

    if (age < 16) return 'ต้องมีอายุอย่างน้อย 16 ปี';
    if (age > 80) return 'อายุควรเป็นจริง';
    return null;
  }

  // ---------- Birthdate Bottom Sheet ----------
  DateTime _parseBirthOr(DateTime fallback) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(_birthDateController.text);
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _openBirthDateSheet() async {
    final now = DateTime.now();
    final defaultInit = DateTime(now.year - 20, now.month, now.day);
    DateTime temp = _parseBirthOr(defaultInit);

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
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _birthDateController.clear();
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          child: const Text('ล้างค่า'),
                        ),
                        const Spacer(),
                        const Text('เลือกวันเกิด', style: TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            _birthDateController.text = DateFormat('dd/MM/yyyy').format(temp);
                            Navigator.pop(ctx);
                            setState(() {});
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
                        initialDateTime: temp,
                        maximumDate: now,            // อนุญาตเลือกถึงวันนี้
                        minimumDate: DateTime(1900), // ยังอนุญาต >80 ปีได้ แต่จะเตือนตอน validate
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),
                const Text('สร้างบัญชี', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                _nameField(),
                _lastNameField(),
                _emailField(),
                _genderField(),
                _birthDateField(),
                _phoneField(),
                _passwordField(),
                _confirmPasswordField(),

                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _acceptTerms,
                  onChanged: (val) => setState(() => _acceptTerms = val ?? false),
                  title: const Text('ยอมรับเงื่อนไขการบริการและนโยบายความเป็นส่วนตัว'),
                ),

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _register,
                    child: const Text('สมัครสมาชิก', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('เข้าสู่ระบบ', style: TextStyle(color: Colors.black87, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Fields ----------
  Widget _nameField() => _inputWrapper(
        controller: _nameController,
        hint: 'ชื่อจริง',
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
          LengthLimitingTextInputFormatter(20),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zก-ฮะ-์]')),
        ],
        validator: _validateName,
      );

  Widget _lastNameField() => _inputWrapper(
        controller: _lastnameController,
        hint: 'นามสกุล',
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
          LengthLimitingTextInputFormatter(20),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zก-ฮะ-์]')),
        ],
        validator: _validateName,
      );

  Widget _emailField() => _inputWrapper(
        controller: _emailController,
        hint: 'อีเมล',
        keyboardType: TextInputType.emailAddress,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
          LengthLimitingTextInputFormatter(50),
        ],
        validator: _validateEmail,
      );

  Widget _birthDateField() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: _birthDateController,
          readOnly: true,
          onTap: _openBirthDateSheet,
          decoration: InputDecoration(
            hintText: 'วันเกิด',
            filled: true,
            fillColor: Colors.grey.shade100,
            suffixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: _validateBirthDate, // ✅ ใช้ตัวตรวจใหม่ที่เช็กอายุ 16–80 ปี
        ),
      );

  Widget _genderField() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          value: _selectedGender,
          items: const ['ชาย', 'หญิง', 'อื่น ๆ']
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (value) => setState(() => _selectedGender = value),
          decoration: InputDecoration(
            hintText: 'เลือกเพศ',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) => v == null ? 'กรุณาเลือกเพศ' : null,
        ),
      );

  Widget _phoneField() => _inputWrapper(
        controller: _phoneController,
        hint: 'เบอร์โทร',
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        validator: _validatePhone,
      );

  Widget _passwordField() => _inputWrapper(
        controller: _passwordController,
        hint: 'รหัสผ่าน',
        obscure: true,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
          LengthLimitingTextInputFormatter(16),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9!#_.]')),
        ],
        validator: _validatePassword,
      );

  Widget _confirmPasswordField() => _inputWrapper(
        controller: _confirmPasswordController,
        hint: 'ยืนยันรหัสผ่าน',
        obscure: true,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
          LengthLimitingTextInputFormatter(16),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9!#_.]')),
        ],
        validator: _validateConfirmPassword,
      );

  Widget _inputWrapper({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: validator,
      ),
    );
  }

  // ---------- Register ----------
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      await _showAlert('กรุณายอมรับเงื่อนไขการบริการและนโยบายความเป็นส่วนตัว', title: 'แจ้งเตือน');
      return;
    }

    try {
      final parsed = DateFormat('dd/MM/yyyy').parseStrict(_birthDateController.text);
      final birthIso = DateFormat('yyyy-MM-dd').format(parsed);

      final result = await memberController.addMember(
        firstName: _nameController.text.trim(),
        lastName: _lastnameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phoneNumber: _phoneController.text.trim(),
        birthDate: birthIso,
        gender: _selectedGender ?? '',
        profileImage: '',
      );

      if (result != null && mounted) {
        await _showAlert('สมัครสมาชิกสำเร็จ', title: 'สำเร็จ');
        Navigator.pop(context);
      } else {
        _showAlert('สมัครสมาชิกไม่สำเร็จ', title: 'เกิดข้อผิดพลาด');
      }
    } catch (e) {
      _showAlert('ไม่สามารถสมัครสมาชิกได้:\n$e', title: 'เกิดข้อผิดพลาด');
    }
  }

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

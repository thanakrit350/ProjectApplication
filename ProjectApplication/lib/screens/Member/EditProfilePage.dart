import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:newproject/boxs/userlog.dart';
import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/controller/MemberController.dart';
import 'package:newproject/model/Member.dart';
import 'package:flutter/services.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _memberController = MemberController();

  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _birthDateCtrl;

  Member? _currentMember;
  File? _imageFile;
  bool _saving = false;

  String _gender = '';
  bool _genderError = false;

  @override
  void initState() {
    super.initState();
    _currentMember = UserLog().member;

    _firstNameCtrl = TextEditingController(text: _currentMember?.firstName ?? '');
    _lastNameCtrl  = TextEditingController(text: _currentMember?.lastName ?? '');

    final birthStr = _currentMember?.birthDate ?? '';
    String birthDisplay = '';
    if (birthStr.isNotEmpty) {
      try {
        final d = DateTime.parse(birthStr);
        birthDisplay = DateFormat('dd/MM/yyyy').format(d);
      } catch (_) {}
    }
    _birthDateCtrl = TextEditingController(text: birthDisplay);
    _gender = _currentMember?.gender ?? '';
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  // ---------- alert helper ----------
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

  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอก';
    if (s.contains(' ')) return 'ห้ามมีช่องว่าง';
    if (s.length < 3 || s.length > 20) return 'ต้องมีความยาว 3–20 ตัวอักษร';
    if (!RegExp(r'^[A-Za-zก-ฮะ-์]+$').hasMatch(s)) return 'ใช้ได้เฉพาะตัวอักษรไทยหรืออังกฤษเท่านั้น';
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
    int age = now.year - d.year;
    final hadBirthdayThisYear =
        (now.month > d.month) || (now.month == d.month && now.day >= d.day);
    if (!hadBirthdayThisYear) age -= 1;

    if (age < 16) return 'ต้องมีอายุอย่างน้อย 16 ปี';
    if (age > 80) return 'อายุควรเป็นจริง';
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  void _removeImage() => setState(() => _imageFile = null);

  /// คืนค่า ImageProvider? แบบ "อาจเป็น null" (ไฟล์/เน็ต)
  ImageProvider? _avatarProviderOrNull() {
    if (_imageFile != null) return FileImage(_imageFile!);
    final path = _currentMember?.profileImage ?? '';
    if (path.isNotEmpty) return NetworkImage(baseURL + path);
    return null; // ให้ CircleAvatar แสดงไอคอนแทน
  }

  DateTime _parseBirthOr(DateTime fallback) {
    try { return DateFormat('dd/MM/yyyy').parseStrict(_birthDateCtrl.text); }
    catch (_) { return fallback; }
  }

  Future<void> _openBirthSheet() async {
    final now = DateTime.now();
    DateTime temp = _parseBirthOr(DateTime(now.year - 20, now.month, now.day));
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: StatefulBuilder(builder: (ctx, setLocal) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
                ),
                Row(children: [
                  TextButton(
                    onPressed: () { _birthDateCtrl.clear(); Navigator.pop(ctx); setState(() {}); },
                    child: const Text('ล้างค่า'),
                  ),
                  const Spacer(),
                  const Text('เลือกวันเกิด', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      _birthDateCtrl.text = DateFormat('dd/MM/yyyy').format(temp);
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                    child: const Text('เสร็จ'),
                  ),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    maximumDate: now,
                    minimumDate: DateTime(1900),
                    initialDateTime: temp,
                    onDateTimeChanged: (d) => setLocal(() => temp = d),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _toServerBirth(String display) {
    if (display.isEmpty) return '';
    try {
      final d = DateFormat('dd/MM/yyyy').parseStrict(display);
      return DateFormat('yyyy-MM-dd').format(d);
    } catch (_) {
      return '';
    }
  }

  Future<void> _saveProfile() async {
    if (_currentMember == null) return;

    setState(() => _genderError = _gender.isEmpty);
    if (!_formKey.currentState!.validate() || _genderError) return;

    setState(() => _saving = true);
    try {
      final result = await _memberController.editMember(
        memberId: _currentMember!.memberId!,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        birthDate: _toServerBirth(_birthDateCtrl.text.trim()),
        gender: _gender,
        email: _currentMember!.email ?? '',
        phoneNumber: _currentMember!.phoneNumber ?? '',
        profileImageFile: _imageFile,
      );

      if (!mounted) return;
      if (result != null) {
        UserLog().member = result;
        // ✅ ใช้ AlertDialog แทน SnackBar
        await _showAlert('บันทึกข้อมูลเรียบร้อย');
        Navigator.pop(context, result);
      } else {
        // ถ้าต้องการให้เป็น Alert ก็ทำได้: await _showAlert('เกิดข้อผิดพลาดในการบันทึก');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarProviderOrNull();

    return Stack(children: [
      Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('แก้ไขโปรไฟล์'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.6,
          actions: [
            TextButton(
              onPressed: _saving ? null : _saveProfile,
              child: const Text('บันทึก', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              // ---------- Avatar (ไม่พึ่ง asset) ----------
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // วงขาวเป็นกรอบ
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: avatar, // อาจเป็น null ได้
                        child: avatar == null
                            ? const Icon(Icons.person, size: 56, color: Colors.white)
                            : null,
                      ),
                    ),
                    // ปุ่มลบรูป (เฉพาะกรณีเลือกรูปใหม่)
                    Positioned(
                      top: -4, right: -4,
                      child: Material(
                        color: Colors.black54, shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _imageFile != null ? _removeImage : null,
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ),
                    // ปุ่มกล้อง
                    Positioned(
                      bottom: -2, right: -2,
                      child: Material(
                        color: Colors.cyan, shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _pickImage,
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              _label('ชื่อ'),
              _textField(
                controller: _firstNameCtrl,
                hint: 'กรอกชื่อของคุณ',
                validator: _validateName,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(20),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zก-ฮะ-์]')),
                ],
              ),

              _label('นามสกุล'),
              _textField(
                controller: _lastNameCtrl,
                hint: 'กรอกนามสกุลของคุณ',
                validator: _validateName,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(20),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zก-ฮะ-์]')),
                ],
              ),

              _label('วันเกิด'),
              _textField(
                controller: _birthDateCtrl,
                hint: 'เลือกวันเกิด (dd/MM/yyyy)',
                readOnly: true,
                onTap: _openBirthSheet,
                validator: _validateBirthDate, // ✅ เช็กอายุ 16–80 ปี
                suffix: const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
              ),

              _label('เพศ'),
              _genderChips(),
              if (_genderError)
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 6),
                  child: Text('กรุณาเลือกเพศ', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
      if (_saving) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
    ]);
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 14),
        child: Text(s, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _genderChips() {
    const genders = ['ชาย', 'หญิง', 'อื่น ๆ'];
    return Wrap(
      spacing: 10,
      children: genders.map((g) {
        final selected = _gender == g;
        return ChoiceChip(
          label: Text(g),
          selected: selected,
          onSelected: (_) { setState(() { _gender = g; _genderError = false; }); },
          selectedColor: Colors.cyan,
          labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
          backgroundColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      }).toList(),
    );
  }
}

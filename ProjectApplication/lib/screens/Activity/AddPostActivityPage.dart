import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import 'package:newproject/boxs/userlog.dart';
import 'package:newproject/controller/ActivityController.dart';
import 'package:newproject/controller/RestaurantTypeController.dart';
import 'package:newproject/model/Restaurant.dart';
import 'package:newproject/model/Activity.dart';
import 'package:newproject/model/ActivityMember.dart';
import 'package:newproject/model/Member.dart';
import 'package:newproject/model/RestaurantType.dart';
import 'package:newproject/screens/Restaurant/AddBasicRestaurantPage.dart';

class AddPostActivityPage extends StatefulWidget {
  final Restaurant? restaurant; // ถ้ามาจากหน้าร้าน
  final Activity? editActivity;

  const AddPostActivityPage({
    Key? key,
    this.restaurant,
    this.editActivity,
  }) : super(key: key);

  @override
  State<AddPostActivityPage> createState() => _AddPostActivityPageState();
}

class _AddPostActivityPageState extends State<AddPostActivityPage> {
  final _formKey = GlobalKey<FormState>();
  final partyNameController = TextEditingController();
  final dateTimeController = TextEditingController();
  final additionalController = TextEditingController();

  List<Map<String, dynamic>> foodTypes = [];
  int? selectedFoodTypeId;

  double? selectedLat;
  double? selectedLon;
  int? selectedRestaurantId;
  String? selectedRestaurantName;

  // ล็อกเมื่อ "มีร้าน" (แม้ร้านไม่มีประเภท)
  bool _lockTypeFromRestaurant = false;

  bool get isEditMode => widget.editActivity != null;

  // ✅ ใช้ตรวจว่ามีการระบุสถานที่หรือไม่
  bool get _hasPlace => (selectedLat != null && selectedLon != null);


  final DateFormat _isoFmt = DateFormat("yyyy-MM-dd'T'HH:mm");
  final _prettyFmt = DateFormat('EEE d MMM y เวลา HH:mm', 'th_TH');


  @override
  void initState() {
    super.initState();
    _loadFoodTypes();
    _initializeData();
  }

  // ---------- Time helpers ----------
  /// ปัดเวลาปัจจุบันลงเป็น “นาทีถ้วน”
  DateTime _nowFloorMinute() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  /// เวลาขั้นต่ำที่เลือกได้ = ตอนนี้ + 3 ชม. และ "ปัดขึ้น" ให้เข้ากับ step 5 นาทีของ UI
  DateTime _minAllowableInvite() {
    var dt = _nowFloorMinute().add(const Duration(hours: 3));
    final mod = dt.minute % 5;
    if (mod != 0) dt = dt.add(Duration(minutes: 5 - mod));
    // ตัดวินาที/มิลลิวินาทีให้เป็นนาทีถ้วน
    return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
  }

  // ---------- Data / Types ----------
  String _foodTypeNameById(int? id) {
    if (id == null) return '';
    final m = foodTypes.firstWhere((e) => e['id'] == id, orElse: () => {});
    if (m.isEmpty) return '';
    return (m['name'] ?? '').toString();
  }

  void _initializeData() {
    if (isEditMode) {
      final activity = widget.editActivity!;
      partyNameController.text = activity.activityName ?? '';
      additionalController.text = activity.descriptionActivity ?? '';
      if (activity.inviteDate != null) {
        dateTimeController.text = _isoFmt.format(activity.inviteDate!);
      }

      selectedFoodTypeId = activity.restaurantType?.restaurantTypeId;

      if (activity.restaurant != null) {
        selectedLat = double.tryParse(activity.restaurant!.latitude ?? '');
        selectedLon = double.tryParse(activity.restaurant!.longitude ?? '');
        selectedRestaurantId = activity.restaurant!.restaurantId;
        selectedRestaurantName = activity.restaurant!.restaurantName;

        final rtId = activity.restaurant!.restaurantType?.restaurantTypeId;
        if (rtId != null) selectedFoodTypeId = rtId;

        _lockTypeFromRestaurant = (selectedRestaurantId != null);
      } else {
        _lockTypeFromRestaurant = false;
      }
    } else if (widget.restaurant != null) {
      selectedLat = double.tryParse(widget.restaurant!.latitude ?? '');
      selectedLon = double.tryParse(widget.restaurant!.longitude ?? '');
      selectedRestaurantId = widget.restaurant!.restaurantId;
      selectedRestaurantName = widget.restaurant!.restaurantName;

      final rtId = widget.restaurant!.restaurantType?.restaurantTypeId;
      selectedFoodTypeId = rtId;

      _lockTypeFromRestaurant = (selectedRestaurantId != null);
    } else {
      _lockTypeFromRestaurant = false;
    }
  }

  Future<void> _loadFoodTypes() async {
    try {
      // ใช้เฉพาะประเภทที่มีร้านจริง ถ้า endpoint ยังไม่มี จะ fallback ไปดึงทั้งหมด
      var types = await RestaurantTypeController().getNonEmptyTypesWithId();
      if (types.isEmpty) {
        types = await RestaurantTypeController().getAllTypesWithId();
      }
      if (!mounted) return;
      setState(() => foodTypes = types);

      // ถ้า id ที่เลือกไว้ไม่อยู่ในลิสต์ใหม่ ให้เคลียร์
      if (selectedFoodTypeId != null &&
          !foodTypes.any((e) => e['id'] == selectedFoodTypeId)) {
        setState(() => selectedFoodTypeId = null);
      }
    } catch (e) {
      debugPrint('load food types failed: $e');
    }
  }

  // ---------- VALIDATORS ----------
  String? _validateActivityName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกชื่อปาร์ตี้';
    if (s.length < 3 || s.length > 50) return 'ความยาวต้อง 3–50 ตัวอักษร';
    final reg = RegExp(r'^[A-Za-z\u0E00-\u0E7F ]+$');
    if (!reg.hasMatch(s)) return 'กรอกได้เฉพาะตัวอักษรไทย/อังกฤษ และช่องว่าง';
    return null;
  }

  String? _validateDescription(String? v) {
    final s = (v ?? '');
    if (s.trim().isEmpty) return null;
    if (s.length < 2 || s.length > 250) return 'ความยาวต้อง 2–250 ตัวอักษร';
    final reg = RegExp(r'^[A-Za-z0-9\u0E00-\u0E7F !#_.]+$');
    if (!reg.hasMatch(s)) return 'อนุญาตเฉพาะ ไทย/อังกฤษ/ตัวเลข/ช่องว่าง และ ! # _ .';
    return null;
  }

  bool _validatePlaceConsistency() {
    final bothNull = (selectedLat == null && selectedLon == null);
    final bothHas = (selectedLat != null && selectedLon != null);
    return bothNull || bothHas;
  }

  // ---------- Date & Time ----------
  Future<void> _selectInviteDate() async {
    final minDT = _minAllowableInvite(); // ใช้ cutoff เดียวกับ validator
    DateTime initial = minDT;

    if (dateTimeController.text.isNotEmpty) {
      try {
        final parsed = DateTime.parse(dateTimeController.text);
        if (!parsed.isBefore(minDT)) initial = parsed;
      } catch (_) {}
    }

    final picked = await _showDateTimeSheet(
      context,
      initialDateTime: initial,
      minDateTime: minDT,
    );
    if (picked != null) {
      setState(() => dateTimeController.text = _isoFmt.format(picked));
    }
  }

  Future<DateTime?> _showDateTimeSheet(
    BuildContext context, {
    required DateTime initialDateTime,
    required DateTime minDateTime,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // เริ่มจากค่า initial (ปัด step 5 แล้ว)
        DateTime selected = initialDateTime;
        int hour = selected.hour;
        int minute = selected.minute; // ตรงกับ step 5 อยู่แล้ว

        final hourCtrl = TextEditingController(text: hour.toString().padLeft(2, '0'));

        void clampToMin() {
          if (selected.isBefore(minDateTime)) {
            selected = minDateTime;
            hour = selected.hour;
            minute = selected.minute;
            final padded = hour.toString().padLeft(2, '0');
            if (hourCtrl.text != padded) {
              hourCtrl.text = padded;
              hourCtrl.selection = TextSelection.collapsed(offset: padded.length);
            }
          }
        }

        String pretty(DateTime dt) => _prettyFmt.format(dt);
        final maxH = MediaQuery.of(ctx).size.height * 0.9;

        return SizedBox(
          height: maxH,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              void updateSelected(DateTime newDT) {
                selected = DateTime(newDT.year, newDT.month, newDT.day, hour, minute);
                clampToMin();
                setSheetState(() {});
              }

              void updateHM({int? h, int? m}) {
                hour = h ?? hour;
                minute = m ?? minute;
                selected = DateTime(selected.year, selected.month, selected.day, hour, minute);

                // บังคับไม่ให้ต่ำกว่า min
                clampToMin();

                // อัปเดตตัวเลขในช่องชั่วโมงให้ตรงกับค่าปัจจุบันเสมอ
                final padded = hour.toString().padLeft(2, '0');
                if (hourCtrl.text != padded) {
                  hourCtrl.text = padded;
                  hourCtrl.selection = TextSelection.collapsed(offset: padded.length);
                }

                setSheetState(() {});
              }

              List<Widget> quickChips() {
                final minDTLocal = minDateTime;

                final q1 = minDTLocal; // เท่ากับขั้นต่ำเป๊ะ
                // พรุ่งนี้ 18:00 (ถ้าต่ำกว่า min → ขยับไปวันถัดไป)
                final now = DateTime.now();
                final tomorrow = now.add(const Duration(days: 1));
                DateTime q2Base = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18, 0);
                final q2 = q2Base.isAfter(minDTLocal) ? q2Base : q2Base.add(const Duration(days: 1));

                // เสาร์นี้ 18:00 (ถ้าต่ำกว่า min → ขยับไปสัปดาห์หน้า)
                int weekday = now.weekday; // จันทร์=1 ... อาทิตย์=7
                int add = (6 - weekday); // เสาร์=6
                if (add <= 0) add += 7;
                DateTime q3Base = DateTime(now.year, now.month, now.day + add, 18, 0);
                final q3 = q3Base.isAfter(minDTLocal) ? q3Base : q3Base.add(const Duration(days: 7));

                final items = [
                  {'label': 'ขั้นต่ำ (+3ชม.)', 'dt': q1},
                  {'label': 'พรุ่งนี้ 18:00', 'dt': q2},
                  {'label': 'เสาร์นี้ 18:00', 'dt': q3},
                ];

                return items.map((e) {
                  final DateTime dt = e['dt'] as DateTime;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(e['label'] as String),
                      onPressed: () {
                        hour = dt.hour;
                        minute = dt.minute;
                        selected = dt;

                        // sync hour field
                        final padded = hour.toString().padLeft(2, '0');
                        if (hourCtrl.text != padded) {
                          hourCtrl.text = padded;
                          hourCtrl.selection = TextSelection.collapsed(offset: padded.length);
                        }

                        clampToMin();
                        setSheetState(() {});
                      },
                    ),
                  );
                }).toList();
              }

              Widget hourBox() {
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('ชั่วโมง', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'ลด',
                            onPressed: hour > 0 ? () => updateHM(h: hour - 1) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: hourCtrl,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                              onChanged: (txt) {
                                int val = int.tryParse(txt) ?? 0;
                                if (val > 23) val = 23;
                                updateHM(h: val);

                                // ยืนยันเลข 2 หลักเสมอ
                                final padded = val.toString().padLeft(2, '0');
                                if (hourCtrl.text != padded) {
                                  final sel = padded.length;
                                  hourCtrl.value = TextEditingValue(
                                    text: padded,
                                    selection: TextSelection.collapsed(offset: sel),
                                  );
                                }
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'เพิ่ม',
                            onPressed: hour < 23 ? () => updateHM(h: hour + 1) : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              Widget minuteBox() {
                final step = 5;
                final options = List.generate(60 ~/ step, (i) => i * step);
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('นาที', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: options.map((m) {
                          final sel = (m == minute);
                          return ChoiceChip(
                            label: Text(m.toString().padLeft(2, '0')),
                            selected: sel,
                            onSelected: (_) => updateHM(m: m),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }

              String _calendarKeyFor(DateTime d) =>
                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

              return SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text('เลือกวันและเวลา',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            child: const Text('ยกเลิก'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              pretty(selected),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                height: 1.2,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.pop(ctx, null),
                            icon: const Icon(Icons.clear),
                            label: const Text('ไม่เลือก'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        children: quickChips(),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        children: [
                          CalendarDatePicker(
                            key: ValueKey(_calendarKeyFor(DateUtils.dateOnly(selected))),
                            initialDate: selected,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            onDateChanged: (d) {
                              updateSelected(DateTime(d.year, d.month, d.day));
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                            child: Row(
                              children: [
                                Expanded(child: hourBox()),
                                const SizedBox(width: 12),
                                Expanded(child: minuteBox()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            if (selected.isBefore(minDateTime)) {
                              selected = minDateTime;
                            }
                            Navigator.pop(ctx, selected);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F80ED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('บันทึกวันและเวลา'),
                        ),
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

  // ---------- UI helpers ----------
  InputDecoration _inputDecoration(IconData icon) => InputDecoration(
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.cyan),
        ),
      );

  Widget _inputText(
    TextEditingController controller,
    String hint,
    IconData icon, {
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    int? maxLength,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: _inputDecoration(icon).copyWith(hintText: hint, counterText: ''),
      validator: validator,
    );
  }

  Widget _buildDateTimePicker() {
    String display = 'วันที่-เวลา (ต้องล่วงหน้าอย่างน้อย 3 ชม.)';
    if (dateTimeController.text.isNotEmpty) {
      try {
        display = _prettyFmt.format(DateTime.parse(dateTimeController.text));
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: TextEditingController(text: display),
        readOnly: true,
        onTap: _selectInviteDate,
        decoration: _inputDecoration(Icons.calendar_today).copyWith(
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dateTimeController.text.isNotEmpty)
                IconButton(
                  tooltip: 'ล้าง',
                  onPressed: () => setState(() => dateTimeController.clear()),
                  icon: const Icon(Icons.clear),
                ),
              const Icon(Icons.access_time),
              const SizedBox(width: 6),
            ],
          ),
        ),
        validator: (val) {
          final raw = dateTimeController.text;
          if (raw.isEmpty) return 'กรุณาเลือกวันนัดหมาย';

          DateTime dt;
          try {
            dt = DateTime.parse(raw);
          } catch (_) {
            return 'รูปแบบวัน-เวลาไม่ถูกต้อง';
          }

          // ใช้ cutoff เดียวกับ bottom sheet
          final minAllow = _minAllowableInvite();

          if (dt.isBefore(minAllow)) {
            final prettyMin = _prettyFmt.format(minAllow);
            return 'กรุณาเลือกเวลาไม่ก่อนกว่า $prettyMin';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildMapPreview() {
    final hasPos = (selectedLat != null && selectedLon != null);
    final center =
        hasPos ? LatLng(selectedLat!, selectedLon!) : const LatLng(18.7883, 98.9853);
    final zoom = hasPos ? 15.0 : 12.0;

    return SizedBox(
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          key: ValueKey('map-${selectedLat ?? 'x'}-${selectedLon ?? 'x'}'),
          options: MapOptions(
            center: center,
            zoom: zoom,
            interactiveFlags: InteractiveFlag.none,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.project',
            ),
            if (hasPos)
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

  // ---------- Place picker ----------
  Future<void> _pickPlace() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBasicRestaurantPage()),
    );

    if (!mounted) return;

    // กด Back → ไม่เปลี่ยนค่าเดิม
    if (result == null) return;

    // "ไม่ระบุสถานที่" → ล้างค่า
    if (result is Map && result['clear'] == true) {
      setState(() {
        selectedLat = null;
        selectedLon = null;
        selectedRestaurantId = null;
        selectedRestaurantName = null;
        selectedFoodTypeId = null;
        _lockTypeFromRestaurant = false;
      });
      return;
    }

    // มีผลลัพธ์ร้าน/พิกัด → อัปเดต
    setState(() {
      final restJson = result['restaurant'];
      selectedLat = (result['lat'] as num?)?.toDouble();
      selectedLon = (result['lon'] as num?)?.toDouble();
      selectedRestaurantId = restJson?['restaurantId'] as int?;
      selectedRestaurantName = restJson?['restaurantName'] as String?;

      int? typeId;
      final rt = restJson?['restaurantType'];
      if (rt is Map && rt['restaurantTypeId'] != null) {
        typeId = (rt['restaurantTypeId'] as num).toInt();
      } else if (restJson?['restaurantTypeId'] != null) {
        typeId = (restJson['restaurantTypeId'] as num).toInt();
      }
      selectedFoodTypeId = typeId;

      _lockTypeFromRestaurant = (selectedRestaurantId != null);
    });
  }

  // ---------- Submit ----------
  Future<void> _submitForm() async {
    final valid = _formKey.currentState!.validate();
    if (!valid) return;

    // ถ้าไม่มีสถานที่ → ต้องมีประเภท และห้ามเป็น "ไม่ระบุ"
    if (!_hasPlace) {
      final name = _foodTypeNameById(selectedFoodTypeId);
      if (selectedFoodTypeId == null || name.trim() == 'ไม่ระบุ') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกประเภทอาหารให้ชัดเจน (ห้ามเลือก "ไม่ระบุ")')),
        );
        return;
      }
    }

    if (!_validatePlaceConsistency()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกสถานที่ให้ถูกต้อง (ระบุ/ไม่ระบุเท่านั้น)')),
      );
      return;
    }

    if (!UserLog().isLoggedIn || UserLog().member == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนโพสต์')),
      );
      return;
    }

    final int memberId = UserLog().member!.memberId!;

    final activity = Activity(
      activityId: isEditMode ? widget.editActivity!.activityId : null,
      activityName: partyNameController.text.trim(),
      descriptionActivity:
          additionalController.text.trim().isEmpty ? null : additionalController.text.trim(),
      inviteDate: DateTime.parse(dateTimeController.text),
      postDate: isEditMode ? widget.editActivity!.postDate : DateTime.now(),
      statusPost: isEditMode ? widget.editActivity!.statusPost : 'กำลังดำเนินอยู่',
      isOwnerSelect: _hasPlace,

      restaurantType: (selectedFoodTypeId != null)
          ? RestaurantType(restaurantTypeId: selectedFoodTypeId!)
          : null,

      restaurant: (selectedRestaurantId != null)
          ? Restaurant(restaurantId: selectedRestaurantId)
          : null,

      activityMembers: isEditMode
          ? widget.editActivity!.activityMembers
          : [
              ActivityMember(
                joinDate: DateTime.now(),
                memberStatus: 'เจ้าของกิจกรรม',
                member: Member(memberId: memberId),
                selectRestaurant: null,
              ),
            ],
    );

    try {
      Activity? result;
      if (isEditMode) {
        result = await ActivityController()
            .updateActivity(widget.editActivity!.activityId!, activity);
      } else {
        result = await ActivityController().createActivity(activity);
      }

      if (!mounted) return;

      if (result != null) {
        Navigator.pop(context, result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditMode ? 'แก้ไขไม่สำเร็จ' : 'โพสต์ไม่สำเร็จ')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final boxColor = Colors.white;
    final lockedTypeName = _foodTypeNameById(selectedFoodTypeId);

    return Scaffold(
      appBar: AppBar(title: Text(isEditMode ? 'แก้ไขปาร์ตี้' : 'สร้างปาร์ตี้')),
      backgroundColor: const Color(0xFFF7F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _inputText(
                partyNameController,
                'ชื่อปาร์ตี้',
                Icons.edit,
                maxLength: 50,
                validator: _validateActivityName,
              ),
              const SizedBox(height: 12),

              _buildMapPreview(),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _pickPlace,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: TextEditingController(
                      text: _hasPlace
                          ? (selectedRestaurantName != null &&
                                  selectedRestaurantName!.trim().isNotEmpty
                              ? '${selectedRestaurantName!}  •  '
                                  'Lat: ${selectedLat!.toStringAsFixed(4)}, '
                                  'Lon: ${selectedLon!.toStringAsFixed(4)}'
                              : 'Lat: ${selectedLat!.toStringAsFixed(4)}, '
                                  'Lon: ${selectedLon!.toStringAsFixed(4)}')
                          : 'ไม่ระบุสถานที่',
                    ),
                    decoration:
                        _inputDecoration(Icons.location_on).copyWith(hintText: 'สถานที่'),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _buildDateTimePicker(),
              const SizedBox(height: 12),

              // ---------- ประเภทอาหาร ----------
              if (_lockTypeFromRestaurant)
                TextFormField(
                  readOnly: true,
                  decoration: _inputDecoration(Icons.restaurant_menu).copyWith(
                    labelText: 'ประเภทอาหาร (กำหนดจากร้าน)',
                    hintText: (lockedTypeName.isEmpty) ? 'ไม่ระบุ' : lockedTypeName,
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  value: selectedFoodTypeId,
                  hint: const Text('เลือกประเภทอาหาร'),
                  decoration: _inputDecoration(Icons.restaurant_menu),

                  // ถ้า "ไม่มีสถานที่" → ซ่อนตัวเลือกที่ชื่อ "ไม่ระบุ"
                  items: foodTypes
                      .where((t) => _hasPlace
                          ? true
                          : ((t['name'] ?? '').toString().trim() != 'ไม่ระบุ'))
                      .map((type) => DropdownMenuItem<int>(
                            value: type['id'],
                            child: Text(type['name']),
                          ))
                      .toList(),

                  onChanged: (val) => setState(() => selectedFoodTypeId = val),

                  // บังคับเลือกเมื่อ "ไม่มีสถานที่" + ห้าม "ไม่ระบุ"
                  validator: (val) {
                    if (_lockTypeFromRestaurant) return null;
                    if (!_hasPlace) {
                      if (val == null) return 'กรุณาเลือกประเภทอาหาร';
                      final name = _foodTypeNameById(val);
                      if (name.trim() == 'ไม่ระบุ') {
                        return 'กรุณาเลือกประเภทอาหารให้ชัดเจน (ห้ามเลือก "ไม่ระบุ")';
                      }
                    }
                    return null;
                  },
                  dropdownColor: boxColor,
                ),

              const SizedBox(height: 12),

              _inputText(
                additionalController,
                'คำอธิบายกิจกรรม (ไม่บังคับ)',
                Icons.note,
                maxLines: 3,
                maxLength: 250,
                validator: _validateDescription,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFE9F3FF),
              foregroundColor: const Color(0xFF2F80ED),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: const Text('โพสต์'),
          ),
        ),
      ),
    );
  }
}

// lib/screens/Restaurant/CreateRestaurantPage.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:newproject/controller/RestaurantController.dart';
import 'package:newproject/widgets/multi_image_picker_field.dart';

class CreateRestaurantPage extends StatefulWidget {
  const CreateRestaurantPage({super.key});

  @override
  State<CreateRestaurantPage> createState() => _CreateRestaurantPageState();
}

class _CreateRestaurantPageState extends State<CreateRestaurantPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _typeId = TextEditingController(text: '1');
  final _open = TextEditingController();
  final _close = TextEditingController();

  List<XFile> _images = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _open.text = now.toIso8601String();
    _close.text = now.add(const Duration(hours: 8)).toIso8601String();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = RestaurantController();
    final ok = await ctrl.createRestaurantWithImages(
      restaurantName: _name.text.trim(),
      latitude: _lat.text.trim(),
      longitude: _lon.text.trim(),
      openTime: DateTime.parse(_open.text),
      closeTime: DateTime.parse(_close.text),
      restaurantTypeId: int.tryParse(_typeId.text) ?? 1,
      images: _images,
    );
    if (!mounted) return;
    if (ok != null) {
      Navigator.pop(context, ok);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกร้านไม่สำเร็จ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างร้านอาหาร')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'ชื่อร้าน'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'กรอกชื่อร้าน' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lat,
                      decoration: const InputDecoration(labelText: 'ละติจูด'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'ระบุ lat' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _lon,
                      decoration: const InputDecoration(labelText: 'ลองจิจูด'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'ระบุ lon' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _typeId,
                decoration: const InputDecoration(labelText: 'RestaurantTypeId'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _open,
                decoration: const InputDecoration(labelText: 'เปิด (ISO)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _close,
                decoration: const InputDecoration(labelText: 'ปิด (ISO)'),
              ),
              const SizedBox(height: 16),

              // วิดเจ็ตเลือกหลายรูป
              MultiImagePickerField(
                onChanged: (files) => _images = files,
                title: 'รูปภาพร้าน',
                maxImages: 10,
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('บันทึก'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

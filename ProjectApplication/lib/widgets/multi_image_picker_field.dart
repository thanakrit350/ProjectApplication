// lib/widgets/multi_image_picker_field.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MultiImagePickerField extends StatefulWidget {
  final List<XFile> initial;
  final ValueChanged<List<XFile>> onChanged;
  final String title;
  final int maxImages;

  const MultiImagePickerField({
    super.key,
    this.initial = const [],
    required this.onChanged,
    this.title = 'รูปภาพร้านอาหาร',
    this.maxImages = 10,
  });

  @override
  State<MultiImagePickerField> createState() => _MultiImagePickerFieldState();
}

class _MultiImagePickerFieldState extends State<MultiImagePickerField> {
  final picker = ImagePicker();
  late List<XFile> _files;

  @override
  void initState() {
    super.initState();
    _files = [...widget.initial];
  }

  Future<void> _pickMore() async {
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() {
      final remain = widget.maxImages - _files.length;
      _files.addAll(picked.take(remain));
    });
    widget.onChanged(_files);
  }

  void _removeAt(int i) {
    setState(() => _files.removeAt(i));
    widget.onChanged(_files);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${_files.length}/${widget.maxImages}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _files.length >= widget.maxImages ? null : _pickMore,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('เพิ่มรูป'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_files.isEmpty)
          Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('ยังไม่มีรูป'),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _files.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
            ),
            itemBuilder: (_, i) {
              final f = _files[i];
              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(f.path), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: InkWell(
                      onTap: () => _removeAt(i),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black54, borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

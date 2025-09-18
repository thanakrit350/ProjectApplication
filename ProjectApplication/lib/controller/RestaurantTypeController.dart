import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:newproject/constant/constant_value.dart';

class RestaurantTypeController {
  Future<List<Map<String, dynamic>>> getAllTypesWithId() async {
    final candidates = <String>[
      '$baseURL/restaurant-types',        // ถ้าคอนโทรลเลอร์เดิม
      '$baseURL/restaurants/restaurantTypes', // เผื่อโปรเจ็กต์คุณวาง path ไว้ที่อื่น
    ];
    for (final url in candidates) {
      try {
        final res = await http.get(Uri.parse(url), headers: headers);
        if (res.statusCode == 200) {
          final List<dynamic> arr = json.decode(utf8.decode(res.bodyBytes));
          return arr.map((e) => {
            'id': e['restaurantTypeId'],
            'name': e['typeName'] ?? '',
          }).toList();
        }
      } catch (_) {}
    }
    return [];
  }
  /// ✅ ใหม่: ดึงเฉพาะประเภทที่ "มีร้านจริง"
  Future<List<Map<String, dynamic>>> getNonEmptyTypesWithId() async {
    // 1) พยายามใช้ endpoint ที่ backend เพิ่งเพิ่มก่อน
    final endpoints = <String>[
      '$baseURL/restaurant-types/non-empty',  // คืน array ของ RestaurantType
      '$baseURL/restaurant-types/with-counts' // คืน [{id,name,restaurantCount}]
    ];

    for (final url in endpoints) {
      try {
        final res = await http.get(Uri.parse(url), headers: headers);
        if (res.statusCode != 200) continue;

        final body = utf8.decode(res.bodyBytes);
        final List<dynamic> arr = json.decode(body);

        // กรณี /non-empty: map ตรง ๆ
        if (url.endsWith('/non-empty')) {
          return arr.map((e) => {
            'id': e['restaurantTypeId'],
            'name': e['typeName'] ?? '',
          }).toList();
        }

        // กรณี /with-counts: กรองเฉพาะที่ count > 0
        final filtered = arr.where((e) {
          final cnt = (e['restaurantCount'] as num?)?.toInt() ?? 0;
          return cnt > 0;
        });

        return filtered.map((e) => {
          'id'  : e['id'] ?? e['restaurantTypeId'],
          'name': e['name'] ?? e['typeName'] ?? '',
        }).toList();
      } catch (_) {
        // ลอง endpoint ถัดไป
      }
    }

    // 2) Fallback: ถ้า backend ไม่มีทั้งสอง endpoint ข้างบน
    // จะได้ "ทุกประเภท" (อาจมีประเภทที่ไม่มีร้านปนอยู่)
    return await getAllTypesWithId();
  }
}

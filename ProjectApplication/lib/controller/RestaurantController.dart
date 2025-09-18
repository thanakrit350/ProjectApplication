import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/model/Restaurant.dart';

/// ใช้คืน page metadata จาก Spring Page
class PagedRestaurants {
  final List<Restaurant> items;
  final int page;      // page ปัจจุบัน (0-based)
  final int size;      // size ของ page
  final int totalPages;
  final int totalElements;
  final bool last;     // เป็นหน้าสุดท้ายไหม

  PagedRestaurants({
    required this.items,
    required this.page,
    required this.size,
    required this.totalPages,
    required this.totalElements,
    required this.last,
  });
}

class RestaurantController {
  // -------------------- ของเดิม (คงไว้) --------------------
  Future<List<Restaurant>> getAllRestaurants() async {
    final url = Uri.parse('$baseURL/restaurants');
    final response = await http.get(url, headers: headers);

    final utf8body = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = json.decode(utf8body);
    return jsonList.map((e) => Restaurant.fromRestaurantJson(e)).toList();
  }

  Future<Restaurant?> addRestaurant({
    required String restaurantName,
    required String restaurantPhone,
    required String restaurantImg,
    required String description,
    required String latitude,
    required String longitude,
    required String province,
    required String district,
    required String subdistrict,
    required String openTime,
    required String closeTime,
    required Map<String, dynamic> restaurantType,
  }) async {
    final data = {
      "restaurantName": restaurantName,
      "restaurantPhone": restaurantPhone,
      "restaurantImg": restaurantImg,
      "description": description,
      "latitude": latitude,
      "longitude": longitude,
      "province": province,
      "district": district,
      "subdistrict": subdistrict,
      "openTime": openTime,
      "closeTime": closeTime,
      "restaurantType": restaurantType,
    };

    final url = Uri.parse('$baseURL/restaurants');
    final response = await http.post(
      url,
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: json.encode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      return Restaurant.fromRestaurantJson(jsonResponse);
    } else {
      print('❌ addRestaurant failed: ${response.statusCode} — ${response.body}');
      return null;
    }
  }

  Future<Restaurant?> editRestaurant(Restaurant restaurant) async {
    final url = Uri.parse('$baseURL/restaurants/${restaurant.restaurantId}');
    final response = await http.put(
      url,
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: json.encode(restaurant.toJson()),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      return Restaurant.fromRestaurantJson(jsonResponse);
    } else {
      print('❌ editRestaurant failed: ${response.statusCode} — ${response.body}');
      return null;
    }
  }

  Future<void> deleteRestaurant(int restaurantId) async {
    final url = Uri.parse('$baseURL/restaurants/$restaurantId');
    await http.delete(url, headers: headers);
  }

  Future<Restaurant?> getRestaurantById(int restaurantId) async {
    final url = Uri.parse('$baseURL/restaurants/$restaurantId');
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final utf8body = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> jsonMap = json.decode(utf8body);
      return Restaurant.fromRestaurantJson(jsonMap);
    } else {
      print('❌ getRestaurantById failed: ${response.statusCode} — ${response.body}');
      return null;
    }
  }

  /// ---- เพิ่มร้านอย่างง่าย (fallback เดิม) ----
  Future<Restaurant?> addBasicRestaurant({
  required String restaurantName,
  required String latitude,
  required String longitude,
  int? restaurantTypeId,
  String? restaurantTypeName,
  String? province,
  String? district,
  String? subdistrict,
}) async {
  // ---------- เตรียม payload สำหรับ JSON endpoint ----------
  final String finalTypeName =
      (restaurantTypeName != null && restaurantTypeName.trim().isNotEmpty)
          ? restaurantTypeName.trim()
          : 'ร้านอาหาร';

  final Map<String, dynamic> data = {
    'restaurantName': restaurantName,
    'latitude': latitude,
    'longitude': longitude,
    if (restaurantTypeId != null) 'restaurantTypeId': restaurantTypeId,
    if (restaurantTypeId == null) 'restaurantTypeName': finalTypeName,
    if ((province ?? '').isNotEmpty) 'province': province,
    if ((district ?? '').isNotEmpty) 'district': district,
    if ((subdistrict ?? '').isNotEmpty) 'subdistrict': subdistrict,
  };

  // ---------- ยิงไป /restaurantsJson (application/json) ----------
  final urlJson = Uri.parse('$baseURL/restaurantsJson');
  final res = await http.post(
    urlJson,
    headers: {
      ...headers,
      'Content-Type': 'application/json; charset=utf-8',
    },
    body: jsonEncode(data),
  );

  if (res.statusCode == 200 || res.statusCode == 201) {
    final jsonResponse = jsonDecode(utf8.decode(res.bodyBytes));
    return Restaurant.fromRestaurantJson(jsonResponse);
  }

  // ---------- Fallback: ถ้า JSON ไม่ได้ และมี typeId → ลอง multipart /restaurants ----------
  if (restaurantTypeId != null) {
    try {
      final urlMp = Uri.parse('$baseURL/restaurants');

      // อย่าตั้ง Content-Type เอง ให้ MultipartRequest จัดการ
      final mpReq = http.MultipartRequest('POST', urlMp);
      // กรอง Content-Type เดิมออก (ถ้ามีใน headers) แล้วใส่ header อื่น ๆ เช่น Authorization
      final filteredHeaders = Map<String, String>.from(headers)
        ..removeWhere((k, _) => k.toLowerCase() == 'content-type');
      mpReq.headers.addAll(filteredHeaders);

      mpReq.fields['restaurantName'] = restaurantName;
      mpReq.fields['latitude'] = latitude;
      mpReq.fields['longitude'] = longitude;
      // province เป็น required ใน /restaurants ฝั่งคุณกำหนดไว้ — ถ้าไม่มี ให้ส่งค่าว่างได้
      mpReq.fields['province'] = (province ?? '');
      mpReq.fields['restaurantType'] = restaurantTypeId.toString();
      if ((district ?? '').isNotEmpty) mpReq.fields['district'] = district!;
      if ((subdistrict ?? '').isNotEmpty) mpReq.fields['subdistrict'] = subdistrict!;

      final streamed = await mpReq.send();
      final fb = await http.Response.fromStream(streamed);

      if (fb.statusCode == 200 || fb.statusCode == 201) {
        final jsonResponse = jsonDecode(utf8.decode(fb.bodyBytes));
        return Restaurant.fromRestaurantJson(jsonResponse);
      } else {
        // debug log
        // print('❌ multipart fallback failed: ${fb.statusCode} — ${fb.body}');
      }
    } catch (e) {
      // print('❌ multipart fallback error: $e');
    }
  }

  // ถ้าไม่สำเร็จ
  return null;
}


  // -------------------- ใหม่: เรียก page แบบ Spring --------------------
    Future<PagedRestaurants> fetchPaged({
    String q = '',
    int? typeId,
    int page = 0,
    int size = 30,
  }) async {
    final candidates = <String>[
      '$baseURL/restaurantsJson/searchPaged', // ตัวใหม่ (ถ้ามี)
      '$baseURL/restaurants/searchPaged',     // ตัวเดิมของโปรเจ็กต์คุณ
    ];

    Object? lastErr;

    for (final base in candidates) {
      final uri = Uri.parse(base).replace(queryParameters: {
        if (q.isNotEmpty) 'q': q,
        if (typeId != null) 'typeId': '$typeId',
        'page': '$page',
        'size': '$size',
      });

      try {
        final res = await http.get(uri, headers: headers);
        if (res.statusCode == 200) {
          final map = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final List<dynamic> content = map['content'] ?? [];
          final items = content.map((e) => Restaurant.fromRestaurantJson(e)).toList();

          return PagedRestaurants(
            items: items,
            page: (map['number'] ?? page) as int,
            size: (map['size'] ?? size) as int,
            totalPages: (map['totalPages'] ?? 0) as int,
            totalElements: (map['totalElements'] ?? 0) as int,
            last: (map['last'] ?? false) as bool,
          );
        }

        // ถ้าเป็น 404/405 ให้ลอง candidate ถัดไป
        if (res.statusCode == 404 || res.statusCode == 405) continue;

        // สถานะอื่น ๆ โยน error ทันที
        throw Exception('status=${res.statusCode}, body=${res.body}');
      } catch (e) {
        lastErr = e;
        // ลองตัวถัดไป
      }
    }

    throw Exception('fetchPaged failed on all endpoints. lastErr=$lastErr');
  }


  /// ใหม่: ใกล้ฉัน (มี page/size) — backend คืนเป็น List เฉย ๆ
  /// hasMore = list.length == size
  Future<(List<Restaurant> items, bool hasMore)> fetchNear({
    required double lat,
    required double lon,
    double radiusKm = 5,
    int page = 0,
    int size = 30,
  }) async {
    final uri = Uri.parse('$baseURL/restaurantsJson/near').replace(queryParameters: {
      'lat': '$lat',
      'lon': '$lon',
      'radiusKm': '$radiusKm',
      'page': '$page',
      'size': '$size',
    });

    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('fetchNear failed: ${res.statusCode} — ${res.body}');
    }
    final list = json.decode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    final items = list.map((e) => Restaurant.fromRestaurantJson(e)).toList();
    final hasMore = items.length == size;
    return (items, hasMore);
  }

  // ================== อัปโหลดหลายรูป (คงเดิม) ==================
  Map<String, String> _multipartHeaders() {
    final h = <String, String>{...headers};
    h.removeWhere((k, v) => k.toLowerCase() == 'content-type');
    return h;
  }

  Future<Restaurant?> createRestaurantWithImages({
    required String restaurantName,
    String restaurantPhone = '',
    String description = '',
    required String latitude,
    required String longitude,
    String province = '',
    String district = '',
    String subdistrict = '',
    required DateTime openTime,
    required DateTime closeTime,
    required int restaurantTypeId,
    List<XFile> images = const [],
  }) async {
    final uri = Uri.parse('$baseURL/restaurants');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_multipartHeaders())
      ..fields.addAll({
        'restaurantName': restaurantName,
        'restaurantPhone': restaurantPhone,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'province': province,
        'district': district,
        'subdistrict': subdistrict,
        'openTime': openTime.toIso8601String(),
        'closeTime': closeTime.toIso8601String(),
        'restaurantType': restaurantTypeId.toString(),
      });

    if (images.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('restaurantImg', images.first.path));
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 201 || res.statusCode == 200) {
      final created = Restaurant.fromRestaurantJson(jsonDecode(utf8.decode(res.bodyBytes)));

      if (created.restaurantId != null && images.length > 1) {
        final remain = images.sublist(1);
        await appendImages(created.restaurantId!, remain);
      }
      return created;
    } else {
      print('❌ createRestaurantWithImages failed: ${res.statusCode} — ${res.body}');
      return null;
    }
  }

  Future<Restaurant?> updateRestaurantWithImages(
    int id, {
    required String restaurantName,
    String restaurantPhone = '',
    String description = '',
    required String latitude,
    required String longitude,
    String province = '',
    String district = '',
    String subdistrict = '',
    required DateTime openTime,
    required DateTime closeTime,
    required int restaurantTypeId,
    List<XFile>? newImages,
  }) async {
    final uri = Uri.parse('$baseURL/restaurants/$id');
    final req = http.MultipartRequest('PUT', uri)
      ..headers.addAll(_multipartHeaders())
      ..fields.addAll({
        'restaurantName': restaurantName,
        'restaurantPhone': restaurantPhone,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'province': province,
        'district': district,
        'subdistrict': subdistrict,
        'openTime': openTime.toIso8601String(),
        'closeTime': closeTime.toIso8601String(),
        'restaurantType': restaurantTypeId.toString(),
      });

    if (newImages != null && newImages.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('restaurantImg', newImages.first.path));
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      return Restaurant.fromRestaurantJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      print('❌ updateRestaurantWithImages failed: ${res.statusCode} — ${res.body}');
      return null;
    }
  }

  Future<bool> appendImages(int id, List<XFile> images) async {
    if (images.isEmpty) return true;

    final uri = Uri.parse('$baseURL/restaurants/$id/images');
    final req = http.MultipartRequest('POST', uri)..headers.addAll(_multipartHeaders());
    for (final x in images) {
      req.files.add(await http.MultipartFile.fromPath('files', x.path));
    }

    try {
      final streamed = await req.send();
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) return true;

      if (streamed.statusCode == 404 || streamed.statusCode == 405) return false;

      print('❌ appendImages failed: ${streamed.statusCode}');
      return false;
    } catch (e) {
      print('❌ appendImages error: $e');
      return false;
    }
  }
}

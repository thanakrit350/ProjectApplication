import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/model/Member.dart';

class MemberController {
  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw ArgumentError('คาดว่าเป็น JSON object แต่ได้ ${raw.runtimeType}');
  }

  String _extractErrorMessage(http.Response res) {
    final body = utf8.decode(res.bodyBytes);
    try {
      final j = json.decode(body);
      if (j is Map && j['message'] is String) return j['message'] as String;
    } catch (_) {}
    return body.isNotEmpty ? body : 'เกิดข้อผิดพลาด (${res.statusCode})';
  }

  Future<List<Member>> getAllMembers() async {
    final url = Uri.parse('$baseURL/members');
    final res = await http.get(url, headers: headers);
    final List<dynamic> list = json.decode(utf8.decode(res.bodyBytes));
    return list.map((e) => Member.fromMemberJson(_toMap(e))).toList();
  }

  // สมัครสมาชิก (ไปที่ /auth/register หรือ /members ก็ได้ตามฝั่งเซิร์ฟเวอร์)
  Future<Member?> addMember({
    required String firstName,
    required String lastName,
    required String birthDate,
    required String gender,
    required String profileImage,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    final url = Uri.parse('$baseURL/auth/register');
    final body = json.encode({
      "firstName": firstName.trim(),
      "lastName": lastName.trim(),
      "birthDate": birthDate,
      "gender": gender,
      "profileImage": profileImage,
      "email": email.trim(),
      "password": password,
      "phoneNumber": phoneNumber.trim(),
    });

    final res = await http.post(url, headers: headers, body: body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return Member.fromMemberJson(_toMap(json.decode(utf8.decode(res.bodyBytes))));
    } else {
      throw Exception(_extractErrorMessage(res));
    }
  }

  // แก้ไข + อัปโหลดรูป (password เป็น optional; ใส่เฉพาะตอนเปลี่ยนรหัส)
  Future<Member?> editMember({
    required int memberId,
    required String firstName,
    required String lastName,
    required String birthDate,
    required String gender,
    required String email,
    String? password,                   // <- optional
    required String phoneNumber,
    File? profileImageFile,
  }) async {
    final uri = Uri.parse('$baseURL/members/$memberId');
    final req = http.MultipartRequest('PUT', uri);

    req.fields.addAll({
      'firstName': firstName,
      'lastName' : lastName,
      'birthDate': birthDate,
      'gender'   : gender,
      'email'    : email,
      'phoneNumber': phoneNumber,
    });

    if (password != null && password.isNotEmpty) {
      req.fields['password'] = password; // ส่งเมื่อผู้ใช้ตั้งใจเปลี่ยนเท่านั้น
    }

    if (profileImageFile != null) {
      req.files.add(await http.MultipartFile.fromPath('profileImage', profileImageFile.path));
    }

    req.headers['Accept'] = 'application/json';

    final resp = await req.send();
    final respStr = await resp.stream.bytesToString();

    if (resp.statusCode == 200) {
      return Member.fromMemberJson(Map<String, dynamic>.from(jsonDecode(respStr)));
    } else {
      throw Exception('อัปเดตไม่สำเร็จ (${resp.statusCode}) $respStr');
    }
  }

  Future<Member?> getMemberById(int id) async {
    final res = await http.get(Uri.parse('$baseURL/members/$id'), headers: headers);
    if (res.statusCode == 200) {
      return Member.fromMemberJson(_toMap(json.decode(utf8.decode(res.bodyBytes))));
    }
    return null;
  }

  Future<Member?> getMemberByEmail(String email) async {
    final res = await http.get(Uri.parse('$baseURL/members/email/$email'), headers: headers);
    if (res.statusCode == 200) {
      return Member.fromMemberJson(_toMap(json.decode(utf8.decode(res.bodyBytes))));
    }
    return null;
  }

  // เข้าสู่ระบบ — ที่ /auth/login (x-www-form-urlencoded) หรือ /members/login ก็ได้
  Future<Map<String, dynamic>> loginMember(String email, String password) async {
    final url = Uri.parse('$baseURL/auth/login');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'email': email.trim(), 'password': password},
    );

    final bodyStr = utf8.decode(res.bodyBytes);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(bodyStr);
      late Member member;
      if (decoded is Map && decoded['data'] is Map) {
        member = Member.fromMemberJson(Map<String, dynamic>.from(decoded['data']));
      } else if (decoded is Map) {
        member = Member.fromMemberJson(Map<String, dynamic>.from(decoded));
      } else {
        throw Exception('รูปแบบข้อมูลไม่ถูกต้อง');
      }

      return {'status': true, 'message': 'เข้าสู่ระบบสำเร็จ', 'member': member};
    } else {
      return {'status': false, 'message': _extractErrorMessageFromString(res.statusCode, bodyStr)};
    }
  }

  String _extractErrorMessageFromString(int code, String body) {
    try {
      final j = json.decode(body);
      if (j is Map && j['message'] is String) return j['message'] as String;
    } catch (_) {}
    return body.isNotEmpty ? body : 'เกิดข้อผิดพลาด ($code)';
  }
}

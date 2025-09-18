import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/model/Activity.dart';
import 'package:newproject/model/ActivityMember.dart';

class ActivityInviteController {
  static const String baseUrl = baseURL;

  // ===== Helpers =====
  String _normalizePhone(String phone) =>
      phone.trim().replaceAll(RegExp(r'[\s-]'), '');

  Map<String, String> _formHeaders() => const {
        'Content-Type': 'application/x-www-form-urlencoded',
      };

  Map<String, String> _jsonHeaders() => const {
        'Content-Type': 'application/json',
      };

  // ===== Invites =====

  /// เชิญเพื่อนด้วยอีเมล
  Future<bool> inviteByEmail(int activityId, String email) async {
    try {
      final url = Uri.parse('$baseUrl/activity-invites/invite');

      final response = await http.post(
        url,
        headers: _formHeaders(),
        body: {
          'activityId': activityId.toString(),
          'email': email,
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final error = response.body;
        throw Exception(error.isEmpty ? 'เชิญด้วยอีเมลไม่สำเร็จ' : error);
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  /// ✅ เชิญเพื่อนด้วย "เบอร์โทร"
  Future<bool> inviteByPhone(int activityId, String phone) async {
    try {
      final url = Uri.parse('$baseUrl/activity-invites/invite-phone');

      final response = await http.post(
        url,
        headers: _formHeaders(),
        body: {
          'activityId': activityId.toString(),
          'phone': _normalizePhone(phone),
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final error = response.body;
        throw Exception(error.isEmpty ? 'เชิญด้วยเบอร์โทรไม่สำเร็จ' : error);
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // ===== Queries =====

  /// ดึงกิจกรรมที่ถูกเชิญ
  Future<List<Activity>> getInvitedActivities(int memberId) async {
    try {
      final url = Uri.parse('$baseUrl/activity-invites/invited/$memberId');

      final response = await http.get(url, headers: _jsonHeaders());

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Activity.fromJson(json)).toList();
      } else {
        throw Exception('ไม่สามารถดึงข้อมูลกิจกรรมได้');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  /// ดึงรายชื่อสมาชิกในกิจกรรม
  Future<List<ActivityMember>> getActivityMembers(int activityId) async {
    try {
      final url = Uri.parse('$baseUrl/activity-invites/members/$activityId');

      final response = await http.get(url, headers: _jsonHeaders());

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => ActivityMember.fromJson(json)).toList();
      } else {
        throw Exception('ไม่สามารถดึงข้อมูลสมาชิกได้');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // ===== Actions =====

  /// ตอบกลับคำเชิญ ("เข้าร่วม" หรือ "ปฏิเสธ")
  Future<bool> respondInvite(int activityId, int memberId, String responseText) async {
    try {
      final url = Uri.parse('$baseUrl/activity-invites/respond');

      final httpResponse = await http.put(
        url,
        headers: _formHeaders(),
        body: {
          'activityId': activityId.toString(),
          'memberId': memberId.toString(),
          'response': responseText,
        },
      );

      if (httpResponse.statusCode == 200) {
        return true;
      } else {
        final error = httpResponse.body;
        throw Exception(error.isEmpty ? 'ตอบกลับคำเชิญไม่สำเร็จ' : error);
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }
}

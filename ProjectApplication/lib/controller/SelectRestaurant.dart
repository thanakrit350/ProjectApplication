import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:newproject/constant/constant_value.dart';
import 'package:newproject/model/Activity.dart';

class ActivitySelectionController {
  final String baseUrl = baseURL;

  /// POST /activities/{activityId}/select-restaurant
  /// body: { "memberId": int, "restaurantId": int }
  /// return: Activity (อัปเดตแล้ว)
  Future<Activity> selectRestaurantForActivity({
    required int activityId,
    required int memberId,
    required int restaurantId,
  }) async {
    final url = Uri.parse('$baseUrl/activities/$activityId/select-restaurant');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'memberId': memberId, 'restaurantId': restaurantId}),
    );

    if (resp.statusCode == 200) {
      return Activity.fromJson(json.decode(resp.body));
    } else {
      throw Exception('เลือกไม่สำเร็จ: ${resp.statusCode} ${resp.body}');
    }
  }
}

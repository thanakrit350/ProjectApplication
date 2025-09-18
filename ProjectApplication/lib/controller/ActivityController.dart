import 'package:http/http.dart' as http;
import 'package:newproject/constant/constant_value.dart';
import 'dart:convert';
import '../model/Activity.dart';

class ActivityController {
  final String baseUrl = baseURL;

  Future<Activity?> createActivity(Activity activity) async {
    final url = Uri.parse('$baseUrl/activities');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(activity.toJson()),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return Activity.fromJson(data);
    } else {
      throw Exception('Failed to create activity: ${response.statusCode}\n${response.body}');
    }
  }

  Future<Activity?> updateActivity(int activityId, Activity activity) async {
    final url = Uri.parse('$baseUrl/activities/$activityId');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(activity.toJson()),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Activity.fromJson(data);
    } else {
      throw Exception('Failed to update activity: ${response.statusCode}\n${response.body}');
    }
  }

  Future<Activity?> getActivityById(int activityId) async {
    final url = Uri.parse('$baseUrl/activities/$activityId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Activity.fromJson(data);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to get activity: ${response.statusCode}\n${response.body}');
    }
  }

  Future<List<Activity>> getAllActivities() async {
    final url = Uri.parse('$baseUrl/activities');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Activity.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch activities: ${response.statusCode}\n${response.body}');
    }
  }

  /// ลบด้วย activityId ให้ตรงกับ Backend: DELETE /activities/{id}
  Future<void> deleteActivity(int activityId) async {
    final url = Uri.parse('$baseUrl/activities/$activityId');
    final response = await http.delete(url);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete activity: ${response.statusCode}\n${response.body}');
    }
  }

  
}

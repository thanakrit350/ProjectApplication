import 'package:newproject/model/ActivityMember.dart';
import 'package:newproject/model/RestaurantType.dart';
import 'Restaurant.dart';

class Activity {
  final int? activityId;
  final String? activityName;
  final String? descriptionActivity;
  final DateTime? inviteDate;
  final DateTime? postDate;
  final String? statusPost;
  final bool? isOwnerSelect;
  final RestaurantType? restaurantType;
  final Restaurant? restaurant;
  final List<ActivityMember> activityMembers;

  Activity({
    this.activityName,
    this.descriptionActivity,
    this.inviteDate,
    this.postDate,
    this.statusPost,
    this.isOwnerSelect,
    this.restaurantType,
    this.restaurant,
    this.activityMembers = const [],
    this.activityId,
  });

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        activityId: json['activityId'],
        activityName: json['activityName'],
        descriptionActivity: json['descriptionActivity'],
        inviteDate: _parseToLocal(json['inviteDate'] ?? ''),
        postDate: _parseToLocal(json['postDate'] ?? ''),
        statusPost: json['statusPost'],
        isOwnerSelect: json['isOwnerSelect'],
        restaurantType: json['restaurantType'] != null
            ? RestaurantType.fromJson(json['restaurantType'])
            : null,
        restaurant: json['restaurant'] != null
            ? Restaurant.fromRestaurantJson(json['restaurant'])
            : null,
        activityMembers: (json['activityMembers'] as List<dynamic>?)
                ?.map((e) => ActivityMember.fromJson(e))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        "activityName": activityName,
        "descriptionActivity": descriptionActivity,
        "inviteDate": inviteDate?.toUtc().toIso8601String(),
        "postDate": postDate?.toUtc().toIso8601String(),
        "statusPost": statusPost,
        "isOwnerSelect": isOwnerSelect,

        // ส่งต่อเมื่อรู้ id เท่านั้น (อย่าส่ง object ว่าง)
        if (restaurantType?.restaurantTypeId != null)
          "restaurantType": {"restaurantTypeId": restaurantType!.restaurantTypeId},

        if (restaurant?.restaurantId != null)
          "restaurant": {"restaurantId": restaurant!.restaurantId},

        'activityMembers': activityMembers.map((e) => e.toJson()).toList(),
      };

  static DateTime? _parseToLocal(dynamic v) {
    if (v == null) return null;
    final d = DateTime.tryParse(v.toString());
    if (d == null) return null;
    return d.isUtc ? d.toLocal() : d;
  }
}

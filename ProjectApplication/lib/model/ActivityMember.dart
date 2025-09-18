import 'Member.dart';
import 'SelectRestaurant.dart';

class ActivityMember {
  final DateTime joinDate;
  final String memberStatus;
  final Member member;
  final SelectRestaurant? selectRestaurant;

  ActivityMember({
    required this.joinDate,
    required this.memberStatus,
    required this.member,
    this.selectRestaurant,
  });

  factory ActivityMember.fromJson(Map<String, dynamic> json) => ActivityMember(
        joinDate: DateTime.parse(json['joinDate']),
        memberStatus: json['memberStatus'],
        member: Member.fromMemberJson(json['member']),
        selectRestaurant: json['selectRestaurant'] != null
            ? SelectRestaurant.fromJson(json['selectRestaurant'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        "joinDate": joinDate.toIso8601String(),
        "memberStatus": memberStatus,
        "member": {"memberId": member.memberId},

        // ส่งเฉพาะตอนมีค่า
        if (selectRestaurant?.selectRestaurantId != null)
          "selectRestaurant": {
            "selectRestaurantId": selectRestaurant!.selectRestaurantId
          },
      };
}

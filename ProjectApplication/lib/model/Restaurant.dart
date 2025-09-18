import 'package:newproject/model/RestaurantType.dart';
import 'package:newproject/utils/time_helper.dart';

class Restaurant {
  int? restaurantId;
  String? restaurantName;
  String? restaurantPhone;
  String? restaurantImg;
  String? description;
  String? latitude;
  String? longitude;
  String? province;
  String? district;
  String? subdistrict;
  String? openTime;  
  String? closeTime; 
  RestaurantType? restaurantType;

  String get formattedOpenTime => formatTime(openTime);
  String get formattedCloseTime => formatTime(closeTime);

  Restaurant({
    this.restaurantId,
    this.restaurantName,
    this.restaurantPhone,
    this.restaurantImg,
    this.description,
    this.latitude,
    this.longitude,
    this.province,
    this.district,
    this.subdistrict,
    this.openTime,
    this.closeTime,
    this.restaurantType,
  });

  factory Restaurant.fromRestaurantJson(Map<String, dynamic> json) {
    return Restaurant(
      restaurantId: json['restaurantId'],
      restaurantName: json['restaurantName'],
      restaurantPhone: json['restaurantPhone'],
      restaurantImg: json['restaurantImg'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      province: json['province'],
      district: json['district'],
      subdistrict: json['subdistrict'],
      openTime: json['openTime'],
      closeTime: json['closeTime'],
      restaurantType: json['restaurantType'] != null
          ? RestaurantType.fromJson(json['restaurantType'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantPhone': restaurantPhone,
      'restaurantImg': restaurantImg,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'province': province,
      'district': district,
      'subdistrict': subdistrict,
      'openTime': openTime,
      'closeTime': closeTime,
      'restaurantType': restaurantType?.toJson(),
    };
  }
}
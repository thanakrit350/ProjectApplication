import 'Restaurant.dart';

class SelectRestaurant {
  final int? selectRestaurantId;
  final bool statusSelect;
  final Restaurant restaurant;

  SelectRestaurant({
    this.selectRestaurantId,
    required this.statusSelect,
    required this.restaurant,
  });

  factory SelectRestaurant.fromJson(Map<String, dynamic> json) => SelectRestaurant(
        selectRestaurantId: json['selectRestaurantId'],
        statusSelect: json['statusSelect'] ?? false,
        restaurant: Restaurant.fromRestaurantJson(json['restaurant']),
      );

  Map<String, dynamic> toJson() => {
        if (selectRestaurantId != null) 'selectRestaurantId': selectRestaurantId,
        'statusSelect': statusSelect,

        // ใช้เฉพาะ id ของร้านพอ
        'restaurant': {'restaurantId': restaurant.restaurantId},
      };
}

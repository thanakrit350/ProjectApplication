class RestaurantType {
  final int? restaurantTypeId;
  final String? typeName;

  RestaurantType({this.restaurantTypeId, this.typeName});

  factory RestaurantType.fromJson(Map<String, dynamic> json) {
    return RestaurantType(
      restaurantTypeId: json['restaurantTypeId'] as int?,
      typeName: json['typeName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (restaurantTypeId != null) 'restaurantTypeId': restaurantTypeId,
      if (typeName != null) 'typeName': typeName,
    };
  }
}

package com.finalproject.Restaurant.dto;

import lombok.Data;

@Data
public class RestaurantUpsertRequest {
    public String restaurantName;
    public String restaurantPhone;
    public String description;
    public String latitude;
    public String longitude;
    public String province;
    public String district;
    public String subdistrict;
    public String openTime;   // "HH:mm" หรือ ISO
    public String closeTime;  // "HH:mm" หรือ ISO

    public Integer restaurantTypeId;     // ถ้าระบุ id มา จะใช้ id
    public String  restaurantTypeName;   // ถ้าไม่ระบุ id, ใช้ชื่อนี้ find-or-create
}

package com.finalproject.Restaurant.dto;

import lombok.Data;
import lombok.NoArgsConstructor;



@Data
@NoArgsConstructor
public class SelectRestaurantRequest {
    private Integer memberId;
    private Integer restaurantId;
}

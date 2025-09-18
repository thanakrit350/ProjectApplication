package com.finalproject.Restaurant.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.*;

@Entity
@Table(name = "Restaurant")
@Data
@AllArgsConstructor
@NoArgsConstructor
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class Restaurant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer restaurantId;

    @Column(nullable = false,length = 255)
    private String restaurantName;

    @Column(length = 13)
    private String restaurantPhone;

    @Column(columnDefinition = "TEXT")
    private String restaurantImg;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false, length = 50)
    private String latitude;

    @Column(nullable = false, length = 50)
    private String longitude;

    @Column(length = 100)
    private String province;

    @Column(length = 100)
    private String district;

    @Column(length = 100)
    private String subdistrict;

    @Column()
    private LocalDateTime openTime;

    @Column()
    private LocalDateTime closeTime;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "restaurantTypeId")
    private RestaurantType restaurantType;
}

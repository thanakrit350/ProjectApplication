package com.finalproject.Restaurant.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "RestaurantType")
@Data
@AllArgsConstructor
@NoArgsConstructor
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class RestaurantType {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer restaurantTypeId;

    @Column(nullable = false, length = 255)
    private String typeName;
//
//    @OneToMany(mappedBy = "restaurantType", cascade = CascadeType.ALL)
//    private List<Restaurant> restaurants = new ArrayList<>();
}

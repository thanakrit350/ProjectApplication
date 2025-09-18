package com.finalproject.Restaurant.service;

import com.finalproject.Restaurant.model.Restaurant;

import java.util.List;

public interface RestaurantService {

    Restaurant getRestaurantById(Integer id);

    List<Restaurant> getAllRestaurants();

    Restaurant createRestaurant(Restaurant restaurant);

    Restaurant saveRestaurant(Restaurant restaurant);

    Restaurant updateRestaurant(Restaurant restaurant);

    void deleteRestaurant(Integer id);

    List<Restaurant> searchRestaurants(String q, Integer typeId);
}

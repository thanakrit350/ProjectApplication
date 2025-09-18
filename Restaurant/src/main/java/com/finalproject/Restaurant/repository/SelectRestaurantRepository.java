package com.finalproject.Restaurant.repository;

import com.finalproject.Restaurant.model.SelectRestaurant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SelectRestaurantRepository extends JpaRepository<SelectRestaurant, Integer> {
    Optional<SelectRestaurant> findByRestaurant_RestaurantId(Integer restaurantId);
}

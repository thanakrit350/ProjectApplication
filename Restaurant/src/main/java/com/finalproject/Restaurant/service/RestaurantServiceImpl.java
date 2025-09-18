package com.finalproject.Restaurant.service;

import com.finalproject.Restaurant.model.Restaurant;
import com.finalproject.Restaurant.repository.RestaurantRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class RestaurantServiceImpl implements RestaurantService {

    @Autowired
    private RestaurantRepository restaurantRepository;

    @Override
    public Restaurant getRestaurantById(Integer id) {
        Optional<Restaurant> restaurant = restaurantRepository.findById(id);
        if (restaurant.isPresent()) {
            return restaurant.get();
        } else {
            throw new RuntimeException("Restaurant not found");
        }
    }

    @Override
    public List<Restaurant> getAllRestaurants() {
        return restaurantRepository.findAll();
    }

    @Override
    public Restaurant createRestaurant(Restaurant restaurant) {
        return restaurantRepository.save(restaurant);
    }

    @Override
    public Restaurant saveRestaurant(Restaurant restaurant) {
        return restaurantRepository.save(restaurant);
    }

    @Override
    public Restaurant updateRestaurant(Restaurant restaurant) {
        if (restaurantRepository.existsById(restaurant.getRestaurantId())) {
            return restaurantRepository.save(restaurant);
        } else {
            throw new RuntimeException("Restaurant not found for update");
        }
    }

    @Override
    public void deleteRestaurant(Integer id) {
        if (restaurantRepository.existsById(id)) {
            restaurantRepository.deleteById(id);
        } else {
            throw new RuntimeException("Restaurant not found for delete");
        }
    }

    @Override
    public List<Restaurant> searchRestaurants(String q, Integer typeId) {
        return restaurantRepository.search(q, typeId);
    }

    public Page<Restaurant> search(String q, Integer typeId, int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        return restaurantRepository.search(
                (q == null || q.isBlank()) ? null : q.trim(),
                typeId,
                pageable
        );
    }
}

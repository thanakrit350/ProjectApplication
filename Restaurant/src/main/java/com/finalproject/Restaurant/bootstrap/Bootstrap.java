package com.finalproject.Restaurant.bootstrap;

import com.finalproject.Restaurant.model.RestaurantType;
import com.finalproject.Restaurant.repository.RestaurantTypeRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
public class Bootstrap implements CommandLineRunner {

    @Autowired
    private RestaurantTypeRepository restaurantTypeRepository;

    @Override
    public void run(String... args) {
        // ถ้ายังไม่มี type ชื่อ "ไม่ระบุ" ให้สร้างไว้ 1 แถว
        restaurantTypeRepository.findByTypeName("ไม่ระบุ").orElseGet(() -> {
            RestaurantType rt = new RestaurantType();
            rt.setTypeName("ไม่ระบุ");
            return restaurantTypeRepository.save(rt);
        });
    }
}

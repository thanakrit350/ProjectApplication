package com.finalproject.Restaurant;

import jakarta.annotation.PostConstruct;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.util.TimeZone;

@SpringBootApplication
@EnableScheduling  // ✅ เปิดให้ใช้ @Scheduled
public class RestaurantApplication {

	@PostConstruct
	public void init() {
		// ตั้งค่าโซนเวลาเป็นไทย (ถ้าต้องการ)
		TimeZone.setDefault(TimeZone.getTimeZone("Asia/Bangkok"));
	}

	public static void main(String[] args) {
		SpringApplication.run(RestaurantApplication.class, args);
	}
}

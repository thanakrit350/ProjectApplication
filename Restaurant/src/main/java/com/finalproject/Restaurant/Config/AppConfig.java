package com.finalproject.Restaurant.Config;

import com.finalproject.Restaurant.model.RestaurantType;
import com.finalproject.Restaurant.repository.RestaurantTypeRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

@Configuration
public class AppConfig {

    @Bean
    CommandLineRunner seedRestaurantTypes(RestaurantTypeRepository repo) {
        return args -> {
            List<String> names = List.of(
                    // หมวดหลัก ๆ
                    "ไทย","อีสาน","ญี่ปุ่น","จีน","เวียดนาม","เกาหลี","อิตาลี","เม็กซิกัน","อเมริกัน",
                    "เมดิเตอร์เรเนียน","ฮาลาล","มังสวิรัติ","วีแกน","อาหารสุขภาพ",
                    // ประเภทย่อย/รูปแบบ
                    "บุฟเฟต์","ชาบูชาบู","สุกี้ยากี้/หม้อไฟ","ยากินิกุ/ปิ้งย่าง","บาร์บีคิว",
                    "ซูชิ","ราเมง","อุด้ง","โซบะ","ก๋วยเตี๋ยว/บะหมี่","ข้าวต้ม","ติ่มซำ",
                    "สเต็ก","พิซซ่า","อาหารจานด่วน","ซีฟู้ด/อาหารทะเล","ของหวาน/ไอศกรีม",
                    "เบเกอรี่/ขนม","คาเฟ่/กาแฟ","อาหารเช้า/บรันช์","ฟิวชัน/เอเชียฟิวชัน",
                    // เผื่อ fallback
                    "ร้านอาหาร"
            );
            for (String n : names) {
                repo.findByTypeNameIgnoreCase(n).orElseGet(() -> repo.save(new RestaurantType(null, n)));
            }
        };
    }
}

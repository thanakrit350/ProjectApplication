package com.finalproject.Restaurant.repository;

import com.finalproject.Restaurant.model.RestaurantType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface RestaurantTypeRepository extends JpaRepository<RestaurantType, Integer> {
    Optional<RestaurantType> findByTypeName(String typeName);
    Optional<RestaurantType> findByTypeNameIgnoreCase(String typeName);
    boolean existsByTypeNameIgnoreCase(String typeName);

    // ใช้เช็คชื่อซ้ำตอนแก้ไข (ยกเว้น id ปัจจุบัน)
    boolean existsByTypeNameIgnoreCaseAndRestaurantTypeIdNot(String typeName, Integer restaurantTypeId);
    List<RestaurantType> findByTypeNameContainingIgnoreCase(String q);
    // ✅ ใหม่: ดึงเฉพาะประเภทที่ "มีร้านอย่างน้อย 1 ร้าน"
    @Query("""
           select rt
           from RestaurantType rt
           where exists (
             select 1 from Restaurant r
             where r.restaurantType = rt
           )
           """)
    List<RestaurantType> findAllHavingRestaurants();

    // (ออปชัน) ถ้าอยากได้ count ด้วย
    interface TypeCountProjection {
        Integer getRestaurantTypeId();
        String getTypeName();
        Long getRestaurantCount();
    }

    @Query("""
           select rt.restaurantTypeId as restaurantTypeId,
                  rt.typeName as typeName,
                  count(r) as restaurantCount
           from RestaurantType rt
           left join Restaurant r on r.restaurantType = rt
           group by rt.restaurantTypeId, rt.typeName
           """)
    List<TypeCountProjection> findAllWithCounts();
}

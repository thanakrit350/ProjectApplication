package com.finalproject.Restaurant.repository;

import com.finalproject.Restaurant.model.Restaurant;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RestaurantRepository extends JpaRepository<Restaurant, Integer> {

    @Query("SELECT r FROM Restaurant r " +
            "WHERE (:typeId IS NULL OR r.restaurantType.restaurantTypeId = :typeId) " +
            "AND ( :q IS NULL OR :q = '' " +
            "   OR LOWER(r.restaurantName) LIKE LOWER(CONCAT('%', :q, '%')) " +
            "   OR LOWER(r.province)      LIKE LOWER(CONCAT('%', :q, '%')) " +
            "   OR LOWER(r.district)      LIKE LOWER(CONCAT('%', :q, '%')) " +
            "   OR LOWER(r.subdistrict)   LIKE LOWER(CONCAT('%', :q, '%')) )")
    List<Restaurant> search(@Param("q") String q, @Param("typeId") Integer typeId);

    @Query("""
           SELECT r FROM Restaurant r
           LEFT JOIN r.restaurantType t
           WHERE (:q IS NULL OR
                  LOWER(r.restaurantName) LIKE LOWER(CONCAT('%', :q, '%')) OR
                  LOWER(r.description)   LIKE LOWER(CONCAT('%', :q, '%')) OR
                  LOWER(r.province)      LIKE LOWER(CONCAT('%', :q, '%')) OR
                  LOWER(r.district)      LIKE LOWER(CONCAT('%', :q, '%')) OR
                  LOWER(r.subdistrict)   LIKE LOWER(CONCAT('%', :q, '%')))
            AND (:typeId IS NULL OR t.restaurantTypeId = :typeId)
           """)
    Page<Restaurant> search(
            @Param("q") String q,
            @Param("typeId") Integer typeId,
            Pageable pageable
    );
    // ดึงเฉพาะในรัศมี (km) และเรียงตามระยะทาง "เส้นโค้งบนทรงกลม" (Haversine)
    // NOTE: เลือกเฉพาะ r.* เท่านั้น -> JPA ไม่งอแงเรื่อง column เกิน
    @Query(value = """
        SELECT r.*,
        (6371 * 2 * ASIN(SQRT(
            POWER(SIN(RADIANS(?1 - CAST(r.latitude  AS DECIMAL(10,6))) / 2), 2) +
            COS(RADIANS(CAST(r.latitude AS DECIMAL(10,6)))) * COS(RADIANS(?1)) *
            POWER(SIN(RADIANS(?2 - CAST(r.longitude AS DECIMAL(10,6))) / 2), 2)
        ))) AS distance_km
        FROM Restaurant r
        WHERE r.latitude IS NOT NULL AND r.longitude IS NOT NULL
        HAVING distance_km <= ?3
        ORDER BY distance_km ASC
        LIMIT ?4 OFFSET ?5
    """, nativeQuery = true)
    List<Restaurant> findNear(double lat, double lon, double radiusKm, int limit, int offset);


}

package com.finalproject.Restaurant.repository;

import com.finalproject.Restaurant.model.Activity;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.*;

@Repository
public interface ActivityRepository extends JpaRepository<Activity, Integer> {

    @Query("SELECT DISTINCT a FROM Activity a " +
            "LEFT JOIN FETCH a.activityMembers am " +
            "LEFT JOIN FETCH am.member m " +
            "LEFT JOIN FETCH am.selectRestaurant sr " +
            "LEFT JOIN FETCH sr.restaurant r")
    List<Activity> findAllWithMembers();

    Activity findByActivityId(Integer activityId);

    @Query("SELECT a FROM Activity a JOIN a.activityMembers am WHERE am.member.memberId = :memberId AND am.memberStatus = 'ถูกเชิญ'")
    List<Activity> findActivitiesByInvitedMember(@Param("memberId") Integer memberId);

    // 🔎 ใช้ตอนดู Activity รายตัวให้ครบความสัมพันธ์ (member + selectRestaurant + restaurant)
    @Query("SELECT a FROM Activity a " +
            "LEFT JOIN FETCH a.activityMembers am " +
            "LEFT JOIN FETCH am.member m " +
            "LEFT JOIN FETCH am.selectRestaurant sr " +
            "LEFT JOIN FETCH sr.restaurant r " +
            "WHERE a.activityId = :id")
    Optional<Activity> findByIdWithMembers(@Param("id") Integer id);

    // 🧹 ใช้ลบความสัมพันธ์ใน join table ก่อนลบ Activity
    @Modifying
    @Query(value = "DELETE FROM member_join_activity WHERE activityId = :activityId", nativeQuery = true)
    void deleteMemberLinks(@Param("activityId") Integer activityId);

    List<Activity> findAllByInviteDateBeforeAndStatusPostNot(LocalDateTime now, String statusPost);

    // ✅ (ทางเลือก) Bulk update ทีเดียว เร็วกว่า แต่ข้าม lifecycle
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
      update Activity a 
         set a.statusPost = :done 
       where a.inviteDate <= :now 
         and (a.statusPost is null or a.statusPost <> :done)
      """)
    int bulkMarkFinished(LocalDateTime now, String done);

}

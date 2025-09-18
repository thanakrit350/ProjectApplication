package com.finalproject.Restaurant.repository;

import com.finalproject.Restaurant.model.ActivityMember;
import com.finalproject.Restaurant.model.Member;
import com.finalproject.Restaurant.model.SelectRestaurant;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ActivityMemberRepository extends JpaRepository<ActivityMember, Integer> {

    boolean existsByMemberAndSelectRestaurantAndMemberStatus(
            Member member,
            SelectRestaurant selectRestaurant,
            String memberStatus
    );

    // ✅ แก้ 'invited' ให้ตรงกับที่ใช้จริงในระบบ ถ้าคุณเก็บเป็น "ถูกเชิญ" ให้แก้แบบนี้:
    @Query("SELECT am FROM ActivityMember am WHERE am.member.memberId = :memberId AND am.memberStatus = 'ถูกเชิญ'")
    List<ActivityMember> findByMember_MemberId(@Param("memberId") Integer memberId);

    // ✅ เขียน query ให้สั้นลง
    @Query("SELECT am FROM Activity a JOIN a.activityMembers am " +
            "WHERE a.activityId = :activityId AND am.member.memberId = :memberId")
    ActivityMember findByActivityAndMember(@Param("activityId") Integer activityId,
                                           @Param("memberId") Integer memberId);
}

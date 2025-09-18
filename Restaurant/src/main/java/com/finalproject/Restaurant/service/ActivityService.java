package com.finalproject.Restaurant.service;

import com.finalproject.Restaurant.model.*;
import com.finalproject.Restaurant.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.*;

import static org.springframework.http.HttpStatus.*;

@Service
public class ActivityService {

    @Autowired private ActivityRepository activityRepository;
    @Autowired private ActivityMemberRepository activityMemberRepository;
    @Autowired private MemberRepository memberRepository;
    @Autowired private RestaurantRepository restaurantRepository;
    @Autowired private SelectRestaurantRepository selectRestaurantRepository;
    @Autowired private RestaurantTypeRepository restaurantTypeRepository; // ✅ ใช้สำหรับ default

    // ---------- Public APIs ----------

    public List<Activity> getAllActivities() {
        return activityRepository.findAllWithMembers();
    }

    public Activity getActivityById(Integer id) {
        return activityRepository.findByIdWithMembers(id).orElse(null);
    }

    public Activity createActivity(Activity activity) {
        normalizeReferences(activity);
        attachRestaurantTypeIfMissing(activity);
        ensureOrDefaultRestaurantType(activity);           // ✅ เปลี่ยนมาใส่ default
        return activityRepository.save(activity);
    }

    @Transactional
    public boolean deleteActivity(Integer id) {
        if (!activityRepository.existsById(id)) return false;

        activityRepository.findByIdWithMembers(id).ifPresent(a -> {
            if (a.getActivityMembers() != null) a.getActivityMembers().clear();
        });

        activityRepository.deleteMemberLinks(id);
        activityRepository.deleteById(id);
        return true;
    }

    @Transactional
    public Activity updateActivity(Integer id, Activity updatedActivity) {
        return activityRepository.findById(id).map(existing -> {
            existing.setActivityName(updatedActivity.getActivityName());
            existing.setDescriptionActivity(updatedActivity.getDescriptionActivity());
            existing.setInviteDate(updatedActivity.getInviteDate());
            existing.setPostDate(updatedActivity.getPostDate());
            existing.setStatusPost(updatedActivity.getStatusPost());
            existing.setIsOwnerSelect(updatedActivity.getIsOwnerSelect());
            existing.setActivityMembers(updatedActivity.getActivityMembers());
            existing.setRestaurant(updatedActivity.getRestaurant());
            existing.setRestaurantType(updatedActivity.getRestaurantType());

            normalizeReferences(existing);
            attachRestaurantTypeIfMissing(existing);
            ensureOrDefaultRestaurantType(existing);       // ✅ เปลี่ยนมาใส่ default

            return activityRepository.save(existing);
        }).orElse(null);
    }

    @Transactional
    public Activity createActivityWithMembers(Activity activity) {
        if (activity.getActivityMembers() != null) {
            for (ActivityMember am : activity.getActivityMembers()) {
                if (am.getMember() == null || am.getMember().getMemberId() == null) {
                    throw new ResponseStatusException(BAD_REQUEST, "memberId is required");
                }
                am.setMember(memberRepository.getReferenceById(am.getMember().getMemberId()));
                am.setSelectRestaurant(null);
            }
        }

        normalizeReferences(activity);
        attachRestaurantTypeIfMissing(activity);
        ensureOrDefaultRestaurantType(activity);           // ✅ เปลี่ยนมาใส่ default

        return activityRepository.save(activity);
    }

    // ---------- Select Choice ----------

    @Transactional
    public Activity selectRestaurantForMember(Integer activityId, Integer memberId, Integer restaurantId) {
        Activity activity = activityRepository.findByIdWithMembers(activityId)
                .orElseThrow(() -> new ResponseStatusException(NOT_FOUND, "Activity not found"));

        if (activity.getRestaurant() != null) {
            throw new ResponseStatusException(BAD_REQUEST, "ร้านถูกกำหนดแล้ว ไม่สามารถเลือกได้");
        }

        Date invite = activity.getInviteDate();
        if (invite == null) {
            throw new ResponseStatusException(BAD_REQUEST, "กิจกรรมไม่มีวันนัดหมาย");
        }
        Calendar cal = Calendar.getInstance();
        cal.setTime(invite);
        cal.add(Calendar.HOUR_OF_DAY, -2);
        Date closeAt = cal.getTime();
        if (new Date().after(closeAt)) {
            throw new ResponseStatusException(BAD_REQUEST, "หมดเวลาการเลือกร้าน");
        }

        ActivityMember target = activity.getActivityMembers().stream()
                .filter(am -> am.getMember() != null
                        && am.getMember().getMemberId().equals(memberId))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(FORBIDDEN, "ไม่ใช่สมาชิกของกิจกรรมนี้"));

        Restaurant restaurant = restaurantRepository.findById(restaurantId)
                .orElseThrow(() -> new ResponseStatusException(NOT_FOUND, "Restaurant not found"));

        SelectRestaurant sr = selectRestaurantRepository
                .findByRestaurant_RestaurantId(restaurantId)
                .orElseGet(() -> {
                    SelectRestaurant s = new SelectRestaurant();
                    s.setRestaurant(restaurant);
                    s.setStatusSelect(true);
                    return selectRestaurantRepository.save(s);
                });

        target.setSelectRestaurant(sr);
        activityMemberRepository.save(target);

        return activityRepository.findByIdWithMembers(activityId)
                .orElseThrow(() -> new ResponseStatusException(NOT_FOUND));
    }

    // ---------- Helpers ----------

    /** ทำให้ reference ที่ส่งมาโดย client กลายเป็น managed entity ของ JPA */
    private void normalizeReferences(Activity a) {
        if (a == null) return;

        if (a.getRestaurantType() != null && a.getRestaurantType().getRestaurantTypeId() != null) {
            a.setRestaurantType(
                    restaurantTypeRepository.getReferenceById(a.getRestaurantType().getRestaurantTypeId())
            );
        }

        if (a.getRestaurant() != null && a.getRestaurant().getRestaurantId() != null) {
            a.setRestaurant(
                    restaurantRepository.getReferenceById(a.getRestaurant().getRestaurantId())
            );
        }
    }

    /** ถ้าเลือก "ร้าน" มา แต่ Activity ไม่มี restaurantType -> เติมจากร้านให้ (ถ้าร้านมี) */
    private void attachRestaurantTypeIfMissing(Activity a) {
        if (a == null) return;
        if (a.getRestaurantType() != null) return;
        if (a.getRestaurant() == null || a.getRestaurant().getRestaurantId() == null) return;

        restaurantRepository.findById(a.getRestaurant().getRestaurantId()).ifPresent(r -> {
            a.setRestaurant(r); // managed entity
            a.setRestaurantType(r.getRestaurantType()); // อาจเป็น null ถ้าร้านยังไม่กำหนด
        });
    }

    /** ถ้ายังไม่มี type หลังจากพยายามแนบจากร้าน → ใส่ default "ไม่ระบุ" */
    private void ensureOrDefaultRestaurantType(Activity a) {
        if (a.getRestaurantType() == null) {
            RestaurantType def = restaurantTypeRepository.findByTypeName("ไม่ระบุ")
                    .orElseThrow(() ->
                            new IllegalStateException("Default RestaurantType 'ไม่ระบุ' is missing"));
            a.setRestaurantType(def);
        }
    }
}

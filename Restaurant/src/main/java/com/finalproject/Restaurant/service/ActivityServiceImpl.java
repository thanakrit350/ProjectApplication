package com.finalproject.Restaurant.service;

import com.finalproject.Restaurant.model.Activity;
import com.finalproject.Restaurant.repository.ActivityRepository;
import jakarta.transaction.Transactional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;

@Service
public class ActivityServiceImpl extends ActivityService {

    @Autowired
    private ActivityRepository activityRepository;

    @Override
    public List<Activity> getAllActivities() {
        return activityRepository.findAll();
    }

    @Override
    public Activity getActivityById(Integer id) {
        return activityRepository.findById(id).orElse(null);
    }

    @Override
    public Activity createActivity(Activity activity) {
        return activityRepository.save(activity);
    }

    @Override
    public Activity updateActivity(Integer id, Activity activity) {
        if (activityRepository.existsById(id)) {
            activity.setActivityId(id);
            return activityRepository.save(activity);
        }
        return null;
    }

    @Override
    @Transactional
    public boolean deleteActivity(Integer id) {
        if (!activityRepository.existsById(id)) {
            return false;
        }

        // 1) ลบความสัมพันธ์ในตารางเชื่อมก่อน
        activityRepository.deleteMemberLinks(id);

        // 2) ค่อยลบ Activity
        activityRepository.deleteById(id);
        return true;
    }
}

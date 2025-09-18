package com.finalproject.Restaurant.controller;

import com.finalproject.Restaurant.dto.SelectRestaurantRequest;
import com.finalproject.Restaurant.model.Activity;
import com.finalproject.Restaurant.service.ActivityService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/activities")
@CrossOrigin(origins = "*")
public class    ActivityController {

    @Autowired
    private ActivityService activityService;

    @GetMapping
    public ResponseEntity<List<Activity>> getListActivity() {
        return ResponseEntity.ok(activityService.getAllActivities());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Activity> getActivityById(@PathVariable Integer id) {
        Activity activity = activityService.getActivityById(id);
        return activity != null ? ResponseEntity.ok(activity) : ResponseEntity.notFound().build();
    }

    @PostMapping
    public ResponseEntity<Activity> doAddPost(@RequestBody Activity activity) {
        Activity createdActivity = activityService.createActivityWithMembers(activity);
        return ResponseEntity.ok(createdActivity);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> doRemoveActivity(@PathVariable Integer id) {
        boolean deleted = activityService.deleteActivity(id);
        return deleted ? ResponseEntity.noContent().build() : ResponseEntity.notFound().build();
    }

    @PutMapping("/{id}")
    public ResponseEntity<Activity> doEditActivityDetail(@PathVariable Integer id, @RequestBody Activity activity) {
        Activity updated = activityService.updateActivity(id, activity);
        return updated != null ? ResponseEntity.ok(updated) : ResponseEntity.notFound().build();
    }

    // ✅ เลือกร้านอาหารสำหรับผู้เข้าร่วม
    @PostMapping("/{activityId}/select-restaurant")
    public ResponseEntity<Activity> doSelectChoice(
            @PathVariable Integer activityId,
            @RequestBody SelectRestaurantRequest req) {
        Activity updated = activityService.selectRestaurantForMember(
                activityId, req.getMemberId(), req.getRestaurantId());
        return ResponseEntity.ok(updated);
    }
}



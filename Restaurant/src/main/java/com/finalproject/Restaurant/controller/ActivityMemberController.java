package com.finalproject.Restaurant.controller;

import com.finalproject.Restaurant.model.ActivityMember;
import com.finalproject.Restaurant.service.ActivityMemberService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/activity-members")
@CrossOrigin(origins = "*")
public class ActivityMemberController {

    @Autowired
    private ActivityMemberService activityMemberService;

    @GetMapping
    public ResponseEntity<List<ActivityMember>> getAllActivityMembers() {
        return ResponseEntity.ok(activityMemberService.getAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<ActivityMember> getActivityMemberById(@PathVariable Integer id) {
        ActivityMember member = activityMemberService.getById(id);
        return member != null ? ResponseEntity.ok(member) : ResponseEntity.notFound().build();
    }

    @GetMapping("/member/{memberId}")
    public ResponseEntity<List<ActivityMember>> getByMemberId(@PathVariable Integer memberId) {
        return ResponseEntity.ok(activityMemberService.getByMemberId(memberId));
    }

    @PostMapping
    public ResponseEntity<ActivityMember> createActivityMember(@RequestBody ActivityMember activityMember) {
        return ResponseEntity.ok(activityMemberService.create(activityMember));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteActivityMember(@PathVariable Integer id) {
        boolean deleted = activityMemberService.delete(id);
        return deleted ? ResponseEntity.noContent().build() : ResponseEntity.notFound().build();
    }
}

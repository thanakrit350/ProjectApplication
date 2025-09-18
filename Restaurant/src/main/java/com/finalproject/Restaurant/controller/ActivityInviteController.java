package com.finalproject.Restaurant.controller;

import com.finalproject.Restaurant.model.Activity;
import com.finalproject.Restaurant.model.ActivityMember;
import com.finalproject.Restaurant.model.Member;
import com.finalproject.Restaurant.repository.ActivityMemberRepository;
import com.finalproject.Restaurant.repository.ActivityRepository;
import com.finalproject.Restaurant.repository.MemberRepository;
import jakarta.transaction.Transactional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Date;
import java.util.List;

@RestController
@RequestMapping("/activity-invites")
@CrossOrigin(origins = "*")
public class ActivityInviteController {

    @Autowired
    private ActivityMemberRepository activityMemberRepo;

    @Autowired
    private MemberRepository memberRepo;

    @Autowired
    private ActivityRepository activityRepo;

    // POST /activity-invites/invite
    @PostMapping("/invite")
    public ResponseEntity<String> inviteByEmail(
            @RequestParam Integer activityId,
            @RequestParam String email
    ) {
        Member invitedMember = memberRepo.findByEmail(email);
        Activity activity = activityRepo.findByActivityId(activityId);

        if (invitedMember == null || activity == null) {
            return ResponseEntity.badRequest().body("ไม่พบสมาชิกหรือกิจกรรม");
        }

        boolean alreadyInvited = activity.getActivityMembers().stream()
                .anyMatch(am -> am.getMember().getMemberId().equals(invitedMember.getMemberId())
                        && "ถูกเชิญ".equals(am.getMemberStatus()));


        if (alreadyInvited) {
            return ResponseEntity.badRequest().body("เคยเชิญอีเมลนี้ไปแล้ว");
        }

        ActivityMember newInvite = new ActivityMember();
        newInvite.setMember(invitedMember);
        newInvite.setJoinDate(new Date());
        newInvite.setMemberStatus("ถูกเชิญ");
        newInvite.setSelectRestaurant(null);

        activityMemberRepo.save(newInvite);

        activity.getActivityMembers().add(newInvite);
        activityRepo.save(activity);

        return ResponseEntity.ok("ส่งคำเชิญเรียบร้อย");
    }


    // GET /activity-invites/invited/{memberId}
    @GetMapping("/invited/{memberId}")
    public ResponseEntity<List<Activity>> getInvitedActivities(@PathVariable Integer memberId) {
        List<Activity> invitedActivities = activityRepo.findActivitiesByInvitedMember(memberId);
        return ResponseEntity.ok(invitedActivities);
    }

    // PUT /activity-invites/respond
    @PutMapping("/respond")
    public ResponseEntity<String> doJoinActivity(
            @RequestParam Integer activityId,
            @RequestParam Integer memberId,
            @RequestParam String response // "เข้าร่วม" or "ปฏิเสธ"
    ) {
        Activity activity = activityRepo.findByActivityId(activityId);
        ActivityMember invite = activityMemberRepo.findByActivityAndMember(activityId, memberId);

        if (invite == null || activity == null) {
            return ResponseEntity.badRequest().body("ไม่พบคำเชิญหรือกิจกรรม");
        }

        if (response.equals("ปฏิเสธ")) {
            // ลบออกจาก activity และจาก repo
            activity.getActivityMembers().removeIf(am -> am.getMember().getMemberId().equals(memberId));
            activityRepo.save(activity);
            activityMemberRepo.delete(invite);
            return ResponseEntity.ok("ปฏิเสธและลบออกจากปาร์ตี้แล้ว");
        }

        invite.setMemberStatus("เข้าร่วม");
        activityMemberRepo.save(invite);
        return ResponseEntity.ok("ตอบกลับเรียบร้อย");
    }

    @PostMapping("/invite-phone")
    public ResponseEntity<String> inviteByPhone(
            @RequestParam Integer activityId,
            @RequestParam String phone
    ) {
        if (phone == null || phone.trim().isEmpty()) {
            return ResponseEntity.badRequest().body("กรุณาระบุเบอร์โทร");
        }

        // หากต้องการ normalize เบอร์ (ตัดเว้นวรรค/ขีด)
        String normalized = phone.trim().replaceAll("[\\s-]", "");

        Member invitedMember = memberRepo.findByPhoneNumber(normalized);
        Activity activity = activityRepo.findByActivityId(activityId);

        if (invitedMember == null || activity == null) {
            return ResponseEntity.badRequest().body("ไม่พบสมาชิกจากเบอร์นี้หรือไม่พบบกิจกรรม");
        }

        // เช็คว่ามีอยู่แล้วหรือยัง
        ActivityMember existing = activity.getActivityMembers().stream()
                .filter(am -> am.getMember().getMemberId().equals(invitedMember.getMemberId()))
                .findFirst()
                .orElse(null);

        if (existing != null) {
            if ("เข้าร่วม".equals(existing.getMemberStatus())) {
                return ResponseEntity.badRequest().body("ผู้ใช้นี้เข้าร่วมกิจกรรมอยู่แล้ว");
            }
            if ("ถูกเชิญ".equals(existing.getMemberStatus())) {
                return ResponseEntity.badRequest().body("เคยเชิญเบอร์นี้ไปแล้ว");
            }
        }

        ActivityMember newInvite = new ActivityMember();
        newInvite.setMember(invitedMember);
        newInvite.setJoinDate(new Date());
        newInvite.setMemberStatus("ถูกเชิญ");
        newInvite.setSelectRestaurant(null);

        activityMemberRepo.save(newInvite);

        activity.getActivityMembers().add(newInvite);
        activityRepo.save(activity);

        return ResponseEntity.ok("ส่งคำเชิญด้วยเบอร์โทรเรียบร้อย");
    }

}

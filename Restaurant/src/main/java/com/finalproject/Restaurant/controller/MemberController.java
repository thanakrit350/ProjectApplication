package com.finalproject.Restaurant.controller;

import com.finalproject.Restaurant.model.LoginResponse;
import com.finalproject.Restaurant.model.Member;
import com.finalproject.Restaurant.service.MemberService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.*;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.*;

@RestController
@RequestMapping("/members")
public class MemberController {

    @Autowired private MemberService memberService;

    // ใช้ path เดียวกับ ImageMemberController
    private static final String UPLOAD_DIR =
            "C:/final/Restaurant/src/main/java/com/finalproject/Restaurant/ImgMember/";
    private static final String PUBLIC_PREFIX = "/imgmember/"; // path ที่ client ใช้เรียก

    @GetMapping
    public ResponseEntity<List<Member>> getAllMembers() {
        try {
            List<Member> members = memberService.getAllMembers();
            members.forEach(m -> m.setPassword(null));
            return ResponseEntity.ok(members);
        } catch (Exception e) {
            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<Member> getMemberById(@PathVariable Integer id) {
        try {
            Member member = memberService.getMemberById(id);
            member.setPassword(null);
            return ResponseEntity.ok(member);
        } catch (Exception e) {
            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Member> doRegisterMember(@RequestBody Member member) {
        try {
            Member saved = memberService.createMember(member);
            saved.setPassword(null);
            return new ResponseEntity<>(saved, HttpStatus.CREATED);
        } catch (Exception e) {
            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    /**
     * อัปเดตข้อมูลสมาชิก + อัปโหลดรูปใหม่ (ถ้ามี)
     * - ถ้าอัปโหลดไฟล์ใหม่: ลบไฟล์รูปเก่าออกให้ด้วย
     * - (옵ชัน) ถ้าส่ง removeImage=true โดยไม่อัปโหลดไฟล์ใหม่ จะลบรูปเก่าและล้างค่า profileImage
     */
    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> EditProfileData(
            @PathVariable Integer id,
            @RequestParam String firstName,
            @RequestParam String lastName,
            @RequestParam @DateTimeFormat(pattern = "yyyy-MM-dd") Date birthDate,
            @RequestParam String gender,
            @RequestParam String email,
            @RequestParam(required = false) String password, // optional
            @RequestParam String phoneNumber,
            @RequestParam(value = "profileImage", required = false) MultipartFile file,
            @RequestParam(value = "removeImage", required = false, defaultValue = "false") boolean removeImage
    ) {
        try {
            Member existing = memberService.getMemberById(id);

            Member incoming = new Member();
            incoming.setMemberId(id);
            incoming.setFirstName(firstName);
            incoming.setLastName(lastName);
            incoming.setBirthDate(birthDate);
            incoming.setGender(gender);
            incoming.setEmail(email);
            incoming.setPassword(password); // service ควรเช็ค null/ว่างเพื่อตรึงค่าเดิม
            incoming.setPhoneNumber(phoneNumber);
            incoming.setProfileImage(existing.getProfileImage()); // default: คงของเดิม

            // กรณีผู้ใช้ติ๊ก "ลบรูป" แต่ไม่ได้อัปโหลดใหม่
            if (removeImage && (file == null || file.isEmpty())) {
                deleteOldImageIfExists(existing.getProfileImage());
                incoming.setProfileImage(null);
            }

            // อัปโหลดไฟล์ใหม่ → ลบของเก่าก่อน แล้วเซ็ต path ใหม่
            if (file != null && !file.isEmpty()) {
                // ลบไฟล์เก่า
                deleteOldImageIfExists(existing.getProfileImage());

                String fileName = UUID.randomUUID() + "_" + StringUtils.cleanPath(file.getOriginalFilename());
                File saveFile = new File(UPLOAD_DIR + fileName);
                try (FileOutputStream fout = new FileOutputStream(saveFile)) {
                    fout.write(file.getBytes());
                }
                incoming.setProfileImage(PUBLIC_PREFIX + fileName);
            }

            Member updated = memberService.updateMember(incoming);
            updated.setPassword(null);
            return ResponseEntity.ok(updated);

        } catch (IOException e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("เกิดข้อผิดพลาดในการบันทึกรูปภาพ");
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("ไม่สามารถอัปเดตสมาชิกได้");
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteMember(@PathVariable Integer id) {
        try {
            memberService.deleteMember(id);
            return new ResponseEntity<>(HttpStatus.NO_CONTENT);
        } catch (Exception e) {
            return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @GetMapping("/email/{email}")
    public ResponseEntity<Member> getMemberByEmail(@PathVariable String email) {
        try {
            Member m = memberService.getMemberByEmail(email);
            if (m == null) return new ResponseEntity<>(HttpStatus.NOT_FOUND);
            m.setPassword(null);
            return ResponseEntity.ok(m);
        } catch (Exception e) {
            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @PostMapping("/login")
    public ResponseEntity<?> doLoginMember(@RequestParam String email,
                                   @RequestParam String password) {
        try {
            Member m = memberService.login(email, password);
            m.setPassword(null);
            return ResponseEntity.ok(new LoginResponse(true, "เข้าสู่ระบบสำเร็จ", m));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new LoginResponse(false, ex.getMessage(), null));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new LoginResponse(false, "เกิดข้อผิดพลาด", null));
        }
    }

    // ---------- helpers ----------
    /** ลบไฟล์รูปเก่า ถ้า path เดิมเป็น /imgmember/xxx ให้ map ไปยัง UPLOAD_DIR แล้วลบอย่างปลอดภัย */
    private void deleteOldImageIfExists(String profileImagePath) {
        if (profileImagePath == null || profileImagePath.isBlank()) return;

        // ยอมรับเฉพาะไฟล์ภายใต้โฟลเดอร์ของเราเท่านั้น
        if (!profileImagePath.startsWith(PUBLIC_PREFIX)) return;

        String filename = profileImagePath.substring(PUBLIC_PREFIX.length());
        File old = new File(UPLOAD_DIR + filename);
        if (old.exists() && old.isFile()) {
            try {
                boolean ok = old.delete();
                if (!ok) {
                    // ถ้าลบไม่สำเร็จ อาจล็อกไว้เฉย ๆ (ไม่ควรล้มทั้ง request)
                    System.err.println("Cannot delete old image: " + old.getAbsolutePath());
                }
            } catch (SecurityException se) {
                System.err.println("SecurityException deleting file: " + se.getMessage());
            }
        }
    }
}

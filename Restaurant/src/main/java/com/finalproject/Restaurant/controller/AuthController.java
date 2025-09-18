package com.finalproject.Restaurant.controller;

import com.finalproject.Restaurant.model.Member;
import com.finalproject.Restaurant.service.MemberService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class AuthController {

    private final MemberService memberService;

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Member req) {
        try {
            Member saved = memberService.register(req);
            saved.setPassword(null); // ไม่ส่ง hash กลับ
            return ResponseEntity.ok(saved);
        } catch (IllegalArgumentException ex) {
            // เช่น อีเมลซ้ำ/ข้อมูลไม่ครบ
            return ResponseEntity.badRequest().body(ex.getMessage());
        } catch (Exception ex) {
            return ResponseEntity.internalServerError().body("สมัครสมาชิกไม่สำเร็จ");
        }
    }

    // login ด้วยอีเมล
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestParam String email,
                                   @RequestParam String password) {
        try {
            Member m = memberService.login(email, password); // <<— แก้จาก loginByEmail เป็น login
            m.setPassword(null);
            return ResponseEntity.ok(m);
        } catch (IllegalArgumentException ex) {
            // อีเมลไม่พบ หรือรหัสผ่านไม่ถูก
            return ResponseEntity.badRequest().body(ex.getMessage());
        } catch (Exception ex) {
            return ResponseEntity.internalServerError().body("ไม่สามารถเข้าสู่ระบบได้");
        }
    }

}

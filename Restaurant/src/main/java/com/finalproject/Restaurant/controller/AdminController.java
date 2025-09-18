package com.finalproject.Restaurant.controller;

import com.finalproject.Restaurant.model.Admin;
import com.finalproject.Restaurant.service.AdminService;
import jakarta.servlet.http.HttpSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/admin")
public class AdminController {

    public static final String SESSION_KEY = "ADMIN_ID";

    @Autowired private AdminService adminService;

    // ----- DTO -----
    public record LoginReq(String username, String password) {}
    public record AdminView(Integer adminId, String adminUserName) {
        static AdminView of(Admin a){ return new AdminView(a.getAdminId(), a.getAdminUserName()); }
    }

    @PostMapping(value="/login", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> doLoginAdmin(@RequestBody LoginReq req, HttpSession session){
        try{
            if(req.username()==null || req.username().isBlank() ||
                    req.password()==null || req.password().isBlank()){
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("กรอกข้อมูลให้ครบ");
            }
            Admin a = adminService.authenticate(req.username(), req.password());
            session.setAttribute(SESSION_KEY, a.getAdminId());
            return ResponseEntity.ok(AdminView.of(a));
        }catch(IllegalArgumentException ex){
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Unauthorized");
        }catch(Exception e){
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("เกิดข้อผิดพลาด");
        }
    }

    @GetMapping("/me")
    public ResponseEntity<?> me(HttpSession session){
        Integer id = (Integer) session.getAttribute(SESSION_KEY);
        if(id==null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        Admin a = adminService.get(id);
        if(a==null) { session.invalidate(); return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build(); }
        return ResponseEntity.ok(AdminView.of(a));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(HttpSession session){
        session.invalidate();
        return ResponseEntity.noContent().build();
    }

    /** ใช้ครั้งเดียวเพื่อสร้างผู้ใช้เริ่มต้น ถ้าไม่มี (ปิดได้หลัง seed เสร็จ) */
    @PostMapping("/bootstrap")
    public ResponseEntity<?> bootstrap(@RequestParam(defaultValue="admin") String username,
                                       @RequestParam(defaultValue="admin1234") String password){
        try{
            // ถ้ามีอยู่แล้ว ไม่ต้องสร้างซ้ำ
            return ResponseEntity.ok(AdminView.of(adminService.create(username, password)));
        }catch(Exception e){
            return ResponseEntity.status(HttpStatus.CONFLICT).body("อาจมีผู้ใช้นี้แล้ว");
        }
    }
}

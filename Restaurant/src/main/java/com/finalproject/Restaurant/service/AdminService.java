package com.finalproject.Restaurant.service;

import com.finalproject.Restaurant.model.Admin;
import com.finalproject.Restaurant.repository.AdminRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class AdminService {

    @Autowired private AdminRepository adminRepository;
    @Autowired private PasswordService passwordService;

    public Admin create(String username, String rawPassword){
        Admin a = new Admin();
        a.setAdminUserName(username.trim());
        a.setAdminPassword(passwordService.encodePassword(rawPassword));
        return adminRepository.save(a);
    }

    public Admin authenticate(String username, String rawPassword){
        Admin a = adminRepository.findByAdminUserNameIgnoreCase(username.trim())
                .orElseThrow(() -> new IllegalArgumentException("ไม่พบผู้ใช้"));
        if(!passwordService.matches(rawPassword, a.getAdminPassword())){
            throw new IllegalArgumentException("รหัสผ่านไม่ถูกต้อง");
        }
        return a;
    }

    public Admin get(Integer id){
        return adminRepository.findById(id).orElse(null);
    }
}

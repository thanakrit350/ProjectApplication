package com.finalproject.Restaurant.service;

import org.springframework.stereotype.Service;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;

@Service
public class PasswordService {

    // เก็บแบบมีเวอร์ชัน: v1$<saltB64>$<hashB64>
    public String encodePassword(String rawPassword) {
        try {
            String salt = generateSalt();
            String hash = sha256Base64(rawPassword + salt);
            return "v1" + "$" + salt + "$" + hash;
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("เข้ารหัสรหัสผ่านล้มเหลว", e);
        }
    }

    public boolean matches(String rawPassword, String encodedPassword) {
        try {
            if (encodedPassword == null) return false;
            String[] parts = encodedPassword.split("\\$");
            if (parts.length != 3 || !"v1".equals(parts[0])) return false;

            String salt = parts[1];
            String expectedHash = parts[2];
            String actualHash = sha256Base64(rawPassword + salt);
            return expectedHash.equals(actualHash);
        } catch (NoSuchAlgorithmException e) {
            return false;
        }
    }

    private String generateSalt() {
        byte[] salt = new byte[16];
        new SecureRandom().nextBytes(salt);
        return Base64.getEncoder().encodeToString(salt);
    }

    private String sha256Base64(String in) throws NoSuchAlgorithmException {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        return Base64.getEncoder().encodeToString(md.digest(in.getBytes()));
    }
}

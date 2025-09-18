package com.finalproject.Restaurant.repository;

import com.finalproject.Restaurant.model.Admin;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface AdminRepository extends JpaRepository<Admin, Integer> {
    Optional<Admin> findByAdminUserNameIgnoreCase(String adminUserName);
}

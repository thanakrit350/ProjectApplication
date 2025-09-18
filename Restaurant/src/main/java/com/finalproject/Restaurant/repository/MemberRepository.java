package com.finalproject.Restaurant.repository;

import com.finalproject.Restaurant.model.Member;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MemberRepository extends JpaRepository<Member, Integer > {
    Member findByEmail(String email);

    Member findByPhoneNumber(String phoneNumber);



}

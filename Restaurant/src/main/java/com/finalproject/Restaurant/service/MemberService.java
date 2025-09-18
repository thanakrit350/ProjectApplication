package com.finalproject.Restaurant.service;

import com.finalproject.Restaurant.model.Member;

import java.util.List;
import java.util.Optional;

public interface MemberService {

    List<Member> getAllMembers();

    Member getMemberById(Integer id);

    Member createMember(Member member);

    Member updateMember(Member member);

    Member getMemberByEmail(String email);

    void deleteMember(Integer id);

    Member register(Member member);              // เหมือน createMember แต่ตั้งใจใช้กับสมัครสมาชิก
    Member login(String email, String rawPassword);


}

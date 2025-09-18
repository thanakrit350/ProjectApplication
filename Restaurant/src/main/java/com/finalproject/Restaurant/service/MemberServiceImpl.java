package com.finalproject.Restaurant.service;

import com.finalproject.Restaurant.model.Member;
import com.finalproject.Restaurant.repository.MemberRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class MemberServiceImpl implements MemberService {

    @Autowired private MemberRepository memberRepository;
    @Autowired private PasswordService passwordService;

    // รูปแบบที่เราสร้างจาก PasswordService คือ "salt:hash"
    private boolean isEncoded(String s) {
        if (s == null) return false;
        String[] parts = s.split(":");
        return parts.length == 2 && !parts[0].isBlank() && !parts[1].isBlank();
    }

    @Override
    public List<Member> getAllMembers() { return memberRepository.findAll(); }

    @Override
    public Member getMemberById(Integer id) {
        Optional<Member> member = memberRepository.findById(id);
        if (member.isPresent()) return member.get();
        throw new RuntimeException("ไม่พบสมาชิก");
    }

    @Override
    public Member createMember(Member member) {
        if (member.getEmail() != null && memberRepository.findByEmail(member.getEmail()) != null) {
            throw new IllegalArgumentException("อีเมลนี้ถูกใช้งานแล้ว");
        }
        String raw = member.getPassword();
        if (raw == null || raw.isBlank()) {
            throw new IllegalArgumentException("ต้องกรอกรหัสผ่าน");
        }
        member.setPassword(passwordService.encodePassword(raw));
        return memberRepository.save(member);
    }

    @Override
    public Member updateMember(Member incoming) {
        Integer id = incoming.getMemberId();
        if (id == null || !memberRepository.existsById(id)) {
            throw new RuntimeException("ไม่พบสมาชิก");
        }

        Member stored = memberRepository.findById(id).orElseThrow();

        if (incoming.getEmail() != null && !incoming.getEmail().equals(stored.getEmail())) {
            if (memberRepository.findByEmail(incoming.getEmail()) != null) {
                throw new IllegalArgumentException("อีเมลนี้ถูกใช้งานแล้ว");
            }
        }

        // รหัสผ่าน: ถ้าไม่ส่ง/ว่าง -> คงเดิม, ถ้าส่ง raw -> เข้ารหัสใหม่
        String newPass = incoming.getPassword();
        if (newPass == null || newPass.isBlank()) {
            incoming.setPassword(stored.getPassword());
        } else if (!isEncoded(newPass)) {
            incoming.setPassword(passwordService.encodePassword(newPass));
        }

        // คืนค่าที่ไม่ได้ส่งมาเป็นของเดิม
        if (incoming.getFirstName() == null)   incoming.setFirstName(stored.getFirstName());
        if (incoming.getLastName() == null)    incoming.setLastName(stored.getLastName());
        if (incoming.getEmail() == null)       incoming.setEmail(stored.getEmail());
        if (incoming.getPhoneNumber() == null) incoming.setPhoneNumber(stored.getPhoneNumber());
        if (incoming.getGender() == null)      incoming.setGender(stored.getGender());
        if (incoming.getBirthDate() == null)   incoming.setBirthDate(stored.getBirthDate());
        if (incoming.getProfileImage() == null)incoming.setProfileImage(stored.getProfileImage());

        return memberRepository.save(incoming);
    }

    @Override
    public void deleteMember(Integer id) {
        if (!memberRepository.existsById(id)) throw new RuntimeException("ไม่พบสมาชิก");
        memberRepository.deleteById(id);
    }

    @Override
    public Member getMemberByEmail(String email) { return memberRepository.findByEmail(email); }

    @Override
    public Member register(Member member) { return createMember(member); }

    @Override
    public Member login(String email, String rawPassword) {
        Member m = memberRepository.findByEmail(email);
        if (m == null) throw new IllegalArgumentException("ไม่พบบัญชีผู้ใช้");
        if (!passwordService.matches(rawPassword, m.getPassword())) {
            throw new IllegalArgumentException("อีเมลหรือรหัสผ่านไม่ถูกต้อง");
        }
        return m;
    }
}

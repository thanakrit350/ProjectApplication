package com.finalproject.Restaurant.service;

import com.finalproject.Restaurant.model.ActivityMember;
import com.finalproject.Restaurant.repository.ActivityMemberRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class ActivityMemberService {

    @Autowired
    private ActivityMemberRepository repository;

    public List<ActivityMember> getAll() {
        return repository.findAll();
    }

    public ActivityMember getById(Integer id) {
        return repository.findById(id).orElse(null);
    }

    public List<ActivityMember> getByMemberId(Integer memberId) {
        return repository.findByMember_MemberId(memberId);
    }

    public ActivityMember create(ActivityMember activityMember) {
        activityMember.setJoinDate(new java.util.Date()); // ตั้งเวลาเข้าร่วมตอนนี้
        return repository.save(activityMember);
    }

    public boolean delete(Integer id) {
        if (repository.existsById(id)) {
            repository.deleteById(id);
            return true;
        }
        return false;
    }
}

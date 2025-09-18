package com.finalproject.Restaurant.service;

import com.finalproject.Restaurant.model.Activity;
import com.finalproject.Restaurant.repository.ActivityRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class ActivityStatusServiceImpl implements ActivityStatusService {

    private final ActivityRepository activityRepository;

    // ✅ โซนเวลาไทย (ปรับตามที่ระบบคุณใช้)
    private static final ZoneId ZONE = ZoneId.of("Asia/Bangkok");
    private static final String DONE = "ดำเนินการเสร็จสิ้น";

    @Override
    @Transactional
    public int markOverdueActivitiesAsFinished() {

        // --------- วิธีที่ 1: อ่านรายการมาเซฟ (ปลอดภัยสุด) ---------
        LocalDateTime now = LocalDateTime.now(ZONE);
        List<Activity> list = activityRepository
                .findAllByInviteDateBeforeAndStatusPostNot(now, DONE);

        for (Activity a : list) {
            a.setStatusPost(DONE);
            // ถ้ามี field อื่นเช่น finishedAt ก็ set ได้ที่นี่
            // a.setFinishedAt(now);
        }
        activityRepository.saveAll(list);
        log.debug("Marked {} activities as finished (loop-save).", list.size());
        return list.size();

    }
}

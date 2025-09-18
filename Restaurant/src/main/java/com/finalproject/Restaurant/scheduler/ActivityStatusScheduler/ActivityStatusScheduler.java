package com.finalproject.Restaurant.scheduler.ActivityStatusScheduler;

import com.finalproject.Restaurant.service.ActivityStatusService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
@Slf4j
public class ActivityStatusScheduler {

    private final ActivityStatusService activityStatusService;

    // ✅ รันทุก ๆ 1 นาที (วินาทีที่ 0 ของทุกนาที)
    // cron: second minute hour day-of-month month day-of-week
    @Scheduled(cron = "0 * * * * *")
    @Transactional
    public void markFinishedBySchedule() {
        try {
            int updated = activityStatusService.markOverdueActivitiesAsFinished();
            if (updated > 0) {
                log.info("Scheduled job: updated {} activities to DONE.", updated);
            }
        } catch (Exception e) {
            log.error("Scheduled job failed: {}", e.getMessage(), e);
        }
    }
}
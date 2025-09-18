package com.finalproject.Restaurant.dto;

import com.fasterxml.jackson.annotation.JsonFormat;

import java.time.Instant;
import java.time.OffsetDateTime;

public class ActivityDTO {
    // แนะนำ
    @JsonFormat(shape = JsonFormat.Shape.STRING,
            pattern = "yyyy-MM-dd'T'HH:mm:ssXXX") // XXX = โชว์โซน เช่น +00:00
    private OffsetDateTime inviteDate;

}


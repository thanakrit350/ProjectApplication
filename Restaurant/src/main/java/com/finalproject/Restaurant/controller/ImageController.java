package com.finalproject.Restaurant.controller;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

@RestController
@RequestMapping("/images")
public class ImageController {

    // ตำแหน่งโฟลเดอร์รูป ต้องตรงกับของ Controller ข้างบน
    private final String imagePath = "C:/final/Restaurant/src/main/java/com/finalproject/Restaurant/Img/";

    @GetMapping("/{filename:.+}")
    public ResponseEntity<byte[]> getImage(@PathVariable String filename) {
        try {
            File file = new File(imagePath + filename);
            if (!file.exists()) return ResponseEntity.notFound().build();

            byte[] imageBytes = Files.readAllBytes(file.toPath());

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(getMediaType(filename));

            return new ResponseEntity<>(imageBytes, headers, HttpStatus.OK);
        } catch (IOException e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    private MediaType getMediaType(String filename) {
        String fn = filename.toLowerCase();
        if (fn.endsWith(".png"))  return MediaType.IMAGE_PNG;
        if (fn.endsWith(".jpg") || fn.endsWith(".jpeg")) return MediaType.IMAGE_JPEG;
        if (fn.endsWith(".gif"))  return MediaType.IMAGE_GIF;
        return MediaType.APPLICATION_OCTET_STREAM;
    }
}

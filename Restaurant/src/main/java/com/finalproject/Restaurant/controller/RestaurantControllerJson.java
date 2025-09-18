package com.finalproject.Restaurant.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.finalproject.Restaurant.dto.RestaurantUpsertRequest;
import com.finalproject.Restaurant.model.Restaurant;
import com.finalproject.Restaurant.model.RestaurantType;
import com.finalproject.Restaurant.repository.RestaurantRepository;
import com.finalproject.Restaurant.repository.RestaurantTypeRepository;
import com.finalproject.Restaurant.service.RestaurantService;
import com.finalproject.Restaurant.service.RestaurantServiceImpl;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.http.*;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.time.*;
import java.util.*;

@RestController
@RequestMapping("/restaurantsJson")
public class RestaurantControllerJson {

    @Autowired private RestaurantService restaurantService;
    @Autowired private RestaurantTypeRepository restaurantTypeRepo;
    @Autowired private RestaurantRepository restaurantRepository;

    // === ที่เก็บไฟล์รูปจริงบนเครื่อง ===
    private static final String IMAGE_DIR =
            "C:/final/Restaurant/src/main/java/com/finalproject/Restaurant/Img/";
    private static final ObjectMapper MAPPER = new ObjectMapper();

    // ====== CREATE (JSON) ======
    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> createRestaurantJson(@RequestBody RestaurantUpsertRequest req) {
        try {
            // บังคับเฉพาะฟิลด์หลัก
            if (req.restaurantName == null || req.restaurantName.trim().isEmpty())
                return new ResponseEntity<>("restaurantName is required", HttpStatus.BAD_REQUEST);
            if (req.latitude == null || req.latitude.trim().isEmpty())
                return new ResponseEntity<>("latitude is required", HttpStatus.BAD_REQUEST);
            if (req.longitude == null || req.longitude.trim().isEmpty())
                return new ResponseEntity<>("longitude is required", HttpStatus.BAD_REQUEST);

            Restaurant r = new Restaurant();
            r.setRestaurantName(req.restaurantName.trim());
            r.setRestaurantPhone(nullToEmpty(req.restaurantPhone));
            r.setDescription(nullToEmpty(req.description));
            r.setLatitude(req.latitude.trim());
            r.setLongitude(req.longitude.trim());
            r.setProvince(nullToEmpty(req.province));
            r.setDistrict(nullToEmpty(req.district));
            r.setSubdistrict(nullToEmpty(req.subdistrict));
            r.setOpenTime(parseFlexibleDateTime(req.openTime));
            r.setCloseTime(parseFlexibleDateTime(req.closeTime));

            // type (ไม่บังคับ)
            RestaurantType type = resolveType(req.restaurantTypeId, req.restaurantTypeName);
            r.setRestaurantType(type);

            Restaurant saved = restaurantService.createRestaurant(r);
            return new ResponseEntity<>(saved, HttpStatus.CREATED);
        } catch (Exception e) {
            return new ResponseEntity<>("ไม่สามารถสร้างร้านอาหารได้", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    // ====== UPDATE (JSON) ======
    @PutMapping(value = "/{id}", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> updateRestaurantJson(@PathVariable Integer id, @RequestBody RestaurantUpsertRequest req) {
        try {
            Restaurant existing = restaurantService.getRestaurantById(id);
            if (existing == null) return new ResponseEntity<>("ไม่พบร้านอาหารนี้", HttpStatus.NOT_FOUND);

            if (req.restaurantName != null) existing.setRestaurantName(req.restaurantName.trim());
            if (req.restaurantPhone != null) existing.setRestaurantPhone(req.restaurantPhone);
            if (req.description != null) existing.setDescription(req.description);
            if (req.latitude != null) existing.setLatitude(req.latitude.trim());
            if (req.longitude != null) existing.setLongitude(req.longitude.trim());
            if (req.province != null) existing.setProvince(req.province);
            if (req.district != null) existing.setDistrict(req.district);
            if (req.subdistrict != null) existing.setSubdistrict(req.subdistrict);
            if (req.openTime != null) existing.setOpenTime(parseFlexibleDateTime(req.openTime));
            if (req.closeTime != null) existing.setCloseTime(parseFlexibleDateTime(req.closeTime));

            if (req.restaurantTypeId != null || (req.restaurantTypeName != null && !req.restaurantTypeName.isBlank())) {
                existing.setRestaurantType(resolveType(req.restaurantTypeId, req.restaurantTypeName));
            }

            Restaurant updated = restaurantService.updateRestaurant(existing);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            return new ResponseEntity<>("ไม่สามารถอัปเดตร้านอาหารได้", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    // ====== REPLACE IMAGES: ลบรูปเก่าทั้งหมดแล้วแทนที่ด้วยรูปใหม่ ======
    @PutMapping(value = "/{id}/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> replaceImages(
            @PathVariable Integer id,
            @RequestParam(value = "files", required = false) List<MultipartFile> files,
            @RequestParam(value = "file",  required = false) MultipartFile fileSingle
    ) {
        try {
            Restaurant r = restaurantService.getRestaurantById(id);
            if (r == null) return new ResponseEntity<>("ไม่พบร้านอาหารนี้", HttpStatus.NOT_FOUND);

            // 1) ลบไฟล์เก่าทั้งหมด
            for (String url : parseImageUrls(r.getRestaurantImg())) {
                String filename = StringUtils.getFilename(url);
                if (filename != null && !filename.isBlank()) {
                    File f = new File(IMAGE_DIR + filename);
                    if (f.exists()) {
                        try { f.delete(); } catch (Exception ignore) {}
                    }
                }
            }

            // 2) รวมไฟล์ใหม่
            List<MultipartFile> all = new ArrayList<>();
            if (files != null) all.addAll(files);
            if (fileSingle != null && !fileSingle.isEmpty()) all.add(fileSingle);

            // 3) เซฟไฟล์ใหม่
            List<String> newUrls = saveFiles(all);

            // 4) บันทึกเป็น JSON array (หรือ null ถ้าไม่ส่งไฟล์)
            r.setRestaurantImg(newUrls.isEmpty() ? null : MAPPER.writeValueAsString(newUrls));

            Restaurant updated = restaurantService.updateRestaurant(r);
            return ResponseEntity.ok(updated);

        } catch (IOException e) {
            return new ResponseEntity<>("อัปโหลดรูปไม่สำเร็จ", HttpStatus.INTERNAL_SERVER_ERROR);
        } catch (Exception e) {
            return new ResponseEntity<>("ไม่สามารถแทนที่รูปได้", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    // ====== ค้นหา “ใกล้ฉัน” ======
    @GetMapping("/near")
    public ResponseEntity<List<Restaurant>> near(
            @RequestParam double lat,
            @RequestParam double lon,
            @RequestParam(defaultValue = "5") double radiusKm,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "30") int size
    ) {
        int offset = page * size;
        return ResponseEntity.ok(restaurantRepository.findNear(lat, lon, radiusKm, size, offset));
    }

    // ====== ค้นหาแบบแบ่งหน้า ======
    @GetMapping("/searchPaged")
    public ResponseEntity<Page<Restaurant>> searchRestaurantsPagedJson(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Integer typeId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "30") int size
    ) {
        return ResponseEntity.ok(((RestaurantServiceImpl) restaurantService)
                .search(q, typeId, page, size));
    }

    // ---------- helpers ----------
    private String nullToEmpty(String s) { return (s == null) ? "" : s; }

    private LocalDateTime parseFlexibleDateTime(String s) {
        if (s == null) return null;
        s = s.trim(); if (s.isEmpty()) return null;
        try { return LocalDateTime.parse(s); } catch (Exception ignore) {}
        try { return LocalDateTime.of(LocalDate.now(), LocalTime.parse(s)); }
        catch (Exception ignore) {}
        return null;
    }

    /** ใช้ id ถ้ามี; ถ้าไม่มี ให้หาตามชื่อ (ไม่สนตัวพิมพ์) และสร้างใหม่อัตโนมัติ */
    private RestaurantType resolveType(Integer id, String name) {
        if (id != null) {
            return restaurantTypeRepo.findById(id).orElse(null);
        }
        if (name != null && !name.isBlank()) {
            String n = name.trim();
            return restaurantTypeRepo.findByTypeNameIgnoreCase(n)
                    .orElseGet(() -> restaurantTypeRepo.save(new RestaurantType(null, n)));
        }
        // ✅ default ถ้าไม่ส่งมาเลย
        String def = "ร้านอาหาร";
        return restaurantTypeRepo.findByTypeNameIgnoreCase(def)
                .orElseGet(() -> restaurantTypeRepo.save(new RestaurantType(null, def)));
    }


    /** แปลงค่าที่เก็บใน restaurantImg ให้เป็นลิสต์ URL (รองรับทั้ง JSON array และสตริงเดี่ยว) */
    private List<String> parseImageUrls(String raw) {
        List<String> out = new ArrayList<>();
        if (raw == null) return out;
        String s = raw.trim();
        if (s.isEmpty()) return out;
        if (s.startsWith("[")) {
            try { out.addAll(MAPPER.readValue(s, List.class)); } catch (Exception ignore) {}
        } else {
            out.add(s);
        }
        return out;
    }

    /** เซฟไฟล์ใหม่ทั้งหมดลงโฟลเดอร์ แล้วคืนค่า URL /images/filename */
    private List<String> saveFiles(List<MultipartFile> files) throws IOException {
        List<String> urls = new ArrayList<>();
        if (files == null) return urls;

        for (MultipartFile f : files) {
            if (f == null || f.isEmpty()) continue;

            String original = StringUtils.cleanPath(Objects.requireNonNullElse(f.getOriginalFilename(), ""));
            String ext = "";
            int dot = original.lastIndexOf('.');
            if (dot != -1) ext = original.substring(dot); // รวมจุด เช่น ".jpg"

            String filename = UUID.randomUUID().toString() + ext;
            File dest = new File(IMAGE_DIR + filename);
            dest.getParentFile().mkdirs();

            try (FileOutputStream out = new FileOutputStream(dest)) {
                out.write(f.getBytes());
            }

            urls.add("/images/" + filename);
        }
        return urls;
    }
}

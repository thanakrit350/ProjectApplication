package com.finalproject.Restaurant.controller;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.finalproject.Restaurant.model.Restaurant;
import com.finalproject.Restaurant.model.RestaurantType;
import com.finalproject.Restaurant.service.RestaurantService;
import com.finalproject.Restaurant.service.RestaurantServiceImpl;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.*;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.time.LocalDateTime;
import java.util.*;

@RestController
@RequestMapping("/restaurants")
public class RestaurantController {

    @Autowired private RestaurantService restaurantService;

    /** โฟลเดอร์ที่เซิร์ฟเวอร์บันทึกรูปจริง */
    private static final String UPLOAD_DIR =
            "C:/final/Restaurant/src/main/java/com/finalproject/Restaurant/Img/";
    /** path สาธารณะที่ client ใช้เรียก (ต้องมี StaticResourceConfig / ImageController เสิร์ฟ) */
    private static final String PUBLIC_PREFIX = "/images/";
    private static final ObjectMapper M = new ObjectMapper();

    private static String nvl(String s){ return (s==null || s.trim().isEmpty()) ? null : s.trim(); }

    /* ======================= READ ======================= */

    @GetMapping
    public ResponseEntity<List<Restaurant>> getRestaurant() {
        try {
            return ResponseEntity.ok(restaurantService.getAllRestaurants());
        } catch (Exception e) {
            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<Restaurant> getRestaurantById(@PathVariable Integer id) {
        try {
            return ResponseEntity.ok(restaurantService.getRestaurantById(id));
        } catch (Exception e) {
            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    /* ======================= CREATE (multipart) ======================= */

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> doAddRestuarant(
            // ===== REQUIRED =====
            @RequestParam("restaurantName") String restaurantName,
            @RequestParam("latitude")       String latitude,
            @RequestParam("longitude")      String longitude,
            @RequestParam("province")       String province,
            @RequestParam("restaurantType") Integer restaurantTypeId,

            // ===== OPTIONAL =====
            @RequestParam(value="restaurantPhone", required=false) String restaurantPhone,
            @RequestParam(value="description",    required=false) String description,
            @RequestParam(value="district",       required=false) String district,
            @RequestParam(value="subdistrict",    required=false) String subdistrict,
            @RequestParam(value="openTime",       required=false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime openTime,
            @RequestParam(value="closeTime",      required=false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime closeTime,

            // รูป (รับได้ทั้งชื่อใหม่/ชื่อเดิม)
            @RequestParam(value="restaurantImgs", required=false) List<MultipartFile> restaurantImgs,
            @RequestParam(value="restaurantImg",  required=false) List<MultipartFile> restaurantImgLegacy
    ){
        try{
            List<MultipartFile> all = combineFiles(restaurantImgs, restaurantImgLegacy);
            List<String> urls = saveFiles(all); // เป็น public path เช่น /images/xxx.jpg

            Restaurant r = new Restaurant();
            r.setRestaurantName(restaurantName.trim());
            r.setLatitude(latitude.trim());
            r.setLongitude(longitude.trim());
            r.setProvince(province.trim());
            r.setRestaurantPhone(nvl(restaurantPhone));
            r.setDescription(nvl(description));
            r.setDistrict(nvl(district));
            r.setSubdistrict(nvl(subdistrict));
            r.setOpenTime(openTime);
            r.setCloseTime(closeTime);

            if(!urls.isEmpty()) r.setRestaurantImg(M.writeValueAsString(urls));

            RestaurantType type = new RestaurantType();
            type.setRestaurantTypeId(restaurantTypeId);
            r.setRestaurantType(type);

            return new ResponseEntity<>(restaurantService.createRestaurant(r), HttpStatus.CREATED);
        }catch(IOException e){
            return new ResponseEntity<>("เกิดข้อผิดพลาดในการบันทึกรูปภาพ", HttpStatus.INTERNAL_SERVER_ERROR);
        }catch(Exception e){
            return new ResponseEntity<>("ไม่สามารถสร้างร้านอาหารได้", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    /* ======================= UPDATE (multipart) ======================= */
    /**
     * อัปเดตร้าน:
     * - ถ้ามีไฟล์ใหม่ → ลบรูปเก่าทั้งหมด แล้วแทนที่ด้วยไฟล์ใหม่
     * - ถ้า removeImages=true และไม่มีไฟล์ใหม่ → ลบรูปเก่าทั้งหมดและล้างค่า
     * - ฟิลด์อื่น ๆ อัปเดตเฉพาะที่ส่งมา
     */
    @PutMapping(value="/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> doEditRestaurant(
            @PathVariable Integer id,

            // ทุกอย่างไม่บังคับ
            @RequestParam(value="restaurantName", required=false) String restaurantName,
            @RequestParam(value="latitude",       required=false) String latitude,
            @RequestParam(value="longitude",      required=false) String longitude,
            @RequestParam(value="province",       required=false) String province,
            @RequestParam(value="restaurantType", required=false) Integer restaurantTypeId,
            @RequestParam(value="restaurantPhone", required=false) String restaurantPhone,
            @RequestParam(value="description",     required=false) String description,
            @RequestParam(value="district",        required=false) String district,
            @RequestParam(value="subdistrict",     required=false) String subdistrict,
            @RequestParam(value="openTime",        required=false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime openTime,
            @RequestParam(value="closeTime",       required=false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime closeTime,

            // รูปใหม่ (หลายไฟล์)
            @RequestParam(value="restaurantImgs", required=false) List<MultipartFile> restaurantImgs,
            @RequestParam(value="restaurantImg",  required=false) List<MultipartFile> restaurantImgLegacy,

            // ลบรูปทั้งหมดโดยไม่อัปโหลดใหม่
            @RequestParam(value="removeImages",   required=false, defaultValue = "false") boolean removeImages
    ){
        try{
            Restaurant r = restaurantService.getRestaurantById(id);
            if(r == null) return new ResponseEntity<>("ไม่พบร้านอาหารนี้", HttpStatus.NOT_FOUND);

            if(nvl(restaurantName) != null) r.setRestaurantName(restaurantName.trim());
            if(nvl(latitude)       != null) r.setLatitude(latitude.trim());
            if(nvl(longitude)      != null) r.setLongitude(longitude.trim());
            if(nvl(province)       != null) r.setProvince(province.trim());

            if(restaurantTypeId != null){
                RestaurantType type = new RestaurantType();
                type.setRestaurantTypeId(restaurantTypeId);
                r.setRestaurantType(type);
            }

            if(restaurantPhone != null) r.setRestaurantPhone(nvl(restaurantPhone));
            if(description    != null) r.setDescription(nvl(description));
            if(district       != null) r.setDistrict(nvl(district));
            if(subdistrict    != null) r.setSubdistrict(nvl(subdistrict));
            if(openTime       != null) r.setOpenTime(openTime);
            if(closeTime      != null) r.setCloseTime(closeTime);

            // จัดการรูป
            List<MultipartFile> all = combineFiles(restaurantImgs, restaurantImgLegacy);
            if(!all.isEmpty()){
                // มีไฟล์ใหม่ → ลบเก่าก่อน แล้วแทนที่
                deleteFilesFromStored(r.getRestaurantImg());
                List<String> urls = saveFiles(all);
                r.setRestaurantImg(urls.isEmpty() ? null : M.writeValueAsString(urls));
            } else if (removeImages) {
                // ขอให้ลบรูปทั้งหมด
                deleteFilesFromStored(r.getRestaurantImg());
                r.setRestaurantImg(null);
            }

            return ResponseEntity.ok(restaurantService.updateRestaurant(r));
        }catch(IOException e){
            return new ResponseEntity<>("เกิดข้อผิดพลาดในการบันทึกรูปภาพ", HttpStatus.INTERNAL_SERVER_ERROR);
        }catch(Exception e){
            return new ResponseEntity<>("ไม่สามารถอัปเดตร้านอาหารได้", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    /* ======================= REPLACE IMAGES (multipart) ======================= */
    /**
     * แทนที่รูป "ทั้งหมด" ของร้าน (ชัดเจนกว่ากรณีอัปเดตหลายฟิลด์)
     * ส่งไฟล์ใหม่ → ระบบลบเก่าทั้งหมดแล้วเซ็ตใหม่
     */
    @PutMapping(value = "/{id}/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> replaceImages(
            @PathVariable Integer id,
            @RequestParam("files") List<MultipartFile> files
    ){
        try{
            Restaurant r = restaurantService.getRestaurantById(id);
            if(r == null) return new ResponseEntity<>("ไม่พบร้านอาหาร", HttpStatus.NOT_FOUND);

            deleteFilesFromStored(r.getRestaurantImg());
            List<String> urls = saveFiles(files);
            r.setRestaurantImg(urls.isEmpty() ? null : M.writeValueAsString(urls));
            return ResponseEntity.ok(restaurantService.updateRestaurant(r));
        }catch(IOException e){
            return new ResponseEntity<>("อัปโหลดรูปไม่สำเร็จ", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    /* ======================= APPEND IMAGES (multipart) ======================= */
    @PostMapping(value = "/{id}/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> appendImages(
            @PathVariable Integer id,
            @RequestParam("files") List<MultipartFile> files
    ) {
        try {
            Restaurant r = restaurantService.getRestaurantById(id);
            if (r == null) return new ResponseEntity<>("ไม่พบร้านอาหาร", HttpStatus.NOT_FOUND);

            // อ่านรูปเดิม
            List<String> current = readStoredUrls(r.getRestaurantImg());
            // เพิ่มรูปใหม่
            current.addAll(saveFiles(files));

            r.setRestaurantImg(current.isEmpty() ? null : M.writeValueAsString(current));
            return ResponseEntity.ok(restaurantService.updateRestaurant(r));

        } catch (IOException e) {
            return new ResponseEntity<>("อัปโหลดรูปไม่สำเร็จ", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    /* ======================= DELETE ======================= */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> doRemoveRestaurant(@PathVariable Integer id) {
        try {
            Restaurant r = restaurantService.getRestaurantById(id);
            if (r != null) {
                deleteFilesFromStored(r.getRestaurantImg()); // ลบไฟล์จริง
            }
            restaurantService.deleteRestaurant(id);
            return new ResponseEntity<>(HttpStatus.NO_CONTENT);
        } catch (Exception e) {
            return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    /* ======================= SEARCH (เดิม) ======================= */
    @GetMapping("/searchPaged")
    public ResponseEntity<Page<Restaurant>> getSearchRestaurant(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Integer typeId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "30") int size
    ) {
        return ResponseEntity.ok(((RestaurantServiceImpl) restaurantService)
                .search(q, typeId, page, size));
    }

    /* ======================= Helpers ======================= */

    /** รวมไฟล์จาก 2 คีย์ให้เป็นลิสต์เดียว */
    private static List<MultipartFile> combineFiles(List<MultipartFile> a, List<MultipartFile> b){
        List<MultipartFile> all = new ArrayList<>();
        if(a!=null) all.addAll(a);
        if(b!=null) all.addAll(b);
        // กันบาง client ส่ง "ไฟล์ว่าง"
        all.removeIf(f -> f==null || f.isEmpty());
        return all;
    }

    /** บันทึกไฟล์ลงดิสก์ แล้วคืนเป็น public URL (เช่น /images/xxxx.jpg) */
    private List<String> saveFiles(List<MultipartFile> files) throws IOException {
        List<String> urls = new ArrayList<>();
        if (files == null) return urls;

        for (MultipartFile f : files) {
            if (f == null || f.isEmpty()) continue;
            String fileName = UUID.randomUUID() + "_" + StringUtils.cleanPath(f.getOriginalFilename());
            File saveFile = new File(UPLOAD_DIR + fileName);
            try (FileOutputStream out = new FileOutputStream(saveFile)) {
                out.write(f.getBytes());
            }
            urls.add(PUBLIC_PREFIX + fileName);
        }
        return urls;
    }

    /** แปลงค่าที่เก็บใน column restaurantImg ให้เป็นลิสต์ public URL */
    private List<String> readStoredUrls(String stored){
        List<String> list = new ArrayList<>();
        if (stored == null || stored.isBlank()) return list;

        try {
            if (stored.trim().startsWith("[")) {
                list.addAll(M.readValue(stored, new TypeReference<List<String>>(){}));
            } else {
                list.add(stored.trim());
            }
        } catch (Exception ignored){}

        // กรองให้เหลือเฉพาะ path ที่ขึ้นต้นด้วย /images/
        list.removeIf(u -> u==null || !u.startsWith(PUBLIC_PREFIX));
        return list;
    }

    /** ลบไฟล์รูปเก่าทั้งหมดอย่างปลอดภัย ตามค่าใน column restaurantImg */
    private void deleteFilesFromStored(String stored){
        for (String url : readStoredUrls(stored)) {
            String filename = url.substring(PUBLIC_PREFIX.length()); // ตัด /images/
            File f = new File(UPLOAD_DIR + filename);
            if (f.exists() && f.isFile()) {
                try {
                    // ถ้าลบไม่ได้ก็ข้าม (ไม่ fail ทั้ง request)
                    boolean ok = f.delete();
                    if (!ok) System.err.println("Cannot delete file: " + f.getAbsolutePath());
                } catch (SecurityException se) {
                    System.err.println("SecurityException deleting file: " + se.getMessage());
                }
            }
        }
    }
}

package com.finalproject.Restaurant.controller;

import com.finalproject.Restaurant.model.RestaurantType;
import com.finalproject.Restaurant.repository.RestaurantTypeRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/restaurant-types")
@CrossOrigin(origins = "*") // ให้ Flutter/เว็บเรียกได้ ถ้าเสิร์ฟหน้าเว็บจาก Spring เอง จะไม่ติด CORS อยู่แล้ว
public class RestaurantTypeController {

    @Autowired
    private RestaurantTypeRepository restaurantTypeRepository;


    // ---- READ: ทั้งหมด ----
    @GetMapping
    public List<RestaurantType> getAllRestaurantTypes() {
        return restaurantTypeRepository.findAll();
    }

    // ---- READ: รายตัว ----
    @GetMapping("/{id}")
    public ResponseEntity<RestaurantType> getById(@PathVariable Integer id) {
        return restaurantTypeRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    // ---- SEARCH: by name (contains, ignore case) ----
    @GetMapping("/search")
    public List<RestaurantType> search(@RequestParam("q") String q) {
        return restaurantTypeRepository.findByTypeNameContainingIgnoreCase(q);
    }

    // ---- CREATE ----
    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> create(@RequestBody RestaurantType body) {
        if (body.getTypeName() == null || body.getTypeName().isBlank()) {
            return ResponseEntity.badRequest().body("typeName is required");
        }
        String name = body.getTypeName().trim();

        if (restaurantTypeRepository.existsByTypeNameIgnoreCase(name)) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body("typeName already exists");
        }

        RestaurantType toSave = new RestaurantType();
        toSave.setTypeName(name);
        RestaurantType saved = restaurantTypeRepository.save(toSave);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    // ---- UPDATE ----
    @PutMapping(value = "/{id}", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> update(@PathVariable Integer id, @RequestBody RestaurantType body) {
        Optional<RestaurantType> opt = restaurantTypeRepository.findById(id);
        if (opt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body("ไม่พบประเภทนี้");
        }

        RestaurantType existing = opt.get();

        if (body.getTypeName() != null) {
            String name = body.getTypeName().trim();
            if (name.isEmpty()) {
                return ResponseEntity.badRequest().body("typeName is required");
            }
            // กันชื่อซ้ำกับตัวอื่น
            if (restaurantTypeRepository.existsByTypeNameIgnoreCaseAndRestaurantTypeIdNot(name, id)) {
                return ResponseEntity.status(HttpStatus.CONFLICT).body("typeName already exists");
            }
            existing.setTypeName(name);
        }

        RestaurantType saved = restaurantTypeRepository.save(existing);
        return ResponseEntity.ok(saved);
    }

    // ---- DELETE ----
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Integer id) {
        if (!restaurantTypeRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        restaurantTypeRepository.deleteById(id);
        return ResponseEntity.noContent().build();
    }
    // ✅ ใหม่: ส่งเฉพาะประเภทที่มีร้านจริง
    @GetMapping("/non-empty")
    public List<RestaurantType> getNonEmptyTypes() {
        return restaurantTypeRepository.findAllHavingRestaurants();
    }

    // (ออปชัน) ถ้าต้องการ count เพื่อนำไปโชว์/กรองฝั่ง client
    @GetMapping("/with-counts")
    public List<Map<String, Object>> getTypesWithCounts() {
        return restaurantTypeRepository.findAllWithCounts().stream()
                .map(p -> Map.<String, Object>of(
                        "id", p.getRestaurantTypeId(),
                        "name", p.getTypeName(),
                        "restaurantCount", p.getRestaurantCount()
                ))
                .collect(Collectors.toList()); // หรือ .toList() ถ้าใช้ JDK 16+
    }
}

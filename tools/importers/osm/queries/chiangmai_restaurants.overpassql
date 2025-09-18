[out:json][timeout:180];

// ---------- เลือกขอบเขต "จังหวัดเชียงใหม่" ----------
area["boundary"="administrative"]["ISO3166-2"="TH-50"]->.prov;

// ---------- เลือกทุกประเภท "กิน-ดื่ม" ----------
(
  // ร้านอาหาร/เครื่องดื่มหลัก ๆ
  nwr["amenity"~"^(restaurant|fast_food|cafe|food_court|ice_cream|pub|bar|bbq|biergarten)$"](area.prov);

  // ร้านเบเกอรี่/ขนม (บางทีถูกแท็กเป็น shop)
  nwr["shop"~"^(bakery|confectionery|deli|pastry)$"](area.prov);

  // แผงลอย/รถเข็น (ถ้ามีแท็ก)
  nwr["amenity"="street_food"](area.prov);
);

// ---------- ส่งออกข้อมูลพร้อมพิกัด center สำหรับ way/relation ----------
out center tags;

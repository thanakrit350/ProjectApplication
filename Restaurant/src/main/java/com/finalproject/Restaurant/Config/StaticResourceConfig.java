package com.finalproject.Restaurant.Config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class StaticResourceConfig implements WebMvcConfigurer {

    // โฟลเดอร์เก็บรูปจริงบนเครื่อง (มี / ต่อท้าย)
    private static final String IMAGE_DIR =
            "file:C:/final/Restaurant/src/main/java/com/finalproject/Restaurant/Img/";

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/images/**")
                .addResourceLocations(IMAGE_DIR)
                .setCachePeriod(3600)   // cache 1 ชม.
                .resourceChain(true);
    }
}

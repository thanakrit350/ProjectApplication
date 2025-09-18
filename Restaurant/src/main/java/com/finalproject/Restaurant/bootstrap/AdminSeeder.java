package com.finalproject.Restaurant.bootstrap;

import com.finalproject.Restaurant.model.Admin;
import com.finalproject.Restaurant.repository.AdminRepository;
import com.finalproject.Restaurant.service.PasswordService;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AdminSeeder {

    @Bean
    CommandLineRunner seedAdmin(AdminRepository repo, PasswordService pwd){
        return args -> {
            if(repo.findByAdminUserNameIgnoreCase("admin").isEmpty()){
                Admin a = new Admin();
                a.setAdminUserName("admin");
                a.setAdminPassword(pwd.encodePassword("admin1234"));
                repo.save(a);
                System.out.println("Created default admin: admin / admin1234");
            }
        };
    }
}

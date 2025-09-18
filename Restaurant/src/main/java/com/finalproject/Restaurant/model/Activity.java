package com.finalproject.Restaurant.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.*;

@Entity
@Table(name = "Activity")
@Data
@AllArgsConstructor
@NoArgsConstructor
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class Activity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer activityId;

    @Column(nullable = false, length = 255)
    private String activityName;

    @Column(columnDefinition = "TEXT")
    private String descriptionActivity;

    @Column(nullable = false)
    private Date inviteDate;

    @Column(nullable = false)
    private Date postDate;

    @Column(nullable = false, length = 50)
    private String statusPost;

    @Column(nullable = false)
    private Boolean isOwnerSelect;

    @ManyToMany(cascade = CascadeType.ALL)
    @JoinTable(
            name = "member_join_activity",
            joinColumns = @JoinColumn(name = "activityId"),
            inverseJoinColumns = @JoinColumn(name = "activityMemberId")
    )
    private List<ActivityMember> activityMembers = new ArrayList<>();

    @ManyToOne
    @JoinColumn(name = "restaurantTypeId")
    private RestaurantType restaurantType;

    @ManyToOne
    @JoinColumn(name = "restaurantId")
    private Restaurant restaurant;
}

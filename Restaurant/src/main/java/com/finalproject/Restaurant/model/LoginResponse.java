package com.finalproject.Restaurant.model;

public class LoginResponse {
    private boolean status;
    private String message;
    private Member data;

    public LoginResponse(boolean status, String message, Member data) {
        this.status = status;
        this.message = message;
        this.data = data;
    }

    public boolean isStatus() {
        return status;
    }

    public String getMessage() {
        return message;
    }

    public Member getData() {
        return data;
    }
}


class Member {
  final int? memberId;
  final String? firstName;
  final String? lastName;
  final String? birthDate;
  final String? gender;
  final String? profileImage;
  final String? email;
  final String? password;
  final String? phoneNumber;

  Member({
    this.memberId,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.gender,
    this.profileImage,
    this.email,
    this.password,
    this.phoneNumber,
  });

  factory Member.fromMemberJson(Map<String, dynamic> json) {
    return Member(
      memberId: json['memberId'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      birthDate: json['birthDate'],
      gender: json['gender'],
      profileImage: json['profileImage'],
      email: json['email'],
      password: json['password'],
      phoneNumber: json['phoneNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': birthDate,
      'gender': gender,
      'profileImage': profileImage,
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
    };
  }

  Member copyWith({
    int? memberId,
    String? firstName,
    String? lastName,
    String? birthDate,
    String? gender,
    String? profileImage,
    String? email,
    String? password,
    String? phoneNumber,
  }) {
    return Member(
      memberId: memberId ?? this.memberId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      profileImage: profileImage ?? this.profileImage,
      email: email ?? this.email,
      password: password ?? this.password,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

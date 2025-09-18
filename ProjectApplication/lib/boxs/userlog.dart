import 'package:newproject/model/Member.dart';

class UserLog {
  static final UserLog _instance = UserLog._internal();

  factory UserLog() {
    return _instance;
  }

  UserLog._internal();

  Member? member; // ใช้เก็บข้อมูลผู้ใช้ที่เข้าสู่ระบบ
  String username = ''; // ใช้เก็บชื่อผู้ใช้ที่เข้าสู่ระบบ

  bool get isLoggedIn => member != null;

  void logout() {
    member = null;
  }
}

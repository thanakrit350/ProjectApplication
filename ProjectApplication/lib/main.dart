import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:newproject/screens/Activity/AddPostActivityPage.dart';
import 'package:newproject/screens/Member/LoginMemberPage.dart';
import 'package:newproject/screens/Home/home.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ บังคับ locale ไทยทั้งแอป (ถ้าอยากยึดตามระบบเอาบรรทัดนี้ออกได้)
      locale: const Locale('th', 'TH'),

      // ✅ เปิด Localizations (ใช้อยู่แล้ว ดีมาก)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th', 'TH'),
      ],

      home: const HomeScreens(),

      // ✅ เพิ่มเส้นทางที่อาจใช้เรียกแบบ named route
      routes: {
        '/login': (context) => const LoginMemberPage(),
        '/addParty': (context) => const AddPostActivityPage(),
      },
    );
  }
}

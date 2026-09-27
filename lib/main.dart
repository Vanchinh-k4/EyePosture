import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Thêm import này
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'firebase_options.dart';

// Thêm async vào ngay sau void main()
void main() async {
  // Đảm bảo Flutter framework đã sẵn sàng
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: true, // Đặt là true để bỏ qua kiểm tra APNs/reCAPTCHA khi test
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EyePosture',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00A86B)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
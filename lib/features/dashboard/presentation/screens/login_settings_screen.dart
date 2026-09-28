import 'package:flutter/material.dart';

class LoginSettingsScreen extends StatefulWidget {
  const LoginSettingsScreen({super.key});

  @override
  State<LoginSettingsScreen> createState() => _LoginSettingsScreenState();
}

class _LoginSettingsScreenState extends State<LoginSettingsScreen> {
  // Biến lưu trạng thái bật/tắt đăng nhập bằng FaceID/Vân tay
  bool _isBiometricEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cài đặt',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: ListTile(
                  // Giảm padding ngang và thu hẹp khoảng cách giữa icon & chữ
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 2.0,
                  ),
                  horizontalTitleGap: 8.0,
                  
                  // Icon biểu tượng màu đỏ
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),

                  // Tiêu đề hiển thị đầy đủ trên 1 dòng
                  title: const Text(
                    'Đăng nhập bằng FaceID/Vân tay',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),

                  // Nút Switch thu nhỏ tỉ lệ 75%
                  trailing: Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: _isBiometricEnabled,
                      activeColor: const Color(0xFFE53935),
                      onChanged: (bool value) {
                        setState(() {
                          _isBiometricEnabled = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:eye_posture/login_screen.dart';
import 'add_device_screen.dart';


class SettingsScreen extends StatelessWidget {
  final String userPhone; // 1. Thêm biến userPhone

  const SettingsScreen({
    super.key, 
    required this.userPhone, // 2. Khai báo tham số trong constructor
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA), // Màu nền xám nhạt mịn
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Cài đặt',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                children: [
                  _buildSettingItem(
                    icon: Icons.link,
                    iconBgColor: const Color(0xFF1E88E5), // Xanh dương
                    title: 'Kết nối thiết bị',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>  AddDeviceScreen(
                            userPhone: userPhone,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.settings_suggest_rounded,
                    iconBgColor: const Color(0xFFE53935), // Đỏ
                    title: 'Cài đặt đăng nhập',
                    onTap: () {},
                  ),      
                  _buildSettingItem(
                    icon: Icons.link_off_rounded,
                    iconBgColor: const Color(0xFF1E88E5), // Xanh dương
                    title: 'Ngắt kết nối',
                    onTap: () {},
                  ),
                  _buildSettingItem(
                    icon: Icons.delete_forever_rounded,
                    iconBgColor: const Color(0xFFE53935), // Đỏ
                    title: 'Xóa tài khoản',
                    onTap: () {},
                  ),
                  _buildSettingItem(
                    icon: Icons.translate_rounded,
                    iconBgColor: const Color(0xFF43A047), // Xanh lá
                    title: 'Ngôn ngữ: Tiếng Việt',
                    trailingWidget: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.star,
                          color: Colors.yellow,
                          size: 14,
                        ),
                      ),
                    ),
                    onTap: () {},
                  ),
                  _buildSettingItem(
                    icon: Icons.smartphone_rounded,
                    iconBgColor: const Color(0xFF43A047), // Xanh lá
                    title: 'Thông tin phiên bản',
                    onTap: () {},
                  ),
                  _buildSettingItem(
                    icon: Icons.logout_rounded,
                    iconBgColor: const Color(0xFFFB8C00), // Cam
                    title: 'Đăng xuất',
                    onTap: () {
                      // Hiển thị hộp thoại xác nhận khi bấm Đăng xuất
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text('Xác nhận đăng xuất'),
                            content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context), // Đóng dialog
                                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                               ),
                                onPressed: () {
                                   // 1. Đóng dialog
                                  Navigator.pop(context);
                
                                 // 2. Chuyển hướng về LoginScreen và xóa tất cả màn hình cũ
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                    (route) => false, // Xóa sạch lịch sử điều hướng
                                  );
                                },
                                child: const Text(
                                  'Đăng xuất',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Thông tin phiên bản phía dưới
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Phiên bản: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '1.0.26',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFE53935),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget dùng chung để tạo từng ô mục cài đặt
  Widget _buildSettingItem({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required VoidCallback onTap,
    Widget? trailingWidget,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingWidget != null) ...[
              trailingWidget,
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFE53935), // Mũi tên màu đỏ theo hình mẫu
              size: 24,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
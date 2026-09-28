import 'package:eye_posture/features/dashboard/presentation/screens/login_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:eye_posture/login_screen.dart';
import 'add_device_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userPhone;

  const SettingsScreen({
    super.key,
    required this.userPhone,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Biến lưu mã ngôn ngữ đang chọn ('vi': Tiếng Việt, 'en': Tiếng Anh)
  String _selectedLanguageCode = 'vi';

  // Modal Bottom Sheet hiển thị danh sách chọn ngôn ngữ
  void _showLanguageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thanh Tiêu đề: Nút đóng [X] + Tiêu đề [Ngôn ngữ]
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, size: 24, color: Colors.black),
                        ),
                        const Expanded(
                          child: Text(
                            'Ngôn ngữ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24), // Cân bằng khoảng cách với icon đóng
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 8),

                  // Lựa chọn 1: Tiếng Việt
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.star, color: Colors.yellow, size: 16),
                      ),
                    ),
                    title: const Text(
                      'Tiếng Việt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    trailing: _selectedLanguageCode == 'vi'
                        ? const Icon(Icons.check, color: Color(0xFFE53935))
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedLanguageCode = 'vi';
                      });
                      setModalState(() {});
                      Navigator.pop(context);
                    },
                  ),

                  // Lựa chọn 2: Tiếng Anh
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🇬🇧', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    title: const Text(
                      'Tiếng Anh',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    trailing: _selectedLanguageCode == 'en'
                        ? const Icon(Icons.check, color: Color(0xFFE53935))
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedLanguageCode = 'en';
                      });
                      setModalState(() {});
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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
                          builder: (context) => AddDeviceScreen(
                            userPhone: widget.userPhone, // Dùng widget.userPhone trong StatefulWidget
                          ),
                        ),
                      );
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.settings_suggest_rounded,
                    iconBgColor: const Color(0xFFE53935), // Đỏ
                    title: 'Cài đặt đăng nhập',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginSettingsScreen()
                        ),
                      );
                    },
                  ),
                  _buildSettingItem(
  icon: Icons.link_off_rounded,
  iconBgColor: const Color(0xFF1E88E5), // Xanh dương
  title: 'Ngắt kết nối',
  onTap: () {
    // Hiển thị hộp thoại xác nhận Ngắt kết nối
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Xác nhận ngắt kết nối',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
         content: const Text(
  'Sau khi hủy liên kết, bạn sẽ không thể xem thông tin của thiết bị. Bạn có chắc chắn muốn ngắt kết nối không?',
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: 14,
    height: 1.4,
    color: Colors.black87,
  ),
),
          actions: [
            // Nút Hủy
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ),
            // Nút Ngắt kết nối
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5), // Xanh dương đồng bộ icon
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // 1. Đóng Dialog
                Navigator.pop(context);

                // 2. Thực hiện logic ngắt kết nối ở đây (VD: Xóa token, gọi API, v.v.)

                // 3. Thông báo cho người dùng
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã ngắt kết nối thiết bị thành công!'),
                    backgroundColor: Color(0xFF1E88E5),
                  ),
                );
              },
              child: const Text(
                'Ngắt kết nối',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  },
),
                 _buildSettingItem(
  icon: Icons.delete_forever_rounded,
  iconBgColor: const Color(0xFFE53935), // Đỏ
  title: 'Xóa tài khoản',
  onTap: () {
    // Hiển thị hộp thoại xác nhận xóa tài khoản
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Xác nhận xóa tài khoản',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
         content: const Text(
  'Tất cả dữ liệu sẽ bị xóa sau khi bạn xóa tài khoản.',
  textAlign: TextAlign.center, // Căn giữa đều hai bên
  style: TextStyle(
    fontSize: 14,
    height: 1.4,
    color: Colors.black87,
  ),
),
          actions: [
            // Nút Hủy
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Nút Xác nhận Xóa
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935), // Màu đỏ nổi bật
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // 1. Đóng Dialog
                Navigator.pop(context);

                // 2. Thực hiện logic xóa tài khoản (VD: Xóa trên Firebase, gọi API, v.v.)

                // 3. Chuyển hướng về LoginScreen và xóa toàn bộ lịch sử màn hình cũ
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );

                // 4. Thông báo cho người dùng
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã xóa tài khoản thành công!'),
                    backgroundColor: Color(0xFFE53935),
                  ),
                );
              },
              child: const Text(
                'Xóa tài khoản',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  },
),
                  
                  // Item Ngôn ngữ
                  _buildSettingItem(
                    icon: Icons.translate_rounded,
                    iconBgColor: const Color(0xFF43A047), // Xanh lá
                    title: 'Ngôn ngữ: ${_selectedLanguageCode == 'vi' ? 'Tiếng Việt' : 'Tiếng Anh'}',
                    trailingWidget: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _selectedLanguageCode == 'vi' ? Colors.red : Colors.blue.shade800,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _selectedLanguageCode == 'vi'
                            ? const Icon(
                                Icons.star,
                                color: Colors.yellow,
                                size: 14,
                              )
                            : const Text(
                                '🇬🇧',
                                style: TextStyle(fontSize: 12),
                              ),
                      ),
                    ),
                    onTap: () => _showLanguageBottomSheet(context),
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
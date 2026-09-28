import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eye_posture/features/dashboard/presentation/screens/device_selection_screen.dart';
import 'package:eye_posture/features/dashboard/presentation/screens/dashboard_screen.dart';
import '/models/user_device_model.dart';
import 'history_screen.dart'; 
import 'settings_screen.dart'; 
import 'notifications_screen.dart'; // 1. Import màn hình thông báo

class MainScreen extends StatefulWidget {
  final String userPhone;

  const MainScreen({super.key, required this.userPhone});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  DeviceModel? _selectedDevice;

  /// Lắng nghe liên tục để phát hiện nếu thiết bị đang chọn bị xóa/hủy liên kết
  void _listenDeviceStatus() {
    if (_selectedDevice == null) return;

    final cleanPhone = widget.userPhone.trim();
    final deviceId = _selectedDevice!.deviceId;

    FirebaseDatabase.instance
        .ref('users/$cleanPhone/devices/$deviceId')
        .onValue
        .listen((event) {
      if (!event.snapshot.exists && _selectedDevice != null) {
        if (mounted) {
          setState(() {
            _selectedDevice = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thiết bị đang chọn đã ngắt liên kết!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tab 1: Trang chủ
    Widget homeTabContent = _selectedDevice == null
        ? DeviceSelectionScreen(
            userPhone: widget.userPhone,
            onSelectDevice: (device) {
              setState(() {
                _selectedDevice = device;
              });
              _listenDeviceStatus();
            },
          )
        : DashboardScreen(
            selectedDevice: _selectedDevice!,
            userPhone: widget.userPhone,
            onSwitchDevice: () {
              setState(() {
                _selectedDevice = null;
              });
            },
          );

    // Tab 2: Lịch sử
    Widget historyTabContent = HistoryScreen(
      userPhone: widget.userPhone,
      initialDeviceId: _selectedDevice?.deviceId,
    );

    // Tab 3: Thông báo (Thêm mới)
    Widget notificationsTabContent = const NotificationsScreen();

    // Tab 4: Cài đặt
    Widget settingsTabContent = SettingsScreen(
      userPhone: widget.userPhone,
    );

    // Danh sách các Tab màn hình (được mở rộng thành 4 tab)
    final List<Widget> pages = [
      homeTabContent,
      historyTabContent,
      notificationsTabContent,
      settingsTabContent,
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed, // Đảm bảo hiển thị đủ 4 tab không bị xô lệch
        selectedItemColor: const Color(0xFF00A86B),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Lịch sử',
          ),
          // Mục Thông báo mới
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Thông báo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
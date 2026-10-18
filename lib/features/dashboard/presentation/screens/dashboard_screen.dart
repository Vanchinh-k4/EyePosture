import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/constants/app_colors.dart';
import '/models/user_device_model.dart';
import '../widgets/metric_card.dart';
import 'add_device_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userPhone;
  final DeviceModel selectedDevice;
  final VoidCallback? onSwitchDevice;
  final Function(int)? onNavigateToTab; // 🚀 Bổ sung Callback chuyển Tab

  const DashboardScreen({
    super.key,
    required this.userPhone,
    required this.selectedDevice,
    this.onSwitchDevice,
    this.onNavigateToTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DatabaseReference _deviceRef;

  @override
  void initState() {
    super.initState();
    final deviceId = widget.selectedDevice.deviceId;
    _deviceRef = FirebaseDatabase.instance.ref('devices/$deviceId');
  }

  // Cập nhật cấu hình cài đặt chung lên Firebase (/devices/{deviceId}/settings)
  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await _deviceRef.child('settings').update({
        key: value,
      });
      _showSnackBar('Cập nhật cài đặt thành công');
    } catch (e) {
      _showSnackBar('Lỗi cập nhật cài đặt: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // Hàm hỗ trợ chuyển nhanh tới Tab mong muốn (Ví dụ Tab Lịch Sử có index = 1)
  void _goToHistoryTab() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(1); // Index 1 tương ứng với Tab Lịch Sử & Thống Kê
    } else {
      _showSnackBar('Chuyển sang tab Lịch Sử để xem chi tiết');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _deviceRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Lỗi kết nối: ${snapshot.error}')),
          );
        }

        String deviceName = widget.selectedDevice.deviceName;
        double currentDistance =
            (widget.selectedDevice.currentData?.distanceCm ?? 0).toDouble();
        int currentLight =
            (widget.selectedDevice.currentData?.lightLux ?? 0).toInt();

        String posture = widget.selectedDevice.currentData?.posture ?? 'empty';
        String postureDetail = 'Đang tải...';
        bool isAlarm = false;
        int lastSeenMs = 0;

        // Trạng thái cài đặt chức năng
        bool isBuzzerEnabled = widget.selectedDevice.settings?.warningBuzzer ?? true;
        bool isLedEnabled = true;
        bool isSmartAlertEnabled = true;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final rawData =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final data = Map<String, dynamic>.from(rawData);

          // Đọc thông tin thiết bị
          if (data['info'] != null && data['info'] is Map) {
            final infoMap = Map<String, dynamic>.from(data['info']);
            deviceName = infoMap['device_name'] ?? deviceName;
          } else {
            deviceName = data['device_name'] ?? deviceName;
          }

          // Đọc thời gian tương tác gần nhất
          if (data['last_seen'] != null) {
            if (data['last_seen'] is int) {
              lastSeenMs = data['last_seen'];
            }
          }

          // Đọc dữ liệu cảm biến Realtime
          if (data['current_data'] != null) {
            final currentData =
                Map<String, dynamic>.from(data['current_data']);
            currentDistance =
                (currentData['distance_cm'] ?? currentDistance).toDouble();
            currentLight = (currentData['light_lux'] ?? currentLight).toInt();
            posture = currentData['posture'] ?? posture;
            postureDetail = currentData['posture_detail'] ?? 'Bình thường';
            isAlarm = currentData['alarm'] ?? false;
          }

          // Đọc cài đặt các chức năng
          if (data['settings'] != null) {
            final settings = Map<String, dynamic>.from(data['settings']);
            isBuzzerEnabled = settings['warning_buzzer'] ?? isBuzzerEnabled;
            isLedEnabled = settings['led_light'] ?? true;
            isSmartAlertEnabled = settings['smart_alert'] ?? true;
          }
        }

        final int nowMs = DateTime.now().millisecondsSinceEpoch;
        final bool isOnline =
            lastSeenMs > 0 && (nowMs - lastSeenMs).abs() < 30000;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Đổi thiết bị',
              onPressed: widget.onSwitchDevice,
            ),
            centerTitle: true,
            title: Column(
              children: [
                const Text(
                  'Hệ Thống Giám Sát',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  deviceName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00A86B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_to_queue_rounded),
                tooltip: 'Thêm thiết bị mới',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddDeviceScreen(
                        userPhone: widget.userPhone,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trạng thái kết nối & Thiết bị
                      _buildDeviceInfoBanner(
                        deviceId: widget.selectedDevice.deviceId,
                        isOnline: isOnline,
                      ),
                      const SizedBox(height: 16),

                      // Card Cảnh báo & Trạng thái tư thế
                      _buildPostureCard(
                        posture: posture,
                        postureDetail: postureDetail,
                        isAlarm: isAlarm,
                      ),
                      const SizedBox(height: 16),

                      // Thông số Realtime
                      const Text(
                        'Thông Số Thời Gian Thực',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: MetricCard(
                              title: 'Khoảng Cách',
                              value: '${currentDistance.toInt()} cm',
                              icon: Icons.straighten,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MetricCard(
                              title: 'Ánh Sáng',
                              value: '$currentLight Lux',
                              icon: Icons.wb_sunny_outlined,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Bảng Bật/Tắt Điều Khiển Nhanh
                      const Text(
                        'Thao Tác Nhanh Thiết Bị',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: [
                          _buildQuickControlCard(
                            title: 'Còi Cảnh Báo',
                            subtitle: isBuzzerEnabled ? 'Đang Bật' : 'Đã Tắt',
                            icon: isBuzzerEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            activeColor: Colors.orange,
                            isActive: isBuzzerEnabled,
                            onToggle: (val) =>
                                _updateSetting('warning_buzzer', val),
                          ),
                          _buildQuickControlCard(
                            title: 'Đèn LED Báo',
                            subtitle: isLedEnabled ? 'Đang Bật' : 'Đã Tắt',
                            icon: isLedEnabled
                                ? Icons.lightbulb_rounded
                                : Icons.lightbulb_outline_rounded,
                            activeColor: Colors.amber,
                            isActive: isLedEnabled,
                            onToggle: (val) =>
                                _updateSetting('led_light', val),
                          ),
                          _buildQuickControlCard(
                            title: 'Báo Động AI',
                            subtitle: isSmartAlertEnabled ? 'Tự Động' : 'Tắt AI',
                            icon: Icons.psychology_rounded,
                            activeColor: Colors.purple,
                            isActive: isSmartAlertEnabled,
                            onToggle: (val) =>
                                _updateSetting('smart_alert', val),
                          ),
                          _buildQuickControlCard(
                            title: 'Đổi Thiết Bị',
                            subtitle: 'Danh sách',
                            icon: Icons.devices_other_rounded,
                            activeColor: Colors.blue,
                            isActive: true,
                            isSwitch: false,
                            onTap: widget.onSwitchDevice,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Trung Tâm Quản Lý Hệ Thống & Tính Năng Mở Rộng
                      const Text(
                        'Tính Năng Mở Rộng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureTile(
                        icon: Icons.history_toggle_off_rounded,
                        color: Colors.indigo,
                        title: 'Lịch Sử & Thống Kê Chi Tiết',
                        subtitle: 'Xem nhật ký vi phạm tư thế & phiên làm việc',
                        onTap: _goToHistoryTab, // 🚀 CHUYỂN TRỰC TIẾP SANG TAB LỊCH SỬ
                      ),
                      _buildFeatureTile(
                        icon: Icons.timer_outlined,
                        color: Colors.teal,
                        title: 'Chế Độ Học Tập (Pomodoro 25 phút)',
                        subtitle: 'Hẹn giờ tập trung & thông báo nghỉ ngơi',
                        onTap: () {
                          _showSnackBar('Chức năng Pomodoro đang được kích hoạt');
                        },
                      ),
                      _buildFeatureTile(
                        icon: Icons.wifi_find_rounded,
                        color: Colors.deepOrange,
                        title: 'Cấu Hình Mạng Wi-Fi AP',
                        subtitle: 'Cập nhật SSID & Password cho ESP32',
                        onTap: () {
                          _showSnackBar('Mở mục Chia Sẻ / AP Config tại danh sách thiết bị');
                        },
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildDeviceInfoBanner({
    required String deviceId,
    required bool isOnline,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.developer_board_rounded,
                  color: Colors.grey.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                'ID: $deviceId',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: isOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Trực tuyến' : 'Ngoại tuyến',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isOnline ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostureCard({
    required String posture,
    required String postureDetail,
    required bool isAlarm,
  }) {
    Color cardBgColor;
    Color iconColor;
    Color textColor;
    IconData iconData;

    if (isAlarm) {
      cardBgColor = Colors.red.shade50;
      iconColor = Colors.red.shade700;
      textColor = Colors.red.shade900;
      iconData = Icons.warning_amber_rounded;
    } else if (posture == 'good') {
      cardBgColor = AppColors.cardGood;
      iconColor = Colors.green.shade700;
      textColor = Colors.green.shade900;
      iconData = Icons.check_circle_outline_rounded;
    } else if (posture == 'empty') {
      cardBgColor = Colors.grey.shade100;
      iconColor = Colors.grey.shade600;
      textColor = Colors.grey.shade800;
      iconData = Icons.event_seat_outlined;
    } else {
      cardBgColor = Colors.amber.shade50;
      iconColor = Colors.amber.shade800;
      textColor = Colors.amber.shade900;
      iconData = Icons.info_outline_rounded;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: cardBgColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(
              iconData,
              size: 44,
              color: iconColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    postureDetail,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAlarm
                        ? 'Vui lòng điều chỉnh lại tư thế ngồi!'
                        : (posture == 'good'
                            ? 'Khoảng cách & tư thế ngồi đang ở mức an toàn.'
                            : 'Đang theo dõi tư thế ngồi...'),
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickControlCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
    required bool isActive,
    bool isSwitch = true,
    Function(bool)? onToggle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: isSwitch ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isActive
                        ? activeColor.withOpacity(0.15)
                        : Colors.grey.shade200,
                    child: Icon(
                      icon,
                      color: isActive ? activeColor : Colors.grey,
                      size: 20,
                    ),
                  ),
                  if (isSwitch)
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isActive,
                        activeColor: activeColor,
                        onChanged: onToggle,
                      ),
                    )
                  else
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Colors.grey),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? activeColor : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }
}
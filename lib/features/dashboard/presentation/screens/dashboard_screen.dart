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
  final Function(int)? onNavigateToTab;

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

  void _goToHistoryTab() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(1);
    } else {
      _showSnackBar('Chuyển sang tab Lịch Sử để xem chi tiết');
    }
  }

  int _getIntValue(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _getDoubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // =========================================================================
  // 1. CẤU HÌNH AVATAR VÀ TƯ THẾ REALTIME
  // =========================================================================
  Map<String, dynamic> _getAvatarPostureConfig(
      String posture, String detail, bool alarm) {
    final String pUpper = posture.toUpperCase();
    final String dUpper = detail.toUpperCase();

    if (pUpper.contains('ABSENT') || dUpper.contains('VANG MAT')) {
      return {
        'color': Colors.grey.shade600,
        'bgColor': Colors.grey.shade100,
        'borderColor': Colors.grey.shade300,
        'icon': Icons.person_off_rounded,
        'title': 'Vắng mặt',
        'subtitle': 'Không phát hiện người ngồi trước thiết bị',
        'illustration': '🪑',
      };
    } else if (alarm ||
        pUpper.contains('CRITICAL') ||
        dUpper.contains('NGUY HIEM')) {
      return {
        'color': Colors.red.shade700,
        'bgColor': Colors.red.shade50,
        'borderColor': Colors.red.shade200,
        'icon': Icons.warning_amber_rounded,
        'title': 'Cảnh báo nguy hiểm!',
        'subtitle': 'Ngồi quá sát & thiếu ánh sáng nghiêm trọng',
        'illustration': '⚠️',
      };
    } else if (pUpper.contains('TOO CLOSE') ||
        dUpper.contains('NGOI QUA SAT')) {
      return {
        'color': Colors.orange.shade800,
        'bgColor': Colors.orange.shade50,
        'borderColor': Colors.orange.shade200,
        'icon': Icons.airline_seat_recline_extra_rounded,
        'title': 'Cúi quá sát màn hình!',
        'subtitle': 'Hãy ngồi thẳng lưng và giữ khoảng cách > 35cm',
        'illustration': '🙇',
      };
    } else if (pUpper.contains('LOW LIGHT') ||
        dUpper.contains('THIEU ANH SANG')) {
      return {
        'color': Colors.amber.shade900,
        'bgColor': Colors.amber.shade50,
        'borderColor': Colors.amber.shade200,
        'icon': Icons.wb_incandescent_outlined,
        'title': 'Môi trường thiếu sáng',
        'subtitle': 'Hãy bật thêm đèn học để bảo vệ mắt',
        'illustration': '💡',
      };
    } else {
      return {
        'color': Colors.green.shade700,
        'bgColor': Colors.green.shade50,
        'borderColor': Colors.green.shade200,
        'icon': Icons.sentiment_very_satisfied_rounded,
        'title': 'Tư thế chuẩn',
        'subtitle': 'Khoảng cách và ánh sáng đạt mức tối ưu',
        'illustration': '🧘',
      };
    }
  }

  // =========================================================================
  // 2. CẤU HÌNH KHUYẾN NGHỊ ÁNH SÁNG (LDR - LUX)
  // =========================================================================
  Map<String, dynamic> _getLightConfig(double lux) {
    if (lux < 150) {
      return {
        'status': 'Quá tối cho đọc sách / làm việc',
        'advice':
            'Độ sáng ${lux.toInt()} LUX: Hãy bật thêm đèn bàn hoặc mở cửa sổ.',
        'color': Colors.red.shade700,
        'bgColor': Colors.red.shade50,
        'progress': (lux / 500).clamp(0.0, 1.0),
        'icon': Icons.nightlight_round,
      };
    } else if (lux <= 500) {
      return {
        'status': 'Ánh sáng đạt chuẩn học tập',
        'advice':
            'Độ sáng ${lux.toInt()} LUX: Môi trường vừa đủ tối ưu cho mắt.',
        'color': Colors.green.shade700,
        'bgColor': Colors.green.shade50,
        'progress': (lux / 500).clamp(0.0, 1.0),
        'icon': Icons.wb_sunny_rounded,
      };
    } else {
      return {
        'status': 'Ánh sáng rất mạnh / Chói',
        'advice':
            'Độ sáng ${lux.toInt()} LUX: Tránh ánh nắng chiếu trực tiếp vào mắt.',
        'color': Colors.amber.shade900,
        'bgColor': Colors.amber.shade50,
        'progress': 1.0,
        'icon': Icons.wb_sunny_outlined,
      };
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
            _getDoubleValue(widget.selectedDevice.currentData?.distanceCm);
        double currentLight =
            _getDoubleValue(widget.selectedDevice.currentData?.lightLux);

        String posture = widget.selectedDevice.currentData?.posture ?? 'NORMAL';
        String postureDetail = 'Đang tải...';
        bool isAlarm = false;
        int lastSeenMs = 0;
        int sessionTimeSec = 0;

        bool isBuzzerEnabled =
            widget.selectedDevice.settings?.warningBuzzer ?? true;
        bool isLedEnabled = true;
        bool isSmartAlertEnabled = true;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final rawData =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final data = Map<String, dynamic>.from(rawData);

          if (data['info'] != null && data['info'] is Map) {
            final infoMap = Map<String, dynamic>.from(data['info']);
            deviceName = infoMap['device_name'] ?? deviceName;
          } else {
            deviceName = data['device_name'] ?? deviceName;
          }

          if (data['last_seen'] != null && data['last_seen'] is int) {
            lastSeenMs = data['last_seen'];
          }

          if (data['current_data'] != null) {
            final currentData =
                Map<String, dynamic>.from(data['current_data']);
            currentDistance =
                _getDoubleValue(currentData['distance_cm'] ?? currentDistance);
            currentLight =
                _getDoubleValue(currentData['light_lux'] ?? currentLight);
            posture = currentData['posture'] ?? posture;
            postureDetail = currentData['posture_detail'] ?? 'Bình thường';
            isAlarm = currentData['alarm'] == true;
            sessionTimeSec = _getIntValue(currentData['session_time_sec']);
          }

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

        final avatarConfig =
            _getAvatarPostureConfig(posture, postureDetail, isAlarm);
        final lightConfig = _getLightConfig(currentLight);

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
                      // Banner Trạng thái kết nối
                      _buildDeviceInfoBanner(
                        deviceId: widget.selectedDevice.deviceId,
                        isOnline: isOnline,
                      ),
                      const SizedBox(height: 16),

                      // 1. MÔ PHỎNG TƯ THẾ DẠNG VECTOR AVATAR
                      _buildPostureAvatarCard(avatarConfig, currentDistance),
                      const SizedBox(height: 16),

                      // 2. ĐỒNG HỒ PHIÊN RING PROGRESS (POMODORO 45 PHÚT)
                      _buildSessionProgressCard(sessionTimeSec),
                      const SizedBox(height: 16),

                      // 3. CARD CHỈ SỐ MÔI TRƯỜNG & ÁNH SÁNG LDR
                      _buildEnvironmentLuxCard(currentLight, lightConfig),
                      const SizedBox(height: 20),

                      // Thông số Realtime cơ bản
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
                              value: '${currentLight.toInt()} Lux',
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

                      // Feature Tiles & Tính Năng Mở Rộng
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
                        onTap: _goToHistoryTab,
                      ),
                      _buildFeatureTile(
                        icon: Icons.timer_outlined,
                        color: Colors.teal,
                        title: 'Chế Độ Học Tập (Pomodoro 45 phút)',
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
                          _showSnackBar(
                              'Mở mục Chia Sẻ / AP Config tại danh sách thiết bị');
                        },
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // =========================================================================
  // BUILDERS WIDGET PHỤ TRỢ VISUALLY RICH
  // =========================================================================

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

  Widget _buildPostureAvatarCard(
      Map<String, dynamic> config, double distanceCm) {
    final Color mainColor = config['color'] as Color;
    final Color bgColor = config['bgColor'] as Color;
    final Color borderColor = config['borderColor'] as Color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: mainColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: mainColor, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        config['illustration'].toString(),
                        style: const TextStyle(fontSize: 38),
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: mainColor,
                    child: Icon(
                      config['icon'] as IconData,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config['title'].toString(),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: mainColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config['subtitle'].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.straighten, size: 18, color: Colors.grey),
                  SizedBox(width: 6),
                  Text(
                    'Khoảng cách mắt:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
              Text(
                distanceCm > 0
                    ? '${distanceCm.toStringAsFixed(0)} cm'
                    : '-- cm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: distanceCm > 0 && distanceCm < 35
                      ? Colors.red
                      : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionProgressCard(int sessionTimeSec) {
    const int maxSessionSec = 45 * 60;
    final double progress = (sessionTimeSec / maxSessionSec).clamp(0.0, 1.0);

    final int minutes = sessionTimeSec ~/ 60;
    final int seconds = sessionTimeSec % 60;
    final bool isOverTime = sessionTimeSec >= maxSessionSec;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Phiên Ngồi Học Tập',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text('Mục tiêu 45 phút', style: TextStyle(fontSize: 11)),
                backgroundColor: AppColors.primary,
                labelStyle: TextStyle(color: Colors.white),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOverTime ? Colors.red : AppColors.primary,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isOverTime ? Colors.red : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOverTime ? 'Hãy nghỉ giải lao!' : 'Thời gian phiên',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverTime ? Colors.red : Colors.grey,
                        fontWeight:
                            isOverTime ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isOverTime) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn đã ngồi quá 45 phút! Hãy đứng dậy thư giãn 5 phút.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildEnvironmentLuxCard(
      double lux, Map<String, dynamic> lightConfig) {
    final Color mainColor = lightConfig['color'] as Color;
    final Color bgColor = lightConfig['bgColor'] as Color;
    final double progress = lightConfig['progress'] as double;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(lightConfig['icon'] as IconData, color: mainColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Ánh Sáng Phòng (LDR)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                '${lux.toInt()} LUX',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(mainColor),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lightConfig['status'].toString(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: mainColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lightConfig['advice'].toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
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
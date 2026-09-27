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

  const DashboardScreen({
    super.key,
    required this.userPhone,
    required this.selectedDevice,
    this.onSwitchDevice,
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
    // 🚀 Đã sửa: Trỏ thẳng tới Node độc lập /devices/{deviceId}
    _deviceRef = FirebaseDatabase.instance.ref('devices/$deviceId');
  }

  // Cập nhật trạng thái còi báo lên Firebase (/devices/{deviceId}/settings)
  Future<void> _toggleBuzzer(bool isEnabled) async {
    try {
      await _deviceRef.child('settings').update({
        'warning_buzzer': isEnabled,
      });
    } catch (e) {
      _showSnackBar('Lỗi cập nhật còi báo: $e');
    }
  }

  // Cập nhật ngưỡng khoảng cách & ánh sáng
  Future<void> _updateThresholds(double distance, int light) async {
    try {
      await _deviceRef.child('settings').update({
        'distance_cm': distance,
        'light_lux': light,
      });
      _showSnackBar('Cập nhật ngưỡng thành công');
    } catch (e) {
      _showSnackBar('Lỗi cập nhật ngưỡng: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // Hộp thoại chỉnh sửa ngưỡng
  void _showEditThresholdsDialog(double currentDistance, int currentLight) {
    final distanceController =
        TextEditingController(text: currentDistance.toInt().toString());
    final lightController =
        TextEditingController(text: currentLight.toString());

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Chỉnh Sửa Ngưỡng An Toàn',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: distanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Khoảng cách tối thiểu (cm)',
                  prefixIcon: Icon(Icons.straighten),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ánh sáng tối thiểu (Lux)',
                  prefixIcon: Icon(Icons.wb_sunny_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () async {
                final newDistance =
                    double.tryParse(distanceController.text) ?? currentDistance;
                final newLight =
                    int.tryParse(lightController.text) ?? currentLight;

                Navigator.pop(dialogContext);
                await _updateThresholds(newDistance, newLight);
              },
              child: const Text('Lưu', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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

        double targetDistance =
            widget.selectedDevice.settings?.distanceCm ?? 30.0;
        int targetLight = widget.selectedDevice.settings?.lightLux ?? 400;
        bool isAlertEnabled =
            widget.selectedDevice.settings?.warningBuzzer ?? true;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final rawData =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final data = Map<String, dynamic>.from(rawData);

          // 🚀 Đã sửa: Đọc tên thiết bị từ sub-node "info" trong cấu trúc DB mới[cite: 1]
          if (data['info'] != null && data['info'] is Map) {
            final infoMap = Map<String, dynamic>.from(data['info']);
            deviceName = infoMap['device_name'] ?? deviceName;
          } else {
            deviceName = data['device_name'] ?? deviceName;
          }

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

          if (data['settings'] != null) {
            final settings = Map<String, dynamic>.from(data['settings']);
            targetDistance =
                (settings['distance_cm'] ?? targetDistance).toDouble();
            targetLight = (settings['light_lux'] ?? targetLight).toInt();
            isAlertEnabled = settings['warning_buzzer'] ?? isAlertEnabled;
          }
        }

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
                icon: const Icon(Icons.qr_code_scanner_rounded),
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
                      // Card Cảnh báo & Trạng thái chi tiết
                      _buildPostureCard(
                        posture: posture,
                        postureDetail: postureDetail,
                        isAlarm: isAlarm,
                        targetDistance: targetDistance,
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
                      const SizedBox(height: 16),

                      // Cài đặt ngưỡng an toàn
                      _buildThresholdSettingsCard(targetDistance, targetLight),
                      const SizedBox(height: 12),

                      // Bật/tắt còi báo
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SwitchListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text(
                            'Cảnh báo chuông trên ESP32',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Kích hoạt buzzer khi vi phạm ngưỡng',
                          ),
                          value: isAlertEnabled,
                          activeColor: AppColors.primary,
                          onChanged: (val) => _toggleBuzzer(val),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPostureCard({
    required String posture,
    required String postureDetail,
    required bool isAlarm,
    required double targetDistance,
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

  Widget _buildThresholdSettingsCard(double targetDistance, int targetLight) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cài Đặt Ngưỡng An Toàn',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  onPressed: () => _showEditThresholdsDialog(
                    targetDistance,
                    targetLight,
                  ),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.straighten, color: Colors.blue),
              title: const Text('Ngưỡng khoảng cách tối thiểu'),
              trailing: Text(
                '${targetDistance.toInt()} cm',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.wb_sunny, color: Colors.amber.shade700),
              title: const Text('Ngưỡng ánh sáng tối thiểu'),
              trailing: Text(
                '$targetLight Lux',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
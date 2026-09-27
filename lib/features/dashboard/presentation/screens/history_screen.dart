import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eye_posture/core/constants/app_colors.dart';

class HistoryScreen extends StatefulWidget {
  final String userPhone;
  final String? initialDeviceId; // ID thiết bị truyền sang từ MainScreen (nếu có)

  const HistoryScreen({
    super.key,
    required this.userPhone,
    this.initialDeviceId,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedPeriodIndex = 0;
  final List<String> _periods = ['Hôm nay', '7 ngày qua', '30 ngày qua'];

  String? _selectedDeviceId; // ID thiết bị đang được chọn trong trang Lịch Sử

  @override
  void initState() {
    super.initState();
    _selectedDeviceId = widget.initialDeviceId;
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDeviceId != oldWidget.initialDeviceId &&
        widget.initialDeviceId != null) {
      setState(() {
        _selectedDeviceId = widget.initialDeviceId;
      });
    }
  }

  /// Hàm kiểm tra log có nằm trong khoảng thời gian đang lọc hay không
  bool _isLogInSelectedPeriod(int timestampMs) {
    if (timestampMs <= 0) return false;
    final logDate = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();

    if (_selectedPeriodIndex == 0) {
      return logDate.year == now.year &&
          logDate.month == now.month &&
          logDate.day == now.day;
    } else if (_selectedPeriodIndex == 1) {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      return logDate.isAfter(sevenDaysAgo);
    } else {
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      return logDate.isAfter(thirtyDaysAgo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String cleanPhone = widget.userPhone.trim();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Lịch Sử & Thống Kê',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DatabaseEvent>(
        // 1. Đọc danh sách thiết bị liên kết của người dùng từ /users/{phone}/devices
        stream: FirebaseDatabase.instance.ref('users/$cleanPhone/devices').onValue,
        builder: (context, userDevicesSnapshot) {
          if (userDevicesSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userDevicesSnapshot.hasData ||
              userDevicesSnapshot.data?.snapshot.value == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Chưa có thiết bị nào được liên kết tài khoản.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          final userDevicesMap = Map<String, dynamic>.from(
            userDevicesSnapshot.data!.snapshot.value as Map,
          );

          if (userDevicesMap.isEmpty) {
            return const Center(
              child: Text(
                'Bạn chưa có thiết bị nào.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          // Mặc định chọn thiết bị đầu tiên nếu chưa chọn hoặc ID cũ không tồn tại
          if (_selectedDeviceId == null ||
              !userDevicesMap.containsKey(_selectedDeviceId)) {
            _selectedDeviceId = userDevicesMap.keys.first;
          }

          // 2. Lắng nghe dữ liệu chi tiết của thiết bị đang chọn từ /devices/{_selectedDeviceId}
          return StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('devices/$_selectedDeviceId')
                .onValue,
            builder: (context, deviceDetailSnapshot) {
              if (deviceDetailSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              Map<String, dynamic> selectedDeviceData = {};
              if (deviceDetailSnapshot.hasData &&
                  deviceDetailSnapshot.data?.snapshot.value != null) {
                selectedDeviceData = Map<String, dynamic>.from(
                  deviceDetailSnapshot.data!.snapshot.value as Map,
                );
              }

              // Trích xuất history_logs của thiết bị từ Node /devices/{deviceId}/history_logs
              List<Map<String, dynamic>> allLogs = [];
              if (selectedDeviceData.containsKey('history_logs') &&
                  selectedDeviceData['history_logs'] is Map) {
                final rawLogs = Map<String, dynamic>.from(
                  selectedDeviceData['history_logs'] as Map,
                );
                rawLogs.forEach((key, value) {
                  if (value is Map) {
                    allLogs.add(Map<String, dynamic>.from(value));
                  }
                });
              }

              // Lọc danh sách log theo thời gian
              final filteredLogs = allLogs.where((log) {
                final int timestamp = (log['timestamp'] as num? ?? 0).toInt();
                return _isLogInSelectedPeriod(timestamp);
              }).toList();

              // Sắp xếp nhật ký mới nhất lên đầu
              filteredLogs.sort(
                (a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0),
              );

              // Tính toán tổng số lần và tổng thời gian
              int totalViolationCount = filteredLogs.length;
              int totalViolationDurationSeconds = 0;
              for (var log in filteredLogs) {
                totalViolationDurationSeconds +=
                    (log['duration'] as num? ?? 0).toInt();
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Ô CHỌN THIẾT BỊ (Dropdown Selector)
                    _buildDeviceDropdown(userDevicesMap),
                    const SizedBox(height: 16),

                    // 2. Thanh chọn khoảng thời gian
                    _buildPeriodSelector(),
                    const SizedBox(height: 16),

                    // 3. Thẻ thống kê tổng quan
                    _buildOverviewCards(
                      violationCount: totalViolationCount,
                      violationDurationSeconds: totalViolationDurationSeconds,
                    ),
                    const SizedBox(height: 24),

                    // 4. Tiêu đề danh sách
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nhật ký vi phạm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${filteredLogs.length} bản ghi',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 5. Danh sách chi tiết các bản ghi
                    _buildHistoryList(filteredLogs),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Widget Chọn Thiết Bị
 Widget _buildDeviceDropdown(Map<String, dynamic> userDevicesMap) {
  // Lấy danh sách danh sách Future tải tên cho tất cả thiết bị
  final deviceEntries = userDevicesMap.entries.toList();

  return FutureBuilder<List<DataSnapshot>>(
    future: Future.wait(
      deviceEntries.map((entry) {
        return FirebaseDatabase.instance
            .ref('devices/${entry.key}/info/device_name')
            .get();
      }),
    ),
    builder: (context, snapshot) {
      // Map lưu cặp: key (devId) -> value (tên hiển thị)
      final Map<String, String> deviceNames = {};

      if (snapshot.hasData && snapshot.data != null) {
        for (int i = 0; i < deviceEntries.length; i++) {
          final devId = deviceEntries[i].key;
          final rawValue = snapshot.data![i].value;

          if (rawValue == null) {
            deviceNames[devId] = devId;
          } else if (rawValue is String) {
            deviceNames[devId] = rawValue;
          } else if (rawValue is Map) {
            // Trường hợp Firebase trả về dạng Map
            deviceNames[devId] =
                rawValue['device_name']?.toString() ??
                rawValue['name']?.toString() ??
                devId;
          } else {
            deviceNames[devId] = rawValue.toString();
          }
        }
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.important_devices, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDeviceId,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down_circle_outlined,
                    color: AppColors.primary,
                  ),
                  items: deviceEntries.map((entry) {
                    final String devId = entry.key;
                    final String role = entry.value.toString();
                    final bool isOwner = (role == 'owner');

                    // Tên hiển thị an toàn đã xử lý ép kiểu
                    final String name = deviceNames[devId] ?? devId;

                    return DropdownMenuItem<String>(
                      value: devId,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isOwner
                                  ? Colors.blue.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOwner ? 'Chủ sở hữu' : 'Được chia sẻ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOwner
                                    ? Colors.blue.shade800
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newDeviceId) {
                    if (newDeviceId != null) {
                      setState(() {
                        _selectedDeviceId = newDeviceId;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  /// Widget Chọn Khoảng Thời Gian
  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(_periods.length, (index) {
          final isSelected = _selectedPeriodIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriodIndex = index;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : [],
                ),
                child: Text(
                  _periods[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : Colors.grey[700],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Widget Các Thẻ Thống Kê
  Widget _buildOverviewCards({
    required int violationCount,
    required int violationDurationSeconds,
  }) {
    final int minutes = (violationDurationSeconds / 60).ceil();

    return Row(
      children: [
        _buildStatCard(
          title: 'Số lần vi phạm',
          value: '$violationCount lần',
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          title: 'T.Gian ngồi sai',
          value: '$minutes phút',
          icon: Icons.timer_outlined,
          color: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  /// Widget Danh Sách Nhật Ký Vi Phạm
  Widget _buildHistoryList(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 8),
              const Text(
                'Không có nhật ký vi phạm nào trong khoảng thời gian này.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final log = logs[index];
        final String title = log['title'] ?? 'Vi phạm tư thế';
        final String type = log['type'] ?? 'distance_violation';
        final int durationSeconds = (log['duration'] as num? ?? 0).toInt();
        final int timestamp = (log['timestamp'] as num? ?? 0).toInt();

        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final String timeStr =
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} - ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

        IconData iconData = Icons.warning_rounded;
        Color iconColor = Colors.red;

        if (type == 'distance_violation') {
          iconData = Icons.straighten;
          iconColor = Colors.orange;
        } else if (type == 'posture_violation') {
          iconData = Icons.accessibility_new;
          iconColor = Colors.redAccent;
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.1),
              child: Icon(iconData, color: iconColor),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              timeStr,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${(durationSeconds / 60).ceil()} phút',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
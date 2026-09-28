import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eye_posture/core/constants/app_colors.dart';

class HistoryScreen extends StatefulWidget {
  final String userPhone;
  final String? initialDeviceId;

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

  final List<String> _periods = [
    'Hôm nay',
    '7 ngày qua',
    '30 ngày qua',
  ];

  String? _selectedDeviceId;

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

  bool _isLogInSelectedPeriod(int timestampMs) {
    if (timestampMs <= 0) return false;

    final DateTime logDate =
        DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final DateTime now = DateTime.now();

    switch (_selectedPeriodIndex) {
      case 0:
        return logDate.year == now.year &&
            logDate.month == now.month &&
            logDate.day == now.day;

      case 1:
        final DateTime sevenDaysAgo =
            now.subtract(const Duration(days: 7));

        return !logDate.isBefore(sevenDaysAgo) &&
            !logDate.isAfter(now);

      case 2:
        final DateTime thirtyDaysAgo =
            now.subtract(const Duration(days: 30));

        return !logDate.isBefore(thirtyDaysAgo) &&
            !logDate.isAfter(now);

      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String cleanPhone = widget.userPhone.trim();

    if (cleanPhone.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Không xác định được tài khoản người dùng.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

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
        stream: FirebaseDatabase.instance
            .ref('users/$cleanPhone/devices')
            .onValue,
        builder: (context, userDevicesSnapshot) {
          if (userDevicesSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (userDevicesSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Không thể tải danh sách thiết bị.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${userDevicesSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final dynamic rawValue =
              userDevicesSnapshot.data?.snapshot.value;

          if (rawValue == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chưa có thiết bị nào được liên kết tài khoản.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          Map<String, dynamic> userDevicesMap = {};

          if (rawValue is Map) {
            userDevicesMap = Map<String, dynamic>.from(rawValue);
          }

          if (userDevicesMap.isEmpty) {
            return const Center(
              child: Text(
                'Bạn chưa có thiết bị nào.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          if (_selectedDeviceId == null ||
              !userDevicesMap.containsKey(_selectedDeviceId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              final firstDeviceId = userDevicesMap.keys.first;

              if (_selectedDeviceId != firstDeviceId) {
                setState(() {
                  _selectedDeviceId = firstDeviceId;
                });
              }
            });

            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('devices/$_selectedDeviceId')
                .onValue,
            builder: (context, deviceSnapshot) {
              if (deviceSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (deviceSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 50,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Không thể tải dữ liệu thiết bị.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${deviceSnapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              Map<String, dynamic> selectedDeviceData = {};

              final dynamic deviceRawValue =
                  deviceSnapshot.data?.snapshot.value;

              if (deviceRawValue is Map) {
                selectedDeviceData =
                    Map<String, dynamic>.from(deviceRawValue);
              }

              final List<Map<String, dynamic>> allLogs = [];

              final dynamic historyRaw =
                  selectedDeviceData['history_logs'];

              if (historyRaw is Map) {
                final Map<String, dynamic> rawLogs =
                    Map<String, dynamic>.from(historyRaw);

                rawLogs.forEach((key, value) {
                  if (value is Map) {
                    allLogs.add(
                      Map<String, dynamic>.from(value),
                    );
                  }
                });
              }

              final List<Map<String, dynamic>> filteredLogs =
                  allLogs.where((log) {
                final int timestamp =
                    _getIntValue(log['timestamp']);

                return _isLogInSelectedPeriod(timestamp);
              }).toList();

              filteredLogs.sort((a, b) {
                final int timestampA =
                    _getIntValue(a['timestamp']);

                final int timestampB =
                    _getIntValue(b['timestamp']);

                return timestampB.compareTo(timestampA);
              });

              final int totalViolationCount =
                  filteredLogs.length;

              int totalViolationDurationSeconds = 0;

              for (final log in filteredLogs) {
                totalViolationDurationSeconds +=
                    _getIntValue(log['duration']);
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeviceDropdown(userDevicesMap),
                    const SizedBox(height: 16),
                    _buildPeriodSelector(),
                    const SizedBox(height: 16),
                    _buildOverviewCards(
                      violationCount: totalViolationCount,
                      violationDurationSeconds:
                          totalViolationDurationSeconds,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
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
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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

  int _getIntValue(dynamic value) {
    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  Future<String> _getDeviceName(String deviceId) async {
    try {
      final DataSnapshot snapshot = await FirebaseDatabase
          .instance
          .ref('devices/$deviceId/info')
          .get();

      final dynamic value = snapshot.value;

      if (value is Map) {
        final Map<String, dynamic> info =
            Map<String, dynamic>.from(value);

        final String? deviceName =
            info['device_name']?.toString();

        if (deviceName != null &&
            deviceName.trim().isNotEmpty) {
          return deviceName.trim();
        }

        final String? name =
            info['name']?.toString();

        if (name != null && name.trim().isNotEmpty) {
          return name.trim();
        }
      }

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    } catch (e) {
      debugPrint(
        'Lỗi khi lấy tên thiết bị $deviceId: $e',
      );
    }

    return deviceId;
  }

  Widget _buildDeviceDropdown(
    Map<String, dynamic> userDevicesMap,
  ) {
    final deviceEntries = userDevicesMap.entries.toList();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
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
          const Icon(
            Icons.important_devices,
            color: AppColors.primary,
          ),
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
                  final String deviceId = entry.key;
                  final dynamic roleValue = entry.value;
                  final String role =
                      roleValue?.toString() ?? '';
                  final bool isOwner = role == 'owner';

                  return DropdownMenuItem<String>(
                    value: deviceId,
                    child: FutureBuilder<String>(
                      future: _getDeviceName(deviceId),
                      builder: (context, snapshot) {
                        final String name =
                            snapshot.data ?? deviceId;

                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                  fontSize: 15,
                                ),
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isOwner
                                    ? Colors.blue.shade50
                                    : Colors.orange.shade50,
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: Text(
                                isOwner
                                    ? 'Chủ sở hữu'
                                    : 'Được chia sẻ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.bold,
                                  color: isOwner
                                      ? Colors.blue.shade800
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }).toList(),
                onChanged: (String? newDeviceId) {
                  if (newDeviceId == null) return;

                  setState(() {
                    _selectedDeviceId = newDeviceId;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(
          _periods.length,
          (index) {
            final bool isSelected =
                _selectedPeriodIndex == index;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPeriodIndex = index;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [
                            const BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    _periods[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverviewCards({
    required int violationCount,
    required int violationDurationSeconds,
  }) {
    final int minutes =
        (violationDurationSeconds / 60).ceil();

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
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    List<Map<String, dynamic>> logs,
  ) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 8),
              const Text(
                'Không có nhật ký vi phạm nào '
                'trong khoảng thời gian này.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final Map<String, dynamic> log =
            logs[index];

        final String title =
            log['title']?.toString() ??
                'Vi phạm tư thế';

        final String type =
            log['type']?.toString() ??
                'distance_violation';

        final int durationSeconds =
            _getIntValue(log['duration']);

        final int timestamp =
            _getIntValue(log['timestamp']);

        final DateTime date =
            DateTime.fromMillisecondsSinceEpoch(
          timestamp,
        );

        final String timeStr =
            '${date.hour.toString().padLeft(2, '0')}:'
            '${date.minute.toString().padLeft(2, '0')}'
            ' - '
            '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/'
            '${date.year}';

        IconData iconData =
            Icons.warning_rounded;

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
            side: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  iconColor.withOpacity(0.1),
              child: Icon(
                iconData,
                color: iconColor,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              timeStr,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius:
                    BorderRadius.circular(6),
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

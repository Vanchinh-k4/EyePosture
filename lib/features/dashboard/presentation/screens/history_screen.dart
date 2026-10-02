import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
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

  int _getIntValue(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Tự động chuyển đổi Timestamp Giây (10 chữ số) thành Milliseconds (13 chữ số)
  int _normalizeTimestampMs(dynamic value) {
    int ts = _getIntValue(value);
    if (ts <= 0) return 0;
    if (ts < 10000000000) {
      ts = ts * 1000;
    }
    return ts;
  }

  bool _isLogInSelectedPeriod(int timestampMs) {
    if (timestampMs <= 0) return false;

    final DateTime logDate = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final DateTime now = DateTime.now();

    // Mốc bắt đầu tính từ 00:00:00 ngày hôm nay
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);

    switch (_selectedPeriodIndex) {
      case 0: // Hôm nay
        return !logDate.isBefore(startOfToday);

      case 1: // 7 ngày qua
        final DateTime sevenDaysAgo = startOfToday.subtract(const Duration(days: 7));
        return !logDate.isBefore(sevenDaysAgo);

      case 2: // 30 ngày qua
        final DateTime thirtyDaysAgo = startOfToday.subtract(const Duration(days: 30));
        return !logDate.isBefore(thirtyDaysAgo);

      default:
        return true;
    }
  }

  String _formatTimeOnly(int timestamp) {
    if (timestamp <= 0) return '--:--';
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('HH:mm').format(date);
  }

  // CÁCH MỚI: Trả về RichText để ngày có màu xám riêng biệt
  Widget _buildSessionTitleText(int start, int end, bool isRealtimeActive) {
    final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(start);
    final DateTime endDate = DateTime.fromMillisecondsSinceEpoch(end);

    final bool isSameDay = startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;

    final TextStyle defaultStyle = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 13,
      color: Colors.black87,
    );

    final TextStyle grayStyle = const TextStyle(
      fontWeight: FontWeight.normal,
      fontSize: 12,
      color: Colors.grey,
    );

    if (isRealtimeActive) {
      return Text.rich(
        TextSpan(
          style: defaultStyle,
          children: [
            TextSpan(text: 'Từ ${_formatTimeOnly(start)} '),
            TextSpan(text: '(${DateFormat('dd/MM').format(startDate)}) ', style: grayStyle),
            const TextSpan(text: 'đến Hiện tại'),
          ],
        ),
      );
    } else if (isSameDay) {
      return Text.rich(
        TextSpan(
          style: defaultStyle,
          children: [
            TextSpan(text: 'Từ ${_formatTimeOnly(start)} đến ${_formatTimeOnly(end)} '),
            TextSpan(text: '(${DateFormat('dd/MM/yyyy').format(startDate)})', style: grayStyle),
          ],
        ),
      );
    } else {
      return Text.rich(
        TextSpan(
          style: defaultStyle,
          children: [
            TextSpan(text: 'Từ ${_formatTimeOnly(start)} '),
            TextSpan(text: '${DateFormat('dd/MM/yyyy').format(startDate)} ', style: grayStyle),
            TextSpan(text: 'đến ${_formatTimeOnly(end)} '),
            TextSpan(text: DateFormat('dd/MM/yyyy').format(endDate), style: grayStyle),
          ],
        ),
      );
    }
  }

  void _showWorkTimeChartBottomSheet(
      BuildContext context, int totalWorkSeconds, List<Map<String, dynamic>> sessions) {
    final int totalMins = totalWorkSeconds ~/ 60;
    final int totalSecs = totalWorkSeconds % 60;
    
    String totalDisplayStr = '';
    if (totalMins >= 60) {
      totalDisplayStr = '${(totalMins / 60).toStringAsFixed(1)} giờ';
    } else if (totalMins > 0) {
      totalDisplayStr = '$totalMins phút ${totalSecs > 0 ? "$totalSecs giây" : ""}';
    } else {
      totalDisplayStr = '$totalSecs giây';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chi tiết phiên ngồi máy tính',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.computer, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tổng thời gian: $totalDisplayStr',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Các phiên ghi nhận (${sessions.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: sessions.isEmpty
                        ? const Center(
                            child: Text(
                              'Không có ghi nhận phiên làm việc nào.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: sessions.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = sessions[index];
                              final int start = _normalizeTimestampMs(item['start_timestamp']);
                              final int end = _normalizeTimestampMs(item['end_timestamp']);
                              final int duration = _getIntValue(item['duration_seconds']);
                              final bool isRealtimeActive = item['is_realtime_active'] == true;

                              final int pMins = duration ~/ 60;
                              final int pSecs = duration % 60;

                              String durationText = '';
                              if (pMins > 0) {
                                durationText = pSecs > 0 ? '$pMins phút $pSecs giây' : '$pMins phút';
                              } else {
                                durationText = '$pSecs giây';
                              }

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  isRealtimeActive
                                      ? Icons.play_circle_fill
                                      : Icons.check_circle,
                                  color: isRealtimeActive ? Colors.green : Colors.blue,
                                ),
                                // Hiển thị ngày tháng dạng Text.rich màu xám
                                title: _buildSessionTitleText(start, end, isRealtimeActive),
                                subtitle: Text(
                                  isRealtimeActive
                                      ? 'Đang hoạt động (Realtime)'
                                      : 'Đã hoàn thành',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isRealtimeActive
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isRealtimeActive ? Colors.green.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    durationText,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isRealtimeActive ? Colors.green.shade800 : Colors.blue.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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
            return const Center(child: CircularProgressIndicator());
          }

          if (userDevicesSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 50, color: Colors.red.shade300),
                    const SizedBox(height: 12),
                    const Text(
                      'Không thể tải danh sách thiết bị.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final dynamic rawValue = userDevicesSnapshot.data?.snapshot.value;

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

            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('devices/$_selectedDeviceId')
                .onValue,
            builder: (context, deviceSnapshot) {
              if (deviceSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              Map<String, dynamic> selectedDeviceData = {};
              final dynamic deviceRawValue =
                  deviceSnapshot.data?.snapshot.value;

              if (deviceRawValue is Map) {
                selectedDeviceData = Map<String, dynamic>.from(deviceRawValue);
              }

              // --- 1. TẢI VÀ TÍNH TOÁN DỮ LIỆU PHIÊN LÀM VIỆC (SESSIONS) ---
              final dynamic sessionsRaw = selectedDeviceData['sessions'];
              final int lastSeenMs = _normalizeTimestampMs(selectedDeviceData['last_seen']);
              final int nowMs = DateTime.now().millisecondsSinceEpoch;

              final bool isOnline = lastSeenMs > 0 && (nowMs - lastSeenMs).abs() < 30000;

              final List<Map<String, dynamic>> filteredSessions = [];
              int totalSessionDurationSeconds = 0;

              if (sessionsRaw is Map) {
                final Map<String, dynamic> rawSessions =
                    Map<String, dynamic>.from(sessionsRaw);

                rawSessions.forEach((key, value) {
                  if (value is Map) {
                    final sessionMap = Map<String, dynamic>.from(value);

                    int startMs = _normalizeTimestampMs(sessionMap['start_timestamp']);
                    int endMs = _normalizeTimestampMs(sessionMap['end_timestamp']);
                    int durationSec = _getIntValue(sessionMap['duration_seconds']);
                    String status = sessionMap['status']?.toString() ?? '';

                    if (startMs > 0 && _isLogInSelectedPeriod(startMs)) {
                      DateTime startTime = DateTime.fromMillisecondsSinceEpoch(startMs);
                      DateTime endTime;
                      bool isRealtimeActive = false;

                      if (status == 'completed' && endMs > 0) {
                        endTime = DateTime.fromMillisecondsSinceEpoch(endMs);
                      } else if (!isOnline) {
                        endTime = startTime.add(Duration(seconds: durationSec));
                        
                        if (status == 'active') {
                          final sessionRef = FirebaseDatabase.instance
                              .ref('devices/$_selectedDeviceId/sessions/$key');
                          
                          sessionRef.update({
                            'status': 'completed',
                            'end_timestamp': endTime.millisecondsSinceEpoch,
                          });
                        }
                      } else {
                        endTime = DateTime.now();
                        isRealtimeActive = true;
                        
                        final int realTimeDuration = (endTime.millisecondsSinceEpoch - startMs) ~/ 1000;
                        if (realTimeDuration > durationSec) {
                          durationSec = realTimeDuration;
                        }
                      }

                      filteredSessions.add({
                        ...sessionMap,
                        'start_timestamp': startMs,
                        'end_timestamp': endTime.millisecondsSinceEpoch,
                        'duration_seconds': durationSec,
                        'is_realtime_active': isRealtimeActive,
                      });

                      totalSessionDurationSeconds += durationSec;
                    }
                  }
                });

                filteredSessions.sort((a, b) => (b['start_timestamp'] as int)
                    .compareTo(a['start_timestamp'] as int));
              }

              // --- 2. XỬ LÝ LỊCH SỬ VI PHẠM (HISTORY_LOGS) ---
              final List<Map<String, dynamic>> allLogs = [];
              final dynamic historyRaw = selectedDeviceData['history_logs'];

              if (historyRaw is Map) {
                final Map<String, dynamic> rawLogs =
                    Map<String, dynamic>.from(historyRaw);
                rawLogs.forEach((key, value) {
                  if (value is Map) {
                    allLogs.add(Map<String, dynamic>.from(value));
                  }
                });
              }

              final List<Map<String, dynamic>> filteredLogs =
                  allLogs.where((log) {
                final int timestamp = _normalizeTimestampMs(log['timestamp']);
                return _isLogInSelectedPeriod(timestamp);
              }).toList();

              filteredLogs.sort((a, b) {
                final int timestampA = _normalizeTimestampMs(a['timestamp']);
                final int timestampB = _normalizeTimestampMs(b['timestamp']);
                return timestampB.compareTo(timestampA);
              });

              final int totalViolationCount = filteredLogs.length;
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
                      violationDurationSeconds: totalViolationDurationSeconds,
                      totalWorkSeconds: totalSessionDurationSeconds,
                      sessions: filteredSessions,
                    ),
                    const SizedBox(height: 24),
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

  Future<String> _getDeviceName(String deviceId) async {
    try {
      final DataSnapshot snapshot = await FirebaseDatabase.instance
          .ref('devices/$deviceId/info')
          .get();

      final dynamic value = snapshot.value;

      if (value is Map) {
        final Map<String, dynamic> info = Map<String, dynamic>.from(value);
        final String? deviceName = info['device_name']?.toString();
        if (deviceName != null && deviceName.trim().isNotEmpty) {
          return deviceName.trim();
        }
        final String? name = info['name']?.toString();
        if (name != null && name.trim().isNotEmpty) {
          return name.trim();
        }
      }
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    } catch (e) {
      debugPrint('Lỗi khi lấy tên thiết bị $deviceId: $e');
    }
    return deviceId;
  }

  Widget _buildDeviceDropdown(Map<String, dynamic> userDevicesMap) {
    final deviceEntries = userDevicesMap.entries.toList();

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
                  final String deviceId = entry.key;
                  final dynamic roleValue = entry.value;
                  final bool isOwner = roleValue?.toString() == 'owner';

                  return DropdownMenuItem<String>(
                    value: deviceId,
                    child: FutureBuilder<String>(
                      future: _getDeviceName(deviceId),
                      builder: (context, snapshot) {
                        final String name = snapshot.data ?? deviceId;
                        return Row(
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
                                  horizontal: 6, vertical: 2),
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
            final bool isSelected = _selectedPeriodIndex == index;
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
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primary : Colors.grey[700],
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
    required int totalWorkSeconds,
    required List<Map<String, dynamic>> sessions,
  }) {
    final int violationMinutes = (violationDurationSeconds / 60).ceil();
    
    final int mins = totalWorkSeconds ~/ 60;
    final int secs = totalWorkSeconds % 60;

    String workTimeText = '';
    if (mins >= 60) {
      workTimeText = '${(mins / 60).toStringAsFixed(1)} giờ';
    } else if (mins > 0) {
      workTimeText = '$mins phút ${secs > 0 ? "$secs giây" : ""}';
    } else {
      workTimeText = '$secs giây';
    }

    return Column(
      children: [
        InkWell(
          onTap: () => _showWorkTimeChartBottomSheet(
              context, totalWorkSeconds, sessions),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.laptop_chromebook_rounded,
                    color: Colors.blue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workTimeText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Thời gian ngồi máy tính (Nhấn xem ${sessions.length} phiên)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.list_alt_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
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
              value: '$violationMinutes phút',
              icon: Icons.timer_outlined,
              color: Colors.redAccent,
            ),
          ],
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

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
        final Map<String, dynamic> log = logs[index];
        final String title = log['title']?.toString() ?? 'Vi phạm tư thế';
        final String type = log['type']?.toString() ?? 'distance_violation';
        final int durationSeconds = _getIntValue(log['duration']);
        final int timestamp = _normalizeTimestampMs(log['timestamp']);

        final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final String timeOnlyStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        final String dateOnlyStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            // Phần ngày trong nhật ký vi phạm cũng được tô màu xám
            subtitle: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                children: [
                  TextSpan(text: '$timeOnlyStr - '),
                  TextSpan(
                    text: dateOnlyStr,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:eye_posture/core/constants/app_colors.dart';
import 'package:eye_posture/models/user_device_model.dart';
import 'add_device_screen.dart';

class DeviceSelectionScreen extends StatelessWidget {
  final String userPhone;
  final Function(DeviceModel) onSelectDevice;

  const DeviceSelectionScreen({
    super.key,
    required this.userPhone,
    required this.onSelectDevice,
  });

  void _showEditDeviceDialog(BuildContext context, DeviceModel device) {
    showDialog(
      context: context,
      builder: (dialogContext) => _EditDeviceDialogContent(
        device: device,
        parentContext: context,
      ),
    );
  }

  void _showSharedUsersDialog(BuildContext context, DeviceModel device, bool isOnline) {
    showDialog(
      context: context,
      builder: (dialogContext) => _SharedUsersDialogContent(
        device: device,
        parentContext: context,
        isOnline: isOnline,
        userPhone: userPhone,
      ),
    );
  }

  void _confirmDeleteDevice(BuildContext context, DeviceModel device, bool isOwner) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isOwner ? 'Xác nhận xóa thiết bị' : 'Hủy theo dõi thiết bị'),
        content: Text(
          isOwner
              ? 'Bạn là Chủ sở hữu của "${device.deviceName}". Khi xóa, thiết bị sẽ nhận lệnh ngắt kết nối, khôi phục cài đặt gốc và toàn bộ dữ liệu trên Cloud sẽ bị xóa sạch.'
              : 'Bạn có chắc muốn hủy quyền giám sát thiết bị "${device.deviceName}" khỏi tài khoản của bạn?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final String cleanPhone = userPhone.trim();
              final dbRef = FirebaseDatabase.instance.ref();

              Navigator.pop(dialogContext);

              try {
                if (isOwner) {
                  try {
                    await dbRef
                        .child('devices/${device.deviceId}/info/reset_pending')
                        .set(true)
                        .timeout(const Duration(seconds: 2));
                    await Future.delayed(const Duration(milliseconds: 1500));
                  } catch (_) {
                    debugPrint('ESP32 đang OFFLINE, bỏ qua chờ nhận tín hiệu reset.');
                  }

                  final sharedSnap = await dbRef
                      .child('devices/${device.deviceId}/shared_users')
                      .get();

                  final Map<String, dynamic> updates = {};
                  updates['devices/${device.deviceId}'] = null;
                  updates['users/$cleanPhone/devices/${device.deviceId}'] = null;

                  if (sharedSnap.exists && sharedSnap.value is Map) {
                    final sharedUsers = Map<String, dynamic>.from(sharedSnap.value as Map);
                    for (String sharedPhone in sharedUsers.keys) {
                      updates['users/$sharedPhone/devices/${device.deviceId}'] = null;
                    }
                  }

                  await dbRef.update(updates).timeout(const Duration(seconds: 8));

                } else {
                  final Map<String, dynamic> updates = {
                    'users/$cleanPhone/devices/${device.deviceId}': null,
                    'devices/${device.deviceId}/shared_users/$cleanPhone': null,
                  };

                  await dbRef.update(updates).timeout(const Duration(seconds: 8));
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isOwner
                          ? 'Đã xóa hoàn toàn thiết bị "${device.deviceName}"!'
                          : 'Đã hủy theo dõi thiết bị "${device.deviceName}".'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Lỗi khi thực hiện xóa thiết bị: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi khi xóa thiết bị: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              isOwner ? 'Xóa hoàn toàn' : 'Hủy liên kết',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String cleanPhone = userPhone.trim();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('EyePosture'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users/$cleanPhone').onValue,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || userSnapshot.data?.snapshot.value == null) {
            return const Center(child: Text('Không tìm thấy dữ liệu người dùng!'));
          }

          final userData = Map<String, dynamic>.from(
            userSnapshot.data!.snapshot.value as Map<dynamic, dynamic>,
          );
          final String userName = userData['name'] ?? 'Người dùng';
          final Map rawDevicesMap = (userData['devices'] is Map) ? userData['devices'] as Map : {};

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  color: AppColors.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      'Xin chào, $userName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text('SĐT: $cleanPhone'),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Danh sách thiết bị của bạn:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${rawDevicesMap.length} Thiết bị',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Expanded(
  child: rawDevicesMap.isEmpty
      ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.devices_other,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              const Text(
                'Bạn chưa liên kết thiết bị nào.\nNhấn nút bên dưới để thêm thiết bị!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        )
      : ListView.builder(
          // Cộng thêm 1 item để chứa khung Lưu ý ở cuối danh sách
          itemCount: rawDevicesMap.length + 1,
          itemBuilder: (context, index) {
            // Nếu là item cuối cùng -> Hiển thị khung Mẹo / Lưu ý
            if (index == rawDevicesMap.length) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8, bottom: 80), // Padding bottom 80px để chừa chỗ cho FAB
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mẹo: Nếu thiết bị mất kết nối (Offline), hãy khởi động lại thiết bị hoặc mở mục "Chia sẻ / AP Config" để cấu hình lại Wi-Fi.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Các item thiết bị bình thường
            final String deviceId = rawDevicesMap.keys.elementAt(index).toString();
            final String role = rawDevicesMap[deviceId].toString();
            final bool isOwner = (role == 'owner');

            return _DeviceTileItem(
              key: ValueKey(deviceId),
              deviceId: deviceId,
              isOwner: isOwner,
              onSelectDevice: onSelectDevice,
              onEdit: (device) => _showEditDeviceDialog(context, device),
              onShare: (device, isOnline) => _showSharedUsersDialog(context, device, isOnline),
              onDelete: (device) => _confirmDeleteDevice(context, device, isOwner),
            );
          },
        ),
)
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDeviceScreen(
                userPhone: userPhone,
              ),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Thêm thiết bị',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

// ==========================================
// ITEM HIỂN THỊ CHI TIẾT 1 THIẾT BỊ
// ==========================================
class _DeviceTileItem extends StatelessWidget {
  final String deviceId;
  final bool isOwner;
  final Function(DeviceModel) onSelectDevice;
  final Function(DeviceModel) onEdit;
  final Function(DeviceModel, bool) onShare;
  final Function(DeviceModel) onDelete;

  const _DeviceTileItem({
    super.key,
    required this.deviceId,
    required this.isOwner,
    required this.onSelectDevice,
    required this.onEdit,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('devices/$deviceId').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const SizedBox.shrink();
        }

        final rawMap = Map<String, dynamic>.from(
          snapshot.data!.snapshot.value as Map<dynamic, dynamic>,
        );
        final DeviceModel device = DeviceModel.fromMap(deviceId, rawMap);

        // 1. Đọc last_seen linh hoạt (từ root node hoặc info node)
        final Map infoMap = (rawMap['info'] is Map) ? rawMap['info'] as Map : {};
        final dynamic rawLastSeen = rawMap['last_seen'] ?? infoMap['last_seen'];
        final int lastSeen = (rawLastSeen is int) ? rawLastSeen : 0;

        final bool isOnline = lastSeen > 0 &&
            (DateTime.now().millisecondsSinceEpoch - lastSeen) <= 60000;

        // 2. Đọc tên Wi-Fi (SSID) từ wifi_info
        final Map wifiMap = (rawMap['wifi_info'] is Map) ? rawMap['wifi_info'] as Map : {};
        final String wifiSsid = wifiMap['ssid']?.toString() ?? 'Chưa cấu hình';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isOnline ? 2 : 0,
          color: isOnline ? Colors.white : Colors.grey.shade100,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isOnline ? Colors.green.shade100 : Colors.grey.shade300,
              child: Icon(
                Icons.memory,
                color: isOnline ? Colors.green : Colors.grey.shade700,
              ),
            ),
            
            // --- TÊN THIẾT BỊ ---
            title: Text(
              device.deviceName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOnline ? Colors.black87 : Colors.grey.shade700,
              ),
            ),

            // --- THÔNG TIN BÊN TRÁI: ID VÀ TÊN WIFI ---
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'ID: ${device.deviceId}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                // THÊM TÊN WIFI VÀO BÊN DƯỚI ID
                if(isOnline) ...[
                  const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.wifi, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Wi-Fi: $wifiSsid',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
            ),

            // --- CỘT BÊN PHẢI: CHỦ SỞ HỮU VÀ TRẠNG THÁI TRỰC TUYẾN ---
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Tag Vai trò
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOwner ? Colors.blue.shade50 : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOwner ? 'Chủ sở hữu' : 'Được chia sẻ',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOwner ? Colors.blue.shade800 : Colors.purple.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // CHUYỂN TRẠNG THÁI TRỰC TUYẾN XUỐNG DƯỚI CỘT BÊN PHẢI
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOnline ? 'Trực tuyến' : 'Ngoại tuyến',
                          style: TextStyle(
                            fontSize: 11,
                            color: isOnline ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 4),

                // Nút Menu 3 chấm
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit(device);
                    if (value == 'share') onShare(device, isOnline);
                    if (value == 'delete') onDelete(device);
                  },
                  itemBuilder: (context) => [
                    if (isOwner)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Sửa tên / WiFi'),
                          ],
                        ),
                      ),
                    if (isOwner)
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, size: 20),
                            SizedBox(width: 8),
                            Text('Chia sẻ / AP Config'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            isOwner ? Icons.delete_forever : Icons.link_off,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOwner ? 'Xóa thiết bị' : 'Hủy theo dõi',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Sự kiện Click vào Card
            onTap: () {
              if (isOnline) {
                onSelectDevice(device);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Thiết bị "${device.deviceName}" đang Ngoại tuyến! Hãy bật nguồn thiết bị.'),
                    backgroundColor: Colors.orange.shade800,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}

// ==========================================
// DIALOG SỬA TÊN & WIFI TỪ CLOUD
// ==========================================
class _EditDeviceDialogContent extends StatefulWidget {
  final DeviceModel device;
  final BuildContext parentContext;

  const _EditDeviceDialogContent({
    required this.device,
    required this.parentContext,
  });

  @override
  State<_EditDeviceDialogContent> createState() => _EditDeviceDialogContentState();
}

class _EditDeviceDialogContentState extends State<_EditDeviceDialogContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ssidController;
  late final TextEditingController _passController;
  bool _isSaving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device.deviceName);
    _ssidController = TextEditingController(text: widget.device.wifiInfo?.ssid ?? '');
    _passController = TextEditingController(text: widget.device.wifiInfo?.password ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final String newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tên gợi nhớ không được để trống!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dbRef = FirebaseDatabase.instance.ref('devices/${widget.device.deviceId}');

      await dbRef.update({
        'info/device_name': newName,
        'wifi_info/ssid': _ssidController.text.trim(),
        'wifi_info/password': _passController.text.trim(),
      });

      if (mounted) Navigator.pop(context);

      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật thông tin thiết bị thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Sửa: ${widget.device.deviceName}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lưu ý: ESP32 chỉ kết nối được Wi-Fi 2.4GHz. Không nhập mạng 5GHz!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên gợi nhớ',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: 'Tên Wi-Fi (SSID 2.4GHz)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên Wi-Fi';
                  }
                  final lowerVal = val.toLowerCase();
                  if (lowerVal.contains('_5g') || lowerVal.contains('5ghz')) {
                    return 'Thiết bị không hỗ trợ mạng 5GHz!';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _passController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu Wi-Fi',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Vui lòng nhập mật khẩu' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _isSaving
              ? null
              : () {
                  if (_formKey.currentState!.validate()) {
                    _saveChanges();
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Lưu', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ==========================================
// DIALOG QUẢN LÝ CHIA SẺ & CẤU HÌNH WIFI AP
// ==========================================
class _SharedUsersDialogContent extends StatefulWidget {
  final DeviceModel device;
  final BuildContext parentContext;
  final bool isOnline;
  final String userPhone;

  const _SharedUsersDialogContent({
    required this.device,
    required this.parentContext,
    required this.isOnline,
    required this.userPhone,
  });

  @override
  State<_SharedUsersDialogContent> createState() => _SharedUsersDialogContentState();
}

class _SharedUsersDialogContentState extends State<_SharedUsersDialogContent> {
  late final TextEditingController _addPhoneController;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _addPhoneController = TextEditingController();
  }

  @override
  void dispose() {
    _addPhoneController.dispose();
    super.dispose();
  }

  Widget _buildStepItem({
    required String step,
    required String text,
    Widget? extraWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: Colors.amber.shade800,
            child: Text(
              step,
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                if (extraWidget != null) extraWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CHỈ GỬI SSID VÀ PASSWORD SANG ESP32 (KHÔNG THÊM THIẾT BỊ MỚI)
  // =========================================================================
  Future<bool> _sendOnlyWifiCredentialsViaHTTP({
    required String wifiSsid,
    required String wifiPass,
  }) async {
    try {
      final url = Uri.parse('http://192.168.4.1/config');
      
      // Payload gọn nhẹ: chỉ có SSID và Password
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ssid': wifiSsid,
          'password': wifiPass,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Lỗi gửi Wi-Fi sang ESP32: $e');
      return false;
    }
  }

  // CHỈ CẬP NHẬT LẠI NODE WIFI_INFO TRÊN DB SẴN CÓ
  Future<void> _updateWifiInfoOnFirebaseSilently({
    required String wifiSsid,
    required String wifiPass,
  }) async {
    final dbRef = FirebaseDatabase.instance.ref('devices/${widget.device.deviceId}/wifi_info');
    await dbRef.update({
      'ssid': wifiSsid,
      'password': wifiPass,
    });
  }

  // DIALOG CẤU HÌNH WIFI AP (CHỈ NHẬP WIFI)
  void _openApConfigDialog(BuildContext parentContext) {
    final formKey = GlobalKey<FormState>();
    final wifiSsidController = TextEditingController(text: widget.device.wifiInfo?.ssid ?? '');
    final wifiPasswordController = TextEditingController(text: widget.device.wifiInfo?.password ?? '');

    final String deviceId = widget.device.deviceId;
    final String macAddress = widget.device.macAddress;
    final String rawQr = 'EP_$deviceId';

    bool isSendingHTTP = false;
    bool isObscurePassword = true;

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Cấu Hình Wi-Fi Thiết Bị',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thiết bị: ${widget.device.deviceName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: $deviceId | MAC: $macAddress',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.wifi_find, size: 16, color: Colors.amber.shade800),
                                const SizedBox(width: 4),
                                Text(
                                  'Hướng dẫn kết nối ESP32:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildStepItem(
                              step: '1',
                              text: 'Mở Cài đặt Wi-Fi trên điện thoại.',
                            ),
                            _buildStepItem(
                              step: '2',
                              text: 'Bắt mạng Wi-Fi AP do thiết bị phát:',
                              extraWidget: Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: SelectableText(
                                  rawQr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            _buildStepItem(
                              step: '3',
                              text: 'Nhập thông tin Wi-Fi bên dưới và nhấn "Xác Nhận".',
                            ),
                            const Divider(height: 16, color: Colors.amber),
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.redAccent),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Lưu ý: ESP32 CHỈ hỗ trợ Wi-Fi 2.4GHz. Không chọn mạng 5GHz!',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: wifiSsidController,
                        enabled: !isSendingHTTP,
                        decoration: const InputDecoration(
                          labelText: 'Tên Wi-Fi nhà bạn (2.4GHz)',
                          prefixIcon: Icon(Icons.wifi),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập tên Wi-Fi';
                          }
                          final lowerVal = val.toLowerCase();
                          if (lowerVal.contains('_5g') || lowerVal.contains('5ghz')) {
                            return 'Thiết bị không hỗ trợ mạng 5GHz!';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: wifiPasswordController,
                        enabled: !isSendingHTTP,
                        obscureText: isObscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu Wi-Fi',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isObscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                isObscurePassword = !isObscurePassword;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Vui lòng nhập mật khẩu' : null,
                      ),

                      if (isSendingHTTP) ...[
                        const SizedBox(height: 20),
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text(
                          'Đang truyền thông tin Wi-Fi sang ESP32...',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: isSendingHTTP
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isSendingHTTP = true;
                            });

                            final String cleanSsid = wifiSsidController.text.trim();
                            final String cleanPass = wifiPasswordController.text.trim();

                            // CHỈ GỬI SSID VA PASS SANG ESP32
                            bool httpSuccess = await _sendOnlyWifiCredentialsViaHTTP(
                              wifiSsid: cleanSsid,
                              wifiPass: cleanPass,
                            );

                            if (!dialogContext.mounted) return;

                            if (httpSuccess) {
                              // ĐỒNG BỘ NÚT WIFI_INFO LÊN FIREBASE MÀ KHÔNG ĐỤNG ĐẾN THIẾT BỊ KHÁC
                              await _updateWifiInfoOnFirebaseSilently(
                                wifiSsid: cleanSsid,
                                wifiPass: cleanPass,
                              );

                              if (!dialogContext.mounted) return;

                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã truyền Wi-Fi thành công! ESP32 đang kết nối lại...'),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              Navigator.of(dialogContext).pop();
                            } else {
                              setDialogState(() {
                                isSendingHTTP = false;
                              });

                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Lỗi! Hãy đảm bảo điện thoại đã kết nối vào mạng Wi-Fi "$rawQr".',
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Xác Nhận', style: TextStyle(color: Colors.white)),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
  // Trả về SĐT chuẩn 10 số (đầu 0) nếu hợp lệ, trả về null nếu sai
String? formatPhoneToLocal(String rawPhone) {
  // Bỏ khoảng trắng, dấu gạch ngang và các ký tự không phải số (trừ dấu +)
  String phone = rawPhone.trim().replaceAll(' ', '').replaceAll('-', '');

  // Quy đổi các dạng +84 / 84 về đầu số 0
  if (phone.startsWith('+84')) {
    phone = '0${phone.substring(3)}';
  } else if (phone.startsWith('84') && phone.length == 11) {
    phone = '0${phone.substring(2)}';
  }

  // 🟢 Regex chuẩn SĐT di động Việt Nam: Bắt đầu bằng 0
  final vnPhoneRegex = RegExp(r'^0[3|5|7|8|9][0-9]{8}$');

  if (!vnPhoneRegex.hasMatch(phone)) {
    return null; // Không phải số điện thoại 10 số hợp lệ tại Việt Nam
  }

  return phone;
}

  @override
Widget build(BuildContext context) {
  final bool isOffline = !widget.isOnline;

  return AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text('Tài khoản liên kết: ${widget.device.deviceName}'),
    content: SizedBox(
      width: double.maxFinite,
      // BỌC TRONG SingleChildScrollView ĐỂ TRÁNH LỖI OVERFLOW 
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== KHU VỰC CẤU HÌNH WIFI KHI OFFLINE ====================
            if (isOffline) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Thiết bị đang Ngoại tuyến (Offline)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Kết nối điện thoại vào Wi-Fi do thiết bị phát ra để truyền Wi-Fi mới:',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.settings_remote, size: 16),
                        label: const Text(
                          'Cấu hình lại Wi-Fi AP',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          _openApConfigDialog(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ==================== THÊM TÀI KHOẢN MỚI ====================
            const Text(
              'Thêm tài khoản mới:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addPhoneController,
                    keyboardType: TextInputType.phone,
                    enabled: !_isAdding,
                    decoration: const InputDecoration(
                      hintText: 'Nhập SĐT cần chia sẻ',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    padding: const EdgeInsets.symmetric(horizontal: 12),
  ),
  onPressed: _isAdding
    ? null
    : () async {
        final rawPhone = _addPhoneController.text.trim();
        if (rawPhone.isEmpty) return;

        // 🟢 1. Quy đổi SĐT & Kiểm tra định dạng hợp lệ
        final targetPhone = formatPhoneToLocal(rawPhone);

        if (targetPhone == null) {
          if (widget.parentContext.mounted) {
            ScaffoldMessenger.of(widget.parentContext).showSnackBar(
              const SnackBar(
                content: Text('Số điện thoại không đúng định dạng! Vui lòng kiểm tra lại.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final ownerPhone = formatPhoneToLocal(widget.device.ownerPhone);

        // 🟢 2. So sánh với số của chủ sở hữu
        if (targetPhone == ownerPhone) {
          if (widget.parentContext.mounted) {
            ScaffoldMessenger.of(widget.parentContext).showSnackBar(
              const SnackBar(
                content: Text('Không thể chia sẻ cho chính tài khoản chủ sở hữu!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() => _isAdding = true);

        try {
          final dbRef = FirebaseDatabase.instance.ref();

          // 🟢 3. Kiểm tra trong shared_users theo SĐT chuẩn đã lọc
          final existingSnap = await dbRef
              .child('devices/${widget.device.deviceId}/shared_users/$targetPhone')
              .get();

          if (existingSnap.exists && existingSnap.value != null) {
            if (widget.parentContext.mounted) {
              ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                const SnackBar(
                  content: Text('Số điện thoại này đã được chia sẻ từ trước!'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          // 🟢 4. Kiểm tra user tồn tại theo SĐT chuẩn
          final userSnap = await dbRef.child('users/$targetPhone').get();

          if (!userSnap.exists || userSnap.value == null) {
            if (widget.parentContext.mounted) {
              ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                const SnackBar(
                  content: Text('Số điện thoại chưa đăng ký ứng dụng!'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          // 🟢 5. Cập nhật dữ liệu
          final Map<String, dynamic> updates = {
            'devices/${widget.device.deviceId}/shared_users/$targetPhone': true,
            'users/$targetPhone/devices/${widget.device.deviceId}': 'viewer',
          };

          await dbRef.update(updates);

          _addPhoneController.clear();
          if (widget.parentContext.mounted) {
            ScaffoldMessenger.of(widget.parentContext).showSnackBar(
              SnackBar(
                content: Text('Đã chia sẻ thành công cho SĐT: $targetPhone'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (widget.parentContext.mounted) {
            ScaffoldMessenger.of(widget.parentContext).showSnackBar(
              SnackBar(
                content: Text('Có lỗi xảy ra: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isAdding = false);
          }
        }
        },
  child: _isAdding
      ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
      : const Text('Thêm', style: TextStyle(color: Colors.white)),
)
              ],
            ),
            const Divider(height: 24),

            // ==================== DANH SÁCH ĐÃ CHIA SẺ ====================
            const Text(
              'Danh sách đã chia sẻ:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('devices/${widget.device.deviceId}/shared_users')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Chưa chia sẻ cho tài khoản nào.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  );
                }

                final sharedMap = Map<String, dynamic>.from(
                  snapshot.data!.snapshot.value as Map<dynamic, dynamic>,
                );

                // GIỚI HẠN CHIỀU CAO VÀ CHO PHÉP CUỘN BÊN TRONG LISTVIEW NẾU QUÁ DÀI
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: sharedMap.length,
                    itemBuilder: (context, index) {
                      final sharedPhone = sharedMap.keys.elementAt(index);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person, color: AppColors.primary),
                        title: Text(sharedPhone),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Xác nhận hủy chia sẻ'),
                                content: Text(
                                  'Bạn có chắc chắn muốn ngắt quyền truy cập của $sharedPhone?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      'Xác nhận',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final dbRef = FirebaseDatabase.instance.ref();
                              final Map<String, dynamic> updates = {
                                'devices/${widget.device.deviceId}/shared_users/$sharedPhone': null,
                                'users/$sharedPhone/devices/${widget.device.deviceId}': null,
                              };
                              await dbRef.update(updates);

                              if (widget.parentContext.mounted) {
                                ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã hủy chia sẻ với $sharedPhone'),
                                    backgroundColor: Colors.blueGrey,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
  );
}
}
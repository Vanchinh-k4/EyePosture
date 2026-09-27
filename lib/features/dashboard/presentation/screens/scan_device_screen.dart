import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_colors.dart';

class ScanDeviceScreen extends StatefulWidget {
  final String userPhone;

  const ScanDeviceScreen({super.key, required this.userPhone});

  @override
  State<ScanDeviceScreen> createState() => _ScanDeviceScreenState();
}

class _ScanDeviceScreenState extends State<ScanDeviceScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  bool _isValidDeviceQR(String rawData) {
    final regExp = RegExp(r'^EP_[0-9A-Fa-f]{12}$');
    return regExp.hasMatch(rawData.trim());
  }

  String _extractDeviceId(String validQrData) {
    return validQrData.trim().replaceFirst('EP_', '').toUpperCase();
  }

  String _formatToMacAddress(String deviceId) {
    final buffer = StringBuffer();
    for (int i = 0; i < deviceId.length; i++) {
      if (i > 0 && i % 2 == 0) buffer.write(':');
      buffer.write(deviceId[i]);
    }
    return buffer.toString();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String rawData = barcodes.first.rawValue!.trim();

      if (!_isValidDeviceQR(rawData)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã QR không đúng định dạng thiết bị EyePosture!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      setState(() {
        _isProcessing = true;
      });

      _scannerController.stop();
      _checkAndProcessDevice(rawData);
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_isProcessing) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _isProcessing = true;
      });
      _scannerController.stop();

      final BarcodeCapture? capture = await _scannerController.analyzeImage(image.path);

      if (capture != null && capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
        final String rawData = capture.barcodes.first.rawValue!.trim();

        if (!_isValidDeviceQR(rawData)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ảnh chứa mã QR không đúng định dạng thiết bị!'),
                backgroundColor: Colors.red,
              ),
            );
            _resetScanner();
          }
          return;
        }

        _checkAndProcessDevice(rawData);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy mã QR trong ảnh!'),
              backgroundColor: Colors.orange,
            ),
          );
          _resetScanner();
        }
      }
    }
  }

  // 🚀 KIỂM TRA QUYỀN SỞ HỮU THIẾT BỊ TRÊN CƠ SỞ DỮ LIỆU MỚI
  Future<void> _checkAndProcessDevice(String validQrData) async {
    final String cleanPhone = widget.userPhone.trim();
    final String deviceId = _extractDeviceId(validQrData);
    final String formattedMac = _formatToMacAddress(deviceId);

    try {
      final dbRef = FirebaseDatabase.instance.ref();

      // 1. Kiểm tra xem thiết bị đã có Owner trên hệ thống chưa
      final deviceSnapshot = await dbRef.child('devices/$deviceId/info/owner_phone').get().timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw Exception('Timeout Firebase'),
      );

      if (deviceSnapshot.exists && deviceSnapshot.value != null) {
        final String existingOwner = deviceSnapshot.value.toString().trim();

        if (existingOwner == cleanPhone) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bạn đã là Chủ sở hữu của thiết bị này!'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _resetScanner();
          }
          return;
        } else {
          // Đã thuộc quyền sở hữu của người khác
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Thiết bị này đã thuộc sở hữu của tài khoản ($existingOwner). Vui lòng nhờ chủ thiết bị chia sẻ quyền!'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _resetScanner();
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Bỏ qua lỗi kiểm tra online (hoặc thiết bị mới chưa tạo): $e');
    }

    if (mounted) {
      _showDeviceConfigDialog(macAddress: formattedMac, deviceId: deviceId, rawQr: validQrData);
    }
  }

  void _resetScanner() {
    setState(() {
      _isProcessing = false;
    });
    _scannerController.start();
  }

  Future<bool> _sendWifiCredentialsViaHTTP({
    required String wifiSsid,
    required String wifiPass,
  }) async {
    final url = Uri.parse('http://192.168.4.1/config');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "phone": widget.userPhone.trim(),
              "ssid": wifiSsid,
              "pass": wifiPass,
            }),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Lỗi kết nối HTTP WebServer ESP32: $e');
      return false;
    }
  }

  // 🚀 LƯU THIẾT BỊ VÀO FIREBASE THEO CẤU TRÚC MỚI (/devices VÀ /users)
  // 🚀 LƯU THIẾT BỊ VÀO FIREBASE THEO CẤU TRÚC MỚI (/devices VÀ /users)
  Future<void> _saveDeviceToFirebaseSilently({
    required String deviceId,
    required String macAddress,
    required String deviceName,
    required String wifiSsid,
    required String wifiPass,
  }) async {
    try {
      final String cleanPhone = widget.userPhone.trim();
      final ref = FirebaseDatabase.instance.ref();

      // Sử dụng Multi-Path Update để đảm bảo cả /devices và /users được cập nhật đồng thời
      final Map<String, dynamic> updates = {};

      // 1. Dữ liệu node /devices/{deviceId}
      updates['devices/$deviceId'] = {
        'info': {
          'device_id': deviceId,
          'mac_address': macAddress,
          'device_name': deviceName,
          'owner_phone': cleanPhone,
          'created_at': DateTime.now().toIso8601String(),
          'reset_pending': false,
        },
        'wifi_info': {
          'ssid': wifiSsid,
          'password': wifiPass,
        },
        'settings': {
          'distance_cm': 30,
          'light_lux': 400,
          'warning_buzzer': true,
        },
        'current_data': {
          'distance_cm': 0,
          'light_lux': 0,
          'posture': 'good',
          'alarm': false,
        },
        'last_seen': ServerValue.timestamp,
      };

      // 2. Thêm ID thiết bị vào tài khoản User với vai trò "owner"
      updates['users/$cleanPhone/devices/$deviceId'] = 'owner';

      // Ghi tất cả dữ liệu lên Firebase trong 1 thao tác atomic duy nhất
      await ref.update(updates).timeout(const Duration(seconds: 8));

      debugPrint('Đã cập nhật đồng thời thiết bị vào /devices và /users thành công!');
    } catch (e) {
      debugPrint('Lỗi lưu dữ liệu lên Firebase: $e');
    }
  }

  Widget _buildStepItem({
    required String step,
    required String text,
    Widget? extraWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: Colors.amber.shade700,
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                if (extraWidget != null) extraWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceConfigDialog({
    required String macAddress,
    required String deviceId,
    required String rawQr,
  }) {
    final nameController = TextEditingController(text: 'Thiết bị mới');
    final wifiSsidController = TextEditingController();
    final wifiPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSendingHTTP = false;

    showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Cấu Hình Thiết Bị',
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
                          'ID: $deviceId',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'MAC: $macAddress',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- KHUNG HƯỚNG DẪN + LƯU Ý 2.4GHz ---
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
                          text: 'Kết nối vào mạng Wi-Fi của thiết bị:',
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
                          text: 'Quay lại đây, điền thông tin bên dưới và nhấn "Xác Nhận".',
                        ),
                        const Divider(height: 16, color: Colors.amber),
                        // BỔ SUNG CẢNH BÁO 2.4GHz
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Lưu ý: ESP32 CHỈ hỗ trợ Wi-Fi 2.4GHz. Không chọn Wi-Fi 5GHz!',
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
                    controller: nameController,
                    enabled: !isSendingHTTP,
                    decoration: const InputDecoration(
                      labelText: 'Tên thiết bị',
                      prefixIcon: Icon(Icons.devices),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Vui lòng nhập tên' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: wifiSsidController,
                    enabled: !isSendingHTTP,
                    decoration: const InputDecoration(
                      labelText: 'Tên Wifi nhà bạn (2.4GHz)',
                      prefixIcon: Icon(Icons.wifi),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập Wifi';
                      }
                      // BỔ SUNG VALIDATE CHỐNG NHẬP 5GHZ
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
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu Wifi',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Vui lòng nhập mật khẩu' : null,
                  ),
                  if (isSendingHTTP) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text(
                      'Đang truyền cấu hình sang ESP32...',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                      textAlign: TextAlign.center,
                    ),
                  ]
                ],
              ),
            ),
          ),
          actions: isSendingHTTP
              ? []
              : [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _resetScanner();
                    },
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
                        final String cleanName = nameController.text.trim();

                        bool httpSuccess = await _sendWifiCredentialsViaHTTP(
                          wifiSsid: cleanSsid,
                          wifiPass: cleanPass,
                        );

                        if (!context.mounted) return;

                        if (httpSuccess) {
                          await _saveDeviceToFirebaseSilently(
                            deviceId: deviceId,
                            macAddress: macAddress,
                            deviceName: cleanName,
                            wifiSsid: cleanSsid,
                            wifiPass: cleanPass,
                          );

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cấu hình thành công! Đang quay về màn hình chính...'),
                              backgroundColor: Colors.green,
                            ),
                          );

                          Navigator.of(context).popUntil((route) => route.isFirst);
                        } else {
                          setDialogState(() {
                            isSendingHTTP = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Không kết nối được ESP32! Đảm bảo điện thoại đã bắt Wi-Fi "$rawQr".',
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

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét Mã Thiết Bị'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: state.torchState == TorchState.on ? Colors.amber : Colors.grey,
                );
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 110,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Đặt mã QR của thiết bị vào giữa khung hình',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _pickImageFromGallery,
                icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                label: const Text(
                  'Tải QR từ thư viện ảnh',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
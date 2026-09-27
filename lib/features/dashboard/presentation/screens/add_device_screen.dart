import 'package:flutter/material.dart';
import 'package:eye_posture/core/constants/app_colors.dart';
import 'scan_device_screen.dart';

class AddDeviceScreen extends StatefulWidget {
  final String userPhone;

  const AddDeviceScreen({super.key, required this.userPhone});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thêm thiết bị giám sát',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Hình minh họa điện thoại quét mã QR
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE4E6), // Màu nền hồng nhạt
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D), // Khung điện thoại
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Loa điện thoại nhỏ phía trên
                          Container(
                            width: 24,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Màn hình quét QR
                          Container(
                            width: 76,
                            height: 96,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F4F8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 48,
                                color: Color(0xFF4A5568),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Nút Home điện thoại
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.white38,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Tiêu đề hướng dẫn
              const Text(
                'Hãy đảm bảo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // Các bước hướng dẫn
              _buildInstructionStep(
                number: '1.',
                text:
                    'Thiết bị giám sát đã được bật nguồn và đèn tín hiệu/màn hình đang hoạt động bình thường.',
              ),
              const SizedBox(height: 14),
              _buildInstructionStep(
                number: '2.',
                text:
                    'Thiết bị đã sẵn sàng phát tín hiệu Wi-Fi để kết nối.',
              ),
              // Nút "Mở Camera Quét QR"
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    // Chuyển sang màn hình quét QR camera
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ScanDeviceScreen(userPhone: widget.userPhone),
                      ),
                    );

                    // Nếu quét thiết bị thành công (trả về true), đóng màn hình hiện tại
                    if (result == true && mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Mở Camera Quét QR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget hiển thị từng dòng hướng dẫn
  Widget _buildInstructionStep(
      {required String number, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
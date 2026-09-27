import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ForgotPasswordPhoneScreen extends StatefulWidget {
  const ForgotPasswordPhoneScreen({super.key});

  @override
  State<ForgotPasswordPhoneScreen> createState() => _ForgotPasswordPhoneScreenState();
}

class _ForgotPasswordPhoneScreenState extends State<ForgotPasswordPhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  String? _verificationId;
  bool _isOtpSent = false;
  bool _isLoading = false;

  // Các cờ kiểm tra điều kiện mật khẩu
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigits = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // Hàm kiểm tra độ mạnh mật khẩu theo thời gian thực
  void _checkPasswordStrength() {
    final password = _newPasswordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasDigits = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordStrong =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasDigits && _hasSpecialChar;

  // Chuyển định dạng SĐT Việt Nam (+84)
  String _formatPhoneNumber(String phone) {
    String trimmed = phone.trim().replaceAll(' ', '');
    if (trimmed.startsWith('0')) {
      return '+84${trimmed.substring(1)}';
    } else if (!trimmed.startsWith('+')) {
      return '+84$trimmed';
    }
    return trimmed;
  }

  // Lấy dạng SĐT 0xxx để làm key Realtime DB
  String _getRawPhone(String phone) {
    String trimmed = phone.trim().replaceAll(' ', '');
    if (trimmed.startsWith('+84')) {
      return '0${trimmed.substring(3)}';
    }
    return trimmed;
  }

  // 1. GỬI MÃ OTP
  Future<void> _sendOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      _showSnackBar('Vui lòng nhập số điện thoại!', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    final formattedPhone = _formatPhoneNumber(rawPhone);

    try {
      // 🟢 BẮT BUỘC BẬT DÒNG NÀY ĐỂ TRÁNH CRASH TRÊN IOS IPA TEST
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {},
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showSnackBar('Gửi OTP thất bại: ${e.message}', Colors.red);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isOtpSent = true;
            _isLoading = false;
          });
          _showSnackBar('Mã OTP đã gửi tới $formattedPhone', Colors.green);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Đã xảy ra lỗi: $e', Colors.red);
    }
  }

  // 2. XÁC THỰC OTP VÀ ĐỔI MẬT KHẨU
  Future<void> _resetPasswordWithOtp() async {
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final rawPhone = _getRawPhone(_phoneController.text.trim());

    if (otp.isEmpty || otp.length < 6) {
      _showSnackBar('Vui lòng nhập đủ 6 chữ số OTP!', Colors.orange);
      return;
    }

    if (!_isPasswordStrong) {
      _showSnackBar('Mật khẩu chưa đạt tiêu chuẩn độ mạnh yêu cầu!', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Cập nhật trên Realtime Database
        final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
        await dbRef.child('users').child(rawPhone).update({
          'password': newPassword,
        });

        // Cập nhật trên Firebase Auth (nếu có)
        try {
          await userCredential.user!.updatePassword(newPassword);
        } catch (_) {}

        if (!mounted) return;
        _showSnackBar('Đổi mật khẩu mới thành công!', Colors.green);

        await FirebaseAuth.instance.signOut();
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Thao tác thất bại!';
      if (e.code == 'invalid-verification-code') {
        message = 'Mã OTP không chính xác!';
      }
      _showSnackBar(message, Colors.red);
    } catch (e) {
      _showSnackBar('Lỗi cập nhật Database: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  Widget _buildPasswordRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Yêu cầu mật khẩu mạnh:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        _buildRequirementItem('Ít nhất 8 ký tự', _hasMinLength),
        _buildRequirementItem('Có ít nhất 1 chữ cái viết hoa (A-Z)', _hasUppercase),
        _buildRequirementItem('Có ít nhất 1 chữ cái viết thường (a-z)', _hasLowercase),
        _buildRequirementItem('Có ít nhất 1 chữ số (0-9)', _hasDigits),
        _buildRequirementItem('Có ít nhất 1 ký tự đặc biệt (@, #, \$, %...)', _hasSpecialChar),
      ],
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.green : Colors.grey[700],
              fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              !_isOtpSent
                  ? 'Nhập số điện thoại đã đăng ký để nhận mã OTP.'
                  : 'Nhập mã OTP và thiết lập mật khẩu mới đạt độ mạnh.',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _phoneController,
              enabled: !_isOtpSent,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),

            if (_isOtpSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Mã OTP (6 chữ số)',
                  prefixIcon: Icon(Icons.pin),
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: Icon(
                    _isPasswordStrong ? Icons.verified : Icons.error_outline,
                    color: _isPasswordStrong ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _buildPasswordRequirements(),
              ),
            ],

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (!_isOtpSent
                      ? _sendOtp
                      : (_isPasswordStrong ? _resetPasswordWithOtp : null)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      !_isOtpSent ? 'GỬI MÃ OTP' : 'XÁC NHẬN ĐỔI MẬT KHẨU',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
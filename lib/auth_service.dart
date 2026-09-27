import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Hàm kiểm tra Đăng nhập bằng Số điện thoại & Mật khẩu
  Future<Map<String, dynamic>?> loginWithPhoneAndPassword({
    required String phone,
    required String password,
  }) async {
    // Tìm tài khoản trong nhánh users dựa trên số điện thoại
    final snapshot = await _db.child('users/$phone').get();

    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Số điện thoại chưa được đăng ký!');
    }

    final userData = Map<String, dynamic>.from(snapshot.value as Map);

    // Kiểm tra mật khẩu
    if (userData['password'] != password) {
      throw Exception('Mật khẩu không chính xác!');
    }

    return userData; // Đăng nhập thành công, trả về thông tin user
  }
}
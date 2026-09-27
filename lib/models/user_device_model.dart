class UserModel {
  final String phone;
  final String name;
  final Map<String, String> deviceRoles; // Lưu Map: {deviceId: "owner" | "shared"}

  UserModel({
    required this.phone,
    required this.name,
    required this.deviceRoles,
  });

  factory UserModel.fromMap(String phone, Map<String, dynamic> map) {
    Map<String, String> roles = {};

    if (map['devices'] != null && map['devices'] is Map) {
      final devicesMap = Map<String, dynamic>.from(map['devices']);
      devicesMap.forEach((key, value) {
        roles[key] = value.toString(); // e.g., "owner" hoặc "shared"
      });
    }

    return UserModel(
      phone: phone,
      name: map['name'] ?? 'Người dùng',
      deviceRoles: roles,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'name': name,
      'devices': deviceRoles,
    };
  }
}

class DeviceModel {
  final String deviceId;
  final String deviceName;
  final String macAddress;
  final String ownerPhone;
  final dynamic lastSeen;
  final String createdAt;
  final CurrentData? currentData;
  final DeviceSettings? settings;
  final WifiInfo? wifiInfo;

  DeviceModel({
    required this.deviceId,
    required this.deviceName,
    this.macAddress = '',
    this.ownerPhone = '',
    this.lastSeen,
    this.createdAt = '',
    this.currentData,
    this.settings,
    this.wifiInfo,
  });

  factory DeviceModel.fromMap(String key, Map<String, dynamic> map) {
    // Xử lý đọc sub-node "info" nếu có (Cấu trúc DB mới)
    final infoMap = (map['info'] != null && map['info'] is Map)
        ? Map<String, dynamic>.from(map['info'])
        : <String, dynamic>{};

    return DeviceModel(
      deviceId: infoMap['device_id'] ?? map['device_id'] ?? key,
      deviceName: infoMap['device_name'] ?? map['device_name'] ?? 'Thiết bị không tên',
      macAddress: infoMap['mac_address'] ?? map['mac_address'] ?? '',
      ownerPhone: infoMap['owner_phone'] ?? map['owner_phone'] ?? '',
      lastSeen: map['last_seen'] ?? map['lastSeen'],
      createdAt: infoMap['created_at'] ?? map['created_at'] ?? '',
      currentData: map['current_data'] != null
          ? CurrentData.fromMap(Map<String, dynamic>.from(map['current_data']))
          : null,
      settings: map['settings'] != null
          ? DeviceSettings.fromMap(Map<String, dynamic>.from(map['settings']))
          : null,
      wifiInfo: map['wifi_info'] != null
          ? WifiInfo.fromMap(Map<String, dynamic>.from(map['wifi_info']))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'info': {
        'device_id': deviceId,
        'device_name': deviceName,
        'mac_address': macAddress,
        'owner_phone': ownerPhone,
        'created_at': createdAt,
      },
      'last_seen': lastSeen,
      if (currentData != null) 'current_data': currentData!.toMap(),
      if (settings != null) 'settings': settings!.toMap(),
      if (wifiInfo != null) 'wifi_info': wifiInfo!.toMap(),
    };
  }
}

class CurrentData {
  final double distanceCm;
  final int lightLux;
  final String lastActive;
  final String posture;
  final String postureDetail;
  final bool alarm;

  CurrentData({
    this.distanceCm = 0.0,
    this.lightLux = 0,
    this.lastActive = '',
    this.posture = 'unknown',
    this.postureDetail = '',
    this.alarm = false,
  });

  factory CurrentData.fromMap(Map<String, dynamic> map) {
    return CurrentData(
      distanceCm: (map['distance_cm'] ?? 0).toDouble(),
      lightLux: (map['light_lux'] ?? 0).toInt(),
      lastActive: map['last_active'] ?? '',
      posture: map['posture'] ?? 'unknown',
      postureDetail: map['posture_detail'] ?? '',
      alarm: map['alarm'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'distance_cm': distanceCm,
      'light_lux': lightLux,
      'last_active': lastActive,
      'posture': posture,
      'posture_detail': postureDetail,
      'alarm': alarm,
    };
  }
}

class DeviceSettings {
  final double distanceCm;
  final int lightLux;
  final bool warningBuzzer;

  DeviceSettings({
    this.distanceCm = 30.0,
    this.lightLux = 400,
    this.warningBuzzer = true,
  });

  factory DeviceSettings.fromMap(Map<String, dynamic> map) {
    return DeviceSettings(
      distanceCm: (map['distance_cm'] ?? 30).toDouble(),
      lightLux: (map['light_lux'] ?? 400).toInt(),
      warningBuzzer: map['warning_buzzer'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'distance_cm': distanceCm,
      'light_lux': lightLux,
      'warning_buzzer': warningBuzzer,
    };
  }
}

class WifiInfo {
  final String? ssid;
  final String? password; // 1. Thêm trường password ở đây

  WifiInfo({
    this.ssid,
    this.password, // 2. Thêm vào constructor
  });

  factory WifiInfo.fromMap(Map<dynamic, dynamic> map) {
    return WifiInfo(
      ssid: map['ssid']?.toString(),
      password: map['password']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ssid': ssid,
      'password': password, // 4. Đưa password vào Map khi gửi lên Firebase
    };
  }
}
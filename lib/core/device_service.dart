import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DeviceService {
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  Future<Map<String, dynamic>> getDeviceStatus() async {
    final status = <String, dynamic>{};

    // Battery
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      status['battery_level'] = level;
      status['is_charging'] = state == BatteryState.charging || state == BatteryState.full;
    } catch (e) {
      status['battery_error'] = e.toString();
    }

    // Network
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      String networkType = "Unknown";
      if (connectivityResult.contains(ConnectivityResult.mobile)) {
        networkType = "Mobile Data";
      } else if (connectivityResult.contains(ConnectivityResult.wifi)) {
        networkType = "WiFi";
      } else if (connectivityResult.contains(ConnectivityResult.none)) {
        networkType = "Offline";
      }
      status['network_type'] = networkType;
    } catch (e) {
      status['network_error'] = e.toString();
    }

    return status;
  }
}

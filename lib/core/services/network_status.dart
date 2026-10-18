import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents the type of network the device is connected to.
enum NetworkType {
  none,
  wifi,
  mobile,
  ethernet,
  other;

  String get label {
    switch (this) {
      case NetworkType.none:
        return 'Offline';
      case NetworkType.wifi:
        return 'Wi-Fi';
      case NetworkType.mobile:
        return 'Mobile data';
      case NetworkType.ethernet:
        return 'Ethernet';
      case NetworkType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case NetworkType.none:
        return Icons.wifi_off;
      case NetworkType.wifi:
        return Icons.wifi;
      case NetworkType.mobile:
        return Icons.signal_cellular_alt;
      case NetworkType.ethernet:
        return Icons.router;
      case NetworkType.other:
        return Icons.lan;
    }
  }
}

NetworkType _mapResult(ConnectivityResult r) {
  switch (r) {
    case ConnectivityResult.wifi:
      return NetworkType.wifi;
    case ConnectivityResult.mobile:
      return NetworkType.mobile;
    case ConnectivityResult.ethernet:
      return NetworkType.ethernet;
    case ConnectivityResult.none:
      return NetworkType.none;
    default:
      return NetworkType.other;
  }
}

/// The current network type, updated live via [Connectivity].
final networkTypeProvider = StreamProvider<NetworkType>((ref) {
  final connectivity = Connectivity();
  final controller = StreamController<NetworkType>.broadcast();

  NetworkType pick(List<ConnectivityResult> results) =>
      results.isEmpty ? NetworkType.none : _mapResult(results.first);

  Future<void> emit() async {
    final results = await connectivity.checkConnectivity();
    if (!controller.isClosed) controller.add(pick(results));
  }

  emit();
  final sub = connectivity.onConnectivityChanged.listen((results) {
    if (!controller.isClosed) controller.add(pick(results));
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

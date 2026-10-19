import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../platform/dashboard_platform.dart';

class PickedLocation {
  final String? addressText;
  final double? latitude;
  final double? longitude;

  PickedLocation({this.addressText, this.latitude, this.longitude});

  bool get hasCoordinates => latitude != null && longitude != null;

  String get display {
    if (addressText != null && addressText!.isNotEmpty) return addressText!;
    if (hasCoordinates) {
      return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
    }
    return 'Chưa có vị trí';
  }
}

class LocationPickerDialog extends StatefulWidget {
  final PickedLocation? initial;
  const LocationPickerDialog({super.key, this.initial});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final DashboardPlatform _platform = createDashboardPlatform();
  final TextEditingController _addressCtrl = TextEditingController();
  final MapController _mapCtrl = MapController();
  Timer? _debounceTimer;

  LatLng _center = const LatLng(10.7769, 106.7009); // TP.HCM mặc định
  bool _isLocating = false;
  bool _isGeocoding = false;
  bool _isMapMoving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _addressCtrl.text = widget.initial!.addressText ?? '';
      if (widget.initial!.hasCoordinates) {
        _center = LatLng(widget.initial!.latitude!, widget.initial!.longitude!);
      }
    } else {
      _addressCtrl.text = 'TP. Hồ Chí Minh (${_center.latitude.toStringAsFixed(4)}, ${_center.longitude.toStringAsFixed(4)})';
      WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrentLocation());
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    _platform.getCurrentLocation(
      (lat, lng) {
        if (!mounted) return;
        final ll = LatLng(lat, lng);
        setState(() {
          _center = ll;
          _isLocating = false;
        });
        _mapCtrl.move(ll, 17);
        _reverseGeocode(ll);
      },
      (err) {
        if (!mounted) return;
        setState(() => _isLocating = false);
      },
    );
  }

  void _onMapMoved(LatLng center) {
    _debounceTimer?.cancel();
    _addressCtrl.text =
        'Tọa độ: ${center.latitude.toStringAsFixed(6)}, ${center.longitude.toStringAsFixed(6)}';

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _reverseGeocode(center);
    });
  }

  Future<void> _reverseGeocode(LatLng ll) async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);
    String? addr;

    try {
      final placemarks =
          await placemarkFromCoordinates(ll.latitude, ll.longitude)
              .timeout(const Duration(seconds: 2));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.street ?? '').isNotEmpty) p.street!,
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
          if ((p.locality ?? '').isNotEmpty) p.locality!,
          if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
        ];
        if (parts.isNotEmpty) addr = parts.join(', ');
      }
    } catch (_) {}

    if (addr == null || addr.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=${ll.latitude}&lon=${ll.longitude}&accept-language=vi',
        );
        final res = await http.get(uri, headers: {
          'User-Agent': 'com.example.flutter_application_web/1.0',
        }).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final display = data['display_name']?.toString();
          if (display != null && display.isNotEmpty) addr = display;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _isGeocoding = false;
      if (addr != null && addr.isNotEmpty) {
        _addressCtrl.text = addr;
      }
    });
  }

  void _confirm() {
    final text = _addressCtrl.text.trim();
    final finalAddress = text.isEmpty
        ? 'Tọa độ GPS: ${_center.latitude.toStringAsFixed(6)}, ${_center.longitude.toStringAsFixed(6)}'
        : text;

    final result = PickedLocation(
      addressText: finalAddress,
      latitude: _center.latitude,
      longitude: _center.longitude,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Container(
        width: 650,
        height: 560,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              color: const Color(0xFF0D4D8A),
              child: Row(
                children: [
                  const Icon(Icons.map_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Bản đồ chọn vị trí (Map Picker)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Map Area
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapCtrl,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 16,
                      onMapEvent: (event) {
                        if (event is MapEventMoveStart) {
                          setState(() => _isMapMoving = true);
                        } else if (event is MapEventMoveEnd ||
                            event is MapEventFlingAnimationEnd) {
                          final c = _mapCtrl.camera.center;
                          setState(() {
                            _isMapMoving = false;
                            _center = c;
                          });
                          _onMapMoved(c);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.example.flutter_application_web',
                        tileProvider: CancellableNetworkTileProvider(),
                      ),
                    ],
                  ),
                  // Fixed Center Pin
                  const IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(
                          Icons.location_pin,
                          color: Color(0xFFCF3C3C),
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                  // Address Top Card
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isMapMoving ? Icons.sync : Icons.location_on,
                                  size: 18,
                                  color: const Color(0xFF0B6EDB),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isMapMoving
                                      ? 'Đang di chuyển bản đồ...'
                                      : 'Vị trí đã chọn',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF58708F),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _addressCtrl,
                              minLines: 1,
                              maxLines: 2,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF0A2F5D),
                                  fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Nhập hoặc chọn địa chỉ trên bản đồ...',
                                border: InputBorder.none,
                              ),
                            ),
                            if (_isGeocoding)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom Action Buttons
                  Positioned(
                    bottom: 14,
                    left: 14,
                    right: 14,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLocating ? null : _useCurrentLocation,
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0B6EDB),
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded),
                            label: const Text('Vị trí GPS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0B6EDB),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _confirm,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Xác nhận'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B6EDB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _addressCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }
}

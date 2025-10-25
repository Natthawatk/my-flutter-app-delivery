import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api_service.dart';
import '../widgets/rider_bottom_nav.dart';
import '../widgets/longdo_map.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({Key? key}) : super(key: key);

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  Map<String, dynamic>? currentUser;
  List<Map<String, dynamic>> availableJobs = [];
  Map<String, dynamic>? currentJob;
  bool isLoading = true;
  Timer? _locationTimer;
  File? _capturedPhoto; // Store captured photo for current state
  double? _currentLatitude;
  double? _currentLongitude;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _locationTimer = null;
    super.dispose();
  }

  // ---------- Helpers ----------
  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String && v.trim().isNotEmpty) return double.tryParse(v.trim());
    return null;
  }

  bool _isPhotoRequired(String status) {
    // ปรับตามนโยบายธุรกิจของคุณได้
    return status == 'ON_ROUTE' || status == 'DELIVERED';
  }

  String _nextStatusFrom(String current) {
    switch (current) {
      case 'ASSIGNED':
        return 'ON_ROUTE';
      case 'ON_ROUTE':
        return 'DELIVERED';
      default:
        return current;
    }
  }

  // ---------- Location ----------
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled. Using default Bangkok location.');
        if (!mounted) return;
        setState(() {
          _currentLatitude = 13.7563;
          _currentLongitude = 100.5018;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied. Using default Bangkok location.');
          if (!mounted) return;
          setState(() {
            _currentLatitude = 13.7563;
            _currentLongitude = 100.5018;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied. Using default Bangkok location.');
        if (!mounted) return;
        setState(() {
          _currentLatitude = 13.7563;
          _currentLongitude = 100.5018;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (position.latitude >= 5.6 &&
          position.latitude <= 20.5 &&
          position.longitude >= 97.3 &&
          position.longitude <= 105.6) {
        if (!mounted) return;
        setState(() {
          _currentLatitude = position.latitude;
          _currentLongitude = position.longitude;
        });
        debugPrint('📍 Current GPS location: ${position.latitude}, ${position.longitude}');
      } else {
        debugPrint('📍 Location outside Thailand, using Bangkok: ${position.latitude}, ${position.longitude}');
        if (!mounted) return;
        setState(() {
          _currentLatitude = 13.7563;
          _currentLongitude = 100.5018;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e. Using default Bangkok location.');
      if (!mounted) return;
      setState(() {
        _currentLatitude = 13.7563;
        _currentLongitude = 100.5018;
      });
    }
  }

  Future<void> _updateLocationSilently() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (position.latitude >= 5.6 &&
          position.latitude <= 20.5 &&
          position.longitude >= 97.3 &&
          position.longitude <= 105.6) {
        if (!mounted) return;
        setState(() {
          _currentLatitude = position.latitude;
          _currentLongitude = position.longitude;
        });

        if (currentJob != null && currentUser != null) {
          final riderId = currentUser!['user_id'] ?? currentUser!['id'];
          final deliveryId = currentJob!['delivery_id'];
          await ApiService.saveRiderLocation(
            riderId,
            position.latitude,
            position.longitude,
            deliveryId: deliveryId,
          );
        }
      }
    } catch (_) {
      // Silently fail
    }
  }

  // ---------- Data load ----------
  Future<void> _loadUserData() async {
    final user = await ApiService.getCurrentUser();
    if (user != null) {
      if (!mounted) return;
      setState(() {
        currentUser = user;
      });

      final riderId = user['user_id'] ?? user['id'];
      await ApiService.cleanupRiderAssignments(riderId);

      await _loadAvailableJobs();
      await _loadCurrentJob(preserveIfNull: false);
      _startRealTimeUpdates();
    }
  }

  Future<void> _loadAvailableJobs() async {
    if (currentUser == null) return;

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final jobsRaw = await ApiService.getAvailableJobs();
      final jobs = (jobsRaw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        availableJobs = jobs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading available jobs: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentJob({bool preserveIfNull = false}) async {
    if (currentUser == null) {
      debugPrint('⚠️ Cannot load current job - no user');
      return;
    }

    try {
      final riderId = currentUser!['user_id'] ?? currentUser!['id'];
      debugPrint('📥 Loading current job for rider: $riderId');

      final prevJob = currentJob; // keep old job for status-change detection
      final job = await ApiService.getRiderCurrentJob(riderId);

      debugPrint('📦 Current job loaded: ${job != null ? "Job ID ${job['delivery_id']}" : "No job"}');

      if (!mounted) return;
      setState(() {
        if (job == null && preserveIfNull) {
          // Preserve optimistic state
          return;
        }

        currentJob = job;

        final prevStatus = prevJob?['status'];
        final newStatus = job?['status'];
        if (job == null || (prevStatus != null && prevStatus != newStatus)) {
          _capturedPhoto = null; // clear photo on status change or no job
        }
      });
    } catch (e) {
      debugPrint('❌ Error loading current job: $e');
    }
  }

  Future<void> _loadCurrentJobWithRetry({
    int attempts = 5,
    Duration initialDelay = const Duration(milliseconds: 300),
    bool preserveIfNull = true,
  }) async {
    if (currentUser == null) return;
    final riderId = currentUser!['user_id'] ?? currentUser!['id'];

    Duration delay = initialDelay;

    for (int i = 0; i < attempts; i++) {
      try {
        final job = await ApiService.getRiderCurrentJob(riderId);

        if (job != null) {
          if (!mounted) return;
          setState(() {
            final prevStatus = currentJob?['status'];
            final newStatus = job['status'];
            currentJob = Map<String, dynamic>.from(job);
            if (prevStatus != null && prevStatus != newStatus) {
              _capturedPhoto = null;
            }
          });
          return; // done
        } else {
          if (!preserveIfNull && mounted) {
            setState(() {
              currentJob = null;
            });
          }
        }
      } catch (e) {
        debugPrint('❌ Retry load current job error: $e');
      }

      await Future.delayed(delay);
      delay *= 2; // exponential backoff
    }
  }

  void _startRealTimeUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;

    // ปิด auto-refresh list/map เพื่อเลี่ยง map reload
    // อัปเดตเฉพาะตำแหน่งทุก 10 วินาทีเมื่อมีงาน
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (currentJob != null && mounted) {
        _updateLocationSilently();
      }
    });
  }

  // ---------- Actions ----------
  Future<void> _acceptJob(Map<String, dynamic> job) async {
    if (currentUser == null) return;

    if (currentJob != null) {
      _showMessage('คุณมีงานที่ยังไม่เสร็จอยู่แล้ว');
      return;
    }

    try {
      final riderId = currentUser!['user_id'] ?? currentUser!['id'];
      final deliveryId = job['delivery_id'];

      debugPrint('🔄 Accepting job $deliveryId for rider $riderId');

      final success = await ApiService.acceptDeliveryJob(deliveryId, riderId);

      if (success) {
        debugPrint('✅ Job accepted successfully');
        _showMessage('รับงานสำเร็จ!');

        // Optimistic update — show current job immediately
        if (!mounted) return;
        setState(() {
          currentJob = {
            'delivery_id': job['delivery_id'],
            'status': 'ASSIGNED',
            'sender_name': job['sender_name'],
            'receiver_name': job['receiver_name'],
            'pickup_address': job['pickup_address'],
            'delivery_address': job['delivery_address'],
            'pickup_lat': job['pickup_lat'],
            'pickup_lng': job['pickup_lng'],
            'delivery_lat': job['delivery_lat'],
            'delivery_lng': job['delivery_lng'],
            'note': job['note'],
          };
          availableJobs = [];
          isLoading = false;
        });

        // Then sync from server with retry, but preserve optimistic state if null
        await _loadCurrentJobWithRetry(
          attempts: 5,
          initialDelay: const Duration(milliseconds: 300),
          preserveIfNull: true,
        );
      } else {
        debugPrint('❌ Failed to accept job');
        _showMessage('ไม่สามารถรับงานได้ อาจมีคนอื่นรับไปแล้ว');
        await _loadAvailableJobs();
      }
    } catch (e) {
      _showMessage('เกิดข้อผิดพลาด: $e');
      debugPrint('❌ Error accepting job: $e');
    }
  }

  Future<void> _updateJobStatus(String newStatus) async {
    if (currentJob == null) return;

    if (_isPhotoRequired(newStatus) && _capturedPhoto == null) {
      _showMessage('กรุณาถ่ายรูปก่อนอัพเดทสถานะ');
      return;
    }

    try {
      final deliveryId = currentJob!['delivery_id'];
      final success = await ApiService.updateDeliveryStatus(
        deliveryId,
        newStatus,
        photoFile: _capturedPhoto,
      );

      if (success) {
        if (!mounted) return;
        setState(() {
          currentJob!['status'] = newStatus;
          _capturedPhoto = null; // Clear photo after successful update
        });
        _showMessage('อัพเดทสถานะสำเร็จ!');

        if (newStatus == 'DELIVERED') {
          // Job completed, clear current job and reload list
          if (!mounted) return;
          setState(() {
            currentJob = null;
          });
          await _loadAvailableJobs();
        } else {
          // sync เผื่อมีข้อมูลอื่นอัปเดตจากเซิร์ฟเวอร์
          await _loadCurrentJobWithRetry(
            attempts: 3,
            initialDelay: const Duration(milliseconds: 300),
            preserveIfNull: true,
          );
        }
      } else {
        _showMessage('ไม่สามารถอัพเดทสถานะได้');
      }
    } catch (e) {
      _showMessage('เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        if (!mounted) return;
        setState(() {
          _capturedPhoto = File(photo.path);
        });
        _showMessage('ถ่ายรูปสำเร็จ! ตอนนี้สามารถอัพเดทสถานะได้');
      }
    } catch (e) {
      _showMessage('ไม่สามารถถ่ายรูปได้: $e');
    }
  }

  // ---------- UI ----------
  List<MapMarker> _getMapMarkers() {
    final List<MapMarker> markers = [];

    // Rider location
    if (_currentLatitude != null && _currentLongitude != null) {
      String markerTitle = 'Your Location';

      if (currentJob != null) {
        final status = currentJob!['status'] ?? 'ASSIGNED';
        if (status == 'ASSIGNED') {
          markerTitle = 'Rider - Going to Pickup';
        } else if (status == 'ON_ROUTE') {
          markerTitle = 'Rider - Delivering Package';
        }
      }

      markers.add(MapMarker(
        latitude: _currentLatitude!,
        longitude: _currentLongitude!,
        title: markerTitle,
        type: MarkerType.rider,
      ));
    }

    // Job locations
    if (currentJob != null) {
      final status = currentJob!['status'] ?? 'ASSIGNED';

      if (status == 'ASSIGNED') {
        final pickupLat = _asDouble(currentJob!['pickup_lat']);
        final pickupLng = _asDouble(currentJob!['pickup_lng']);

        if (pickupLat != null && pickupLng != null) {
          markers.add(MapMarker(
            latitude: pickupLat,
            longitude: pickupLng,
            title: 'Pickup Location',
            type: MarkerType.pickup,
          ));
        }
      } else if (status == 'ON_ROUTE') {
        final deliveryLat = _asDouble(currentJob!['delivery_lat']);
        final deliveryLng = _asDouble(currentJob!['delivery_lng']);

        if (deliveryLat != null && deliveryLng != null) {
          markers.add(MapMarker(
            latitude: deliveryLat,
            longitude: deliveryLng,
            title: 'Delivery Location',
            type: MarkerType.destination,
          ));
        }
      }
    }

    return markers;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'WAITING':
        return Colors.orange;
      case 'ASSIGNED':
        return Colors.blue;
      case 'ON_ROUTE':
        return Colors.purple;
      case 'DELIVERED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplay(String status) {
    switch (status) {
      case 'WAITING':
        return 'รอไรเดอร์';
      case 'ASSIGNED':
        return 'รับงานแล้ว';
      case 'ON_ROUTE':
        return 'กำลังส่ง';
      case 'DELIVERED':
        return 'ส่งเสร็จแล้ว';
      default:
        return status;
    }
  }

  Widget _buildAvailableJobItem(Map<String, dynamic> job) {
    final deliveryId = job['delivery_id']?.toString() ?? '0';
    final senderName = job['sender_name'] ?? 'Unknown';
    final receiverName = job['receiver_name'] ?? 'Unknown';
    final pickupAddress = job['pickup_address'] ?? 'Address not available';
    final deliveryAddress = job['delivery_address'] ?? 'Address not available';
    final note = job['note'] ?? 'No details';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'งานใหม่',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'ID: $deliveryId',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Pickup Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รับสินค้า',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      pickupAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'จาก: $senderName',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Delivery Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ส่งสินค้า',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      deliveryAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'ถึง: $receiverName',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (note.toString().trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'หมายเหตุ: $note',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Accept Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _acceptJob(job),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'รับงาน',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentJobCard() {
    if (currentJob == null) return const SizedBox.shrink();

    final deliveryId = currentJob!['delivery_id']?.toString() ?? '0';
    final status = (currentJob!['status'] ?? 'ASSIGNED').toString();
    final senderName = currentJob!['sender_name'] ?? 'Unknown';
    final receiverName = currentJob!['receiver_name'] ?? 'Unknown';
    final pickupAddress = currentJob!['pickup_address'] ?? 'Address not available';
    final deliveryAddress = currentJob!['delivery_address'] ?? 'Address not available';

    final nextStatus = _nextStatusFrom(status);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _getStatusColor(status), width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(status).withOpacity(0.1),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                backgroundColor: _getStatusColor(status),
                label: Text(
                  _getStatusDisplay(status),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Text(
                'ID: $deliveryId',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Addresses
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.store_mall_directory, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'รับ: $pickupAddress\nจาก: $senderName',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ส่ง: $deliveryAddress\nถึง: $receiverName',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Photo preview
          if (_capturedPhoto != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _capturedPhoto!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('ถ่ายรูป'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: status == 'DELIVERED'
                      ? null
                      : () => _updateJobStatus(nextStatus),
                  icon: const Icon(Icons.sync),
                  label: Text(
                    status == 'DELIVERED'
                        ? 'เสร็จสิ้นแล้ว'
                        : 'อัปเดตเป็น ${_getStatusDisplay(nextStatus)}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    final centerLat = _currentLatitude ?? 13.7563;
    final centerLng = _currentLongitude ?? 100.5018;

    return Container(
      height: 260,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LongdoMap(
        markers: _getMapMarkers(),
        centerLat: centerLat,
        centerLng: centerLng,
        zoom: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
      ),
      bottomNavigationBar: const RiderBottomNav(currentIndex: 0),
      body: RefreshIndicator(
        onRefresh: () async {
          await _getCurrentLocation();
          await _loadAvailableJobs();
          await _loadCurrentJob(preserveIfNull: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMapCard(),
              if (currentJob != null) _buildCurrentJobCard(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'งานที่ว่าง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (availableJobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('ยังไม่มีงานว่าง')),
                )
              else
                ...availableJobs.map(_buildAvailableJobItem).toList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

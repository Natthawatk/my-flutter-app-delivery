import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
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
  Timer? _realTimeTimer;
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
    _realTimeTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled. Using default Bangkok location.');
        setState(() {
          _currentLatitude = 13.7563;
          _currentLongitude = 100.5018;
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied. Using default Bangkok location.');
          setState(() {
            _currentLatitude = 13.7563;
            _currentLongitude = 100.5018;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied. Using default Bangkok location.');
        setState(() {
          _currentLatitude = 13.7563;
          _currentLongitude = 100.5018;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Check if location is in Thailand (approximate bounds)
      // Thailand: lat 5.6-20.5, lon 97.3-105.6
      if (position.latitude >= 5.6 && position.latitude <= 20.5 &&
          position.longitude >= 97.3 && position.longitude <= 105.6) {
        setState(() {
          _currentLatitude = position.latitude;
          _currentLongitude = position.longitude;
        });
        print('📍 Current GPS location: ${position.latitude}, ${position.longitude}');
      } else {
        // Location outside Thailand, use Bangkok as default
        print('📍 Location outside Thailand, using Bangkok: ${position.latitude}, ${position.longitude}');
        setState(() {
          _currentLatitude = 13.7563;
          _currentLongitude = 100.5018;
        });
      }
    } catch (e) {
      print('Error getting location: $e. Using default Bangkok location.');
      if (mounted) {
        setState(() {
          _currentLatitude = 13.7563;
          _currentLongitude = 100.5018;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    final user = await ApiService.getCurrentUser();
    if (user != null) {
      setState(() {
        currentUser = user;
      });
      // Clean up stale assignments first
      final riderId = user['user_id'] ?? user['id'];
      await ApiService.cleanupRiderAssignments(riderId);
      
      await _loadAvailableJobs();
      await _loadCurrentJob();
      _startRealTimeUpdates();
    }
  }

  Future<void> _loadAvailableJobs() async {
    if (currentUser == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Get available jobs (WAITING status only)
      final jobs = await ApiService.getAvailableJobs();
      setState(() {
        availableJobs = jobs;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading available jobs: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentJob() async {
    if (currentUser == null) {
      print('⚠️ Cannot load current job - no user');
      return;
    }

    try {
      final riderId = currentUser!['user_id'] ?? currentUser!['id'];
      print('📥 Loading current job for rider: $riderId');
      
      final job = await ApiService.getRiderCurrentJob(riderId);
      
      print('📦 Current job loaded: ${job != null ? "Job ID ${job['delivery_id']}" : "No job"}');
      
      setState(() {
        currentJob = job;
        // Clear captured photo when loading new job or status changed
        if (job == null || (currentJob != null && currentJob!['status'] != job['status'])) {
          _capturedPhoto = null;
        }
      });
    } catch (e) {
      print('❌ Error loading current job: $e');
    }
  }

  void _startRealTimeUpdates() {
    _realTimeTimer?.cancel();
    _locationTimer?.cancel();
    
    // Disabled auto-refresh to prevent map reloading
    // Users can use pull-to-refresh to manually update
    
    // Optional: Update GPS location every 10 seconds when rider has active job
    // This only updates location without rebuilding the entire map
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (currentJob != null && mounted) {
        _updateLocationSilently();
      }
    });
  }
  
  Future<void> _updateLocationSilently() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (position.latitude >= 5.6 && position.latitude <= 20.5 &&
          position.longitude >= 97.3 && position.longitude <= 105.6) {
        if (mounted) {
          setState(() {
            _currentLatitude = position.latitude;
            _currentLongitude = position.longitude;
          });
          
          // Save location to database if rider has active job
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
      }
    } catch (e) {
      // Silently fail, keep using last known location
    }
  }

  Future<void> _acceptJob(Map<String, dynamic> job) async {
    if (currentUser == null) return;

    // Check if rider already has a job
    if (currentJob != null) {
      _showMessage('คุณมีงานที่ยังไม่เสร็จอยู่แล้ว');
      return;
    }

    try {
      final riderId = currentUser!['user_id'] ?? currentUser!['id'];
      final deliveryId = job['delivery_id'];
      
      print('🔄 Accepting job $deliveryId for rider $riderId');
      
      final success = await ApiService.acceptDeliveryJob(deliveryId, riderId);
      
      if (success) {
        print('✅ Job accepted successfully');
        _showMessage('รับงานสำเร็จ!');
        
        // Set currentJob immediately with the job data we have
        if (mounted) {
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
          print('🔄 UI updated with job ${job['delivery_id']}');
        }
        
        // Then reload from server in background to get complete data
        Future.delayed(const Duration(milliseconds: 500), () {
          _loadCurrentJob();
        });
      } else {
        print('❌ Failed to accept job');
        _showMessage('ไม่สามารถรับงานได้ อาจมีคนอื่นรับไปแล้ว');
        await _loadAvailableJobs();
      }
    } catch (e) {
      _showMessage('เกิดข้อผิดพลาด: $e');
      print('❌ Error accepting job: $e');
    }
  }

  Future<void> _updateJobStatus(String newStatus) async {
    if (currentJob == null) return;

    // Check if photo is required and captured
    if (_capturedPhoto == null) {
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
        setState(() {
          currentJob!['status'] = newStatus;
          _capturedPhoto = null; // Clear photo after successful update
        });
        _showMessage('อัพเดทสถานะสำเร็จ!');
        
        if (newStatus == 'DELIVERED') {
          // Job completed, clear current job
          setState(() {
            currentJob = null;
          });
          await _loadAvailableJobs();
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
        setState(() {
          _capturedPhoto = File(photo.path);
        });
        _showMessage('ถ่ายรูปสำเร็จ! ตอนนี้สามารถอัพเดทสถานะได้');
      }
    } catch (e) {
      _showMessage('ไม่สามารถถ่ายรูปได้: $e');
    }
  }

  List<MapMarker> _getMapMarkers() {
    List<MapMarker> markers = [];
    
    // Always show rider's current location
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
    
    // Add pickup and dropoff markers if there's an active job
    if (currentJob != null) {
      final status = currentJob!['status'] ?? 'ASSIGNED';
      
      if (status == 'ASSIGNED') {
        // Show pickup location from database
        final pickupLat = currentJob!['pickup_lat'];
        final pickupLng = currentJob!['pickup_lng'];
        
        if (pickupLat != null && pickupLng != null) {
          markers.add(MapMarker(
            latitude: pickupLat is String ? double.parse(pickupLat) : pickupLat.toDouble(),
            longitude: pickupLng is String ? double.parse(pickupLng) : pickupLng.toDouble(),
            title: 'Pickup Location',
            type: MarkerType.pickup,
          ));
        }
      } else if (status == 'ON_ROUTE') {
        // Show dropoff location from database
        final deliveryLat = currentJob!['delivery_lat'];
        final deliveryLng = currentJob!['delivery_lng'];
        
        if (deliveryLat != null && deliveryLng != null) {
          markers.add(MapMarker(
            latitude: deliveryLat is String ? double.parse(deliveryLat) : deliveryLat.toDouble(),
            longitude: deliveryLng is String ? double.parse(deliveryLng) : deliveryLng.toDouble(),
            title: 'Delivery Location',
            type: MarkerType.destination,
          ));
        }
      }
    }
    
    return markers;
  }

  void _showMessage(String message) {
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
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
                decoration: BoxDecoration(
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
                decoration: BoxDecoration(
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
          
          if (note.isNotEmpty) ...[
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
    if (currentJob == null) return Container();

    final deliveryId = currentJob!['delivery_id']?.toString() ?? '0';
    final status = currentJob!['status'] ?? 'ASSIGNED';
    final senderName = currentJob!['sender_name'] ?? 'Unknown';
    final receiverName = currentJob!['receiver_name'] ?? 'Unknown';
    final pickupAddress = currentJob!['pickup_address'] ?? 'Address not available';
    final deliveryAddress = currentJob!['delivery_address'] ?? 'Address not available';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor(status), width: 2),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusDisplay(status),
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
          
          const SizedBox(height: 16),
          
          // Addresses
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
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
          
          const SizedBox(height: 12),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
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
          
          const SizedBox(height: 16),
          
          // Action Buttons
          if (status == 'ASSIGNED')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _updateJobStatus('ON_ROUTE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'เริ่มเดินทางรับสินค้า',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          if (status == 'ON_ROUTE')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _updateJobStatus('DELIVERED'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'ส่งสินค้าเสร็จแล้ว',
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

  Widget _buildNoActiveJobCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        children: [
          // Illustration placeholder
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.delivery_dining,
              size: 60,
              color: Colors.orange[600],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Job',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any active jobs at the moment. Check the available jobs below or wait for new assignments.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveJobCard(ScrollController scrollController) {
    if (currentJob == null) return Container();

    final status = currentJob!['status'] ?? 'ASSIGNED';
    final senderName = currentJob!['sender_name'] ?? 'Unknown';
    final receiverName = currentJob!['receiver_name'] ?? 'Unknown';
    final pickupAddress = currentJob!['pickup_address'] ?? 'Address not available';
    final deliveryAddress = currentJob!['delivery_address'] ?? 'Address not available';
    final note = currentJob!['note'] ?? 'Small Box';
    final deliveryId = currentJob!['delivery_id']?.toString() ?? '0';

    // Calculate progress based on status
    double progress = 0.25;
    String statusText = 'Accept';
    if (status == 'ASSIGNED') {
      progress = 0.5;
      statusText = 'Picked';
    } else if (status == 'ON_ROUTE') {
      progress = 0.75;
      statusText = 'Delivering';
    } else if (status == 'DELIVERED') {
      progress = 1.0;
      statusText = 'Completed';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header with ID and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delivery #$deliveryId',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusDisplay(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Job Details
              Text(
                'From: $senderName',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            'To: $receiverName',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            '$pickupAddress to $deliveryAddress',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue[600],
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            'Parcel: $note',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Status
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Progress Bar
          Column(
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 6,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Accept',
                    style: TextStyle(
                      fontSize: 12,
                      color: progress >= 0.25 ? Colors.blue : Colors.grey[600],
                      fontWeight: progress >= 0.25 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    'Picked',
                    style: TextStyle(
                      fontSize: 12,
                      color: progress >= 0.5 ? Colors.blue : Colors.grey[600],
                      fontWeight: progress >= 0.5 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    'Delivering',
                    style: TextStyle(
                      fontSize: 12,
                      color: progress >= 0.75 ? Colors.blue : Colors.grey[600],
                      fontWeight: progress >= 0.75 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 12,
                      color: progress >= 1.0 ? Colors.blue : Colors.grey[600],
                      fontWeight: progress >= 1.0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Update status step by step: ASSIGNED -> ON_ROUTE -> DELIVERED
                    String nextStatus;
                    if (status == 'ASSIGNED') {
                      nextStatus = 'ON_ROUTE';
                    } else if (status == 'ON_ROUTE') {
                      nextStatus = 'DELIVERED';
                    } else {
                      return; // Already delivered
                    }
                    _updateJobStatus(nextStatus);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'ASSIGNED' ? Colors.blue : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    status == 'ASSIGNED' ? 'เริ่มเดินทาง' : 'ส่งสินค้าเสร็จ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _takePhoto(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _capturedPhoto != null ? Colors.green : Colors.grey[400]!,
                      width: _capturedPhoto != null ? 2 : 1,
                    ),
                    backgroundColor: _capturedPhoto != null ? Colors.green[50] : null,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(
                    _capturedPhoto != null ? Icons.check_circle : Icons.camera_alt,
                    color: _capturedPhoto != null ? Colors.green : Colors.grey[700],
                    size: 18,
                  ),
                  label: Text(
                    _capturedPhoto != null ? 'ถ่ายแล้ว' : 'ถ่ายรูป',
                    style: TextStyle(
                      color: _capturedPhoto != null ? Colors.green : Colors.grey[700],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageIllustration() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Shadow
        Positioned(
          bottom: 10,
          child: Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.brown[300]?.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        // Box
        Container(
          width: 70,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.brown[400],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              // Box lines
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Container(
                  height: 1,
                  color: Colors.brown[600],
                ),
              ),
              Positioned(
                top: 10,
                bottom: 10,
                left: 35,
                child: Container(
                  width: 1,
                  color: Colors.brown[600],
                ),
              ),
              // Arrows
              Positioned(
                bottom: 8,
                left: 15,
                child: Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.brown[800],
                  size: 16,
                ),
              ),
              Positioned(
                bottom: 8,
                right: 15,
                child: Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.brown[800],
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent going back if rider has active job
        if (currentJob != null) {
          _showMessage('Please complete your current job first');
          return false;
        }
        return true;
      },
      child: Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Rider Dashboard',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: currentJob != null
          ? Stack(
              children: [
                // Full screen map as background
                LongdoMapWidget(
                  height: double.infinity,
                  latitude: _currentLatitude ?? 13.7563,
                  longitude: _currentLongitude ?? 100.5018,
                  zoom: 14,
                  markers: _getMapMarkers(),
                ),
                // LIVE indicator at top right
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE TRACKING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Job info card at bottom - draggable
                DraggableScrollableSheet(
                  initialChildSize: 0.35,
                  minChildSize: 0.2,
                  maxChildSize: 0.8,
                  builder: (context, scrollController) {
                    return _buildActiveJobCard(scrollController);
                  },
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadAvailableJobs();
                await _loadCurrentJob();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNoActiveJobCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: RiderBottomNav(
        currentIndex: 0,
        hasActiveJob: currentJob != null,
      ),
      ),
    );
  }
}
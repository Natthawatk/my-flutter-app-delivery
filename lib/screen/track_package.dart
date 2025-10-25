import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/longdo_map.dart';

class DottedLinePainter extends CustomPainter {
  final bool horizontal;
  
  DottedLinePainter({this.horizontal = false});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1;
    
    const dashWidth = 3.0;
    const dashSpace = 3.0;
    
    if (horizontal) {
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, size.height / 2),
          Offset(startX + dashWidth, size.height / 2),
          paint,
        );
        startX += dashWidth + dashSpace;
      }
    } else {
      double startY = 0;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(size.width / 2, startY),
          Offset(size.width / 2, startY + dashWidth),
          paint,
        );
        startY += dashWidth + dashSpace;
      }
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TrackPackageScreen extends StatefulWidget {
  const TrackPackageScreen({Key? key}) : super(key: key);

  @override
  State<TrackPackageScreen> createState() => _TrackPackageScreenState();
}

class _TrackPackageScreenState extends State<TrackPackageScreen> {
  Map<String, dynamic>? deliveryData;
  bool isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && deliveryData == null) {
      setState(() {
        deliveryData = args;
        isLoading = false;
      });
    }
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
        return 'Waiting for Rider Pickup';
      case 'ASSIGNED':
        return 'Rider Assigned';
      case 'ON_ROUTE':
        return 'On the Way';
      case 'DELIVERED':
        return 'Delivered';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'WAITING':
        return Icons.schedule;
      case 'ASSIGNED':
        return Icons.local_shipping;
      case 'ON_ROUTE':
        return Icons.directions_bike;
      case 'DELIVERED':
        return Icons.inventory_2;
      default:
        return Icons.help;
    }
  }

  List<Map<String, dynamic>> _getTimelineSteps(String currentStatus) {
    final steps = [
      {
        'status': 'WAITING',
        'title': 'Waiting for Rider Pickup',
        'time': '10:00 AM',
        'location': '123 Main St',
        'icon': Icons.inventory_2,
        'completed': true,
      },
      {
        'status': 'ASSIGNED',
        'title': 'Rider Assigned',
        'time': '12:00 PM',
        'location': '456 Oak Ave',
        'icon': Icons.local_shipping,
        'completed': _isStatusCompleted('ASSIGNED', currentStatus),
      },
      {
        'status': 'ON_ROUTE',
        'title': 'On the Way',
        'time': '2:00 PM',
        'location': '789 Pine Ln',
        'icon': Icons.directions_bike,
        'completed': _isStatusCompleted('ON_ROUTE', currentStatus),
      },
      {
        'status': 'DELIVERED',
        'title': 'Delivered',
        'time': '3:00 PM',
        'location': '101 Elm St',
        'icon': Icons.inventory_2,
        'completed': _isStatusCompleted('DELIVERED', currentStatus),
      },
    ];

    return steps;
  }

  bool _isStatusCompleted(String stepStatus, String currentStatus) {
    const statusOrder = ['WAITING', 'ASSIGNED', 'ON_ROUTE', 'DELIVERED'];
    final stepIndex = statusOrder.indexOf(stepStatus);
    final currentIndex = statusOrder.indexOf(currentStatus);
    return stepIndex <= currentIndex;
  }

  Widget _buildTimelineItem(Map<String, dynamic> step, bool isLast) {
    final isCompleted = step['completed'] as bool;
    final color = isCompleted ? Colors.green : Colors.grey[300]!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                step['icon'] as IconData,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step['title'] as String,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? Colors.black : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${step['time']}, ${step['location']}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _isSender() async {
    final currentUser = await ApiService.getCurrentUser();
    if (currentUser == null || deliveryData == null) return false;
    
    final userId = currentUser['user_id'];
    final senderId = deliveryData!['sender_id'];
    
    return userId == senderId;
  }

  bool _shouldShowRiderOnMap(String status, bool isSender) {
    // Show rider markers only for ASSIGNED [2] and ON_ROUTE [3] for both sender and receiver
    return ['ASSIGNED', 'ON_ROUTE'].contains(status);
  }

  Future<List<MapMarker>> _getMapMarkers(String status) async {
    List<MapMarker> markers = [];
    final isSender = await _isSender();
    
    // Get coordinates from delivery data
    final pickupLat = deliveryData?['pickup_lat'];
    final pickupLng = deliveryData?['pickup_lng'];
    final dropoffLat = deliveryData?['dropoff_lat'];
    final dropoffLng = deliveryData?['dropoff_lng'];
    final deliveryId = deliveryData?['delivery_id'];
    
    print('🗺️ Getting markers for status: $status');
    print('📍 Pickup coords: lat=$pickupLat, lng=$pickupLng');
    print('📍 Dropoff coords: lat=$dropoffLat, lng=$dropoffLng');
    
    // Get rider's real-time location if job is active
    Map<String, dynamic>? riderLocation;
    if (deliveryId != null && (status == 'ASSIGNED' || status == 'ON_ROUTE')) {
      riderLocation = await ApiService.getRiderLocation(deliveryId);
      print('🏍️ Rider location from DB: $riderLocation');
    }
    
    // For WAITING status, show pickup address marker only
    if (status == 'WAITING') {
      double lat = 13.7563; // Default Bangkok
      double lng = 100.5018;
      
      if (pickupLat != null && pickupLng != null) {
        lat = pickupLat is String ? double.parse(pickupLat) : pickupLat.toDouble();
        lng = pickupLng is String ? double.parse(pickupLng) : pickupLng.toDouble();
      }
      
      print('📦 Adding PICKUP marker at: $lat, $lng');
      markers.add(MapMarker(
        latitude: lat,
        longitude: lng,
        title: 'Pickup Location - Waiting for Rider',
        type: MarkerType.pickup,
      ));
    } 
    // For ASSIGNED status, show both rider and pickup markers
    else if (status == 'ASSIGNED') {
      double pickupLatVal = 13.7563;
      double pickupLngVal = 100.5018;
      
      if (pickupLat != null && pickupLng != null) {
        pickupLatVal = pickupLat is String ? double.parse(pickupLat) : pickupLat.toDouble();
        pickupLngVal = pickupLng is String ? double.parse(pickupLng) : pickupLng.toDouble();
      }
      
      // Add pickup marker
      print('📦 Adding PICKUP marker at: $pickupLatVal, $pickupLngVal');
      markers.add(MapMarker(
        latitude: pickupLatVal,
        longitude: pickupLngVal,
        title: 'Pickup Location',
        type: MarkerType.pickup,
      ));
      
      // Add rider marker from real-time location
      if (riderLocation != null && riderLocation['lat'] != null && riderLocation['lng'] != null) {
        final riderLat = riderLocation['lat'] is String 
            ? double.parse(riderLocation['lat']) 
            : riderLocation['lat'].toDouble();
        final riderLng = riderLocation['lng'] is String 
            ? double.parse(riderLocation['lng']) 
            : riderLocation['lng'].toDouble();
        
        print('🏍️ Adding RIDER marker at: $riderLat, $riderLng');
        markers.add(MapMarker(
          latitude: riderLat,
          longitude: riderLng,
          title: 'Rider - Going to Pickup',
          type: MarkerType.rider,
        ));
      } else {
        // Fallback: use offset from pickup
        print('🏍️ Adding RIDER marker (fallback) near pickup');
        markers.add(MapMarker(
          latitude: pickupLatVal + 0.001,
          longitude: pickupLngVal + 0.001,
          title: 'Rider - Going to Pickup',
          type: MarkerType.rider,
        ));
      }
    }
    // For ON_ROUTE status, show rider and dropoff markers
    else if (status == 'ON_ROUTE') {
      double dropoffLatVal = 13.7563;
      double dropoffLngVal = 100.5018;
      
      if (dropoffLat != null && dropoffLng != null) {
        dropoffLatVal = dropoffLat is String ? double.parse(dropoffLat) : dropoffLat.toDouble();
        dropoffLngVal = dropoffLng is String ? double.parse(dropoffLng) : dropoffLng.toDouble();
      }
      
      // Add dropoff marker
      print('🎯 Adding DROPOFF marker at: $dropoffLatVal, $dropoffLngVal');
      markers.add(MapMarker(
        latitude: dropoffLatVal,
        longitude: dropoffLngVal,
        title: 'Delivery Location',
        type: MarkerType.destination,
      ));
      
      // Add rider marker from real-time location
      if (riderLocation != null && riderLocation['lat'] != null && riderLocation['lng'] != null) {
        final riderLat = riderLocation['lat'] is String 
            ? double.parse(riderLocation['lat']) 
            : riderLocation['lat'].toDouble();
        final riderLng = riderLocation['lng'] is String 
            ? double.parse(riderLocation['lng']) 
            : riderLocation['lng'].toDouble();
        
        print('🏍️ Adding RIDER marker at: $riderLat, $riderLng');
        markers.add(MapMarker(
          latitude: riderLat,
          longitude: riderLng,
          title: 'Rider - Delivering Package',
          type: MarkerType.rider,
        ));
      } else {
        // Fallback: use offset from dropoff
        print('🏍️ Adding RIDER marker (fallback) near dropoff');
        markers.add(MapMarker(
          latitude: dropoffLatVal - 0.001,
          longitude: dropoffLngVal - 0.001,
          title: 'Rider - Delivering Package',
          type: MarkerType.rider,
        ));
      }
    }
    // For DELIVERED status, show dropoff marker only
    else if (status == 'DELIVERED') {
      double dropoffLatVal = 13.7563;
      double dropoffLngVal = 100.5018;
      
      if (dropoffLat != null && dropoffLng != null) {
        dropoffLatVal = dropoffLat is String ? double.parse(dropoffLat) : dropoffLat.toDouble();
        dropoffLngVal = dropoffLng is String ? double.parse(dropoffLng) : dropoffLng.toDouble();
      }
      
      // Add dropoff marker
      print('✅ Adding DELIVERED marker at: $dropoffLatVal, $dropoffLngVal');
      markers.add(MapMarker(
        latitude: dropoffLatVal,
        longitude: dropoffLngVal,
        title: 'Delivered Successfully',
        type: MarkerType.destination,
      ));
    }
    
    print('✅ Total markers created: ${markers.length}');
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final receiverName = deliveryData?['receiver_name'] ?? 'Unknown';
    final senderName = deliveryData?['sender_name'] ?? 'Unknown';
    final deliveryId = deliveryData?['delivery_id']?.toString() ?? '0';
    final currentStatus = deliveryData?['status'] ?? 'WAITING';
    final riderName = deliveryData?['rider_name'] ?? 'Not assigned';
    final riderPhone = deliveryData?['rider_phone'] ?? '';
    
    print('🔍 Delivery data: rider_name=$riderName, status=$currentStatus');
    print('🔍 Addresses: pickup=${deliveryData?['pickup_address']}, dropoff=${deliveryData?['dropoff_address']}');
    final timelineSteps = _getTimelineSteps(currentStatus);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Track Package',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<MapMarker>>(
        future: _getMapMarkers(currentStatus),
        builder: (context, snapshot) {
          final markers = snapshot.data ?? [];
          
          // Get center coordinates from pickup address or use default
          final pickupLat = deliveryData?['pickup_lat'];
          final pickupLng = deliveryData?['pickup_lng'];
          
          double centerLat = 13.7563;
          double centerLng = 100.5018;
          
          if (pickupLat != null && pickupLng != null) {
            centerLat = pickupLat is String ? double.parse(pickupLat) : pickupLat.toDouble();
            centerLng = pickupLng is String ? double.parse(pickupLng) : pickupLng.toDouble();
          }
          
          return Stack(
            children: [
              // Full screen map as background
              LongdoMapWidget(
                height: double.infinity,
                latitude: centerLat,
                longitude: centerLng,
                zoom: 14,
                markers: markers,
              ),
              // Info card at bottom
              DraggableScrollableSheet(
                initialChildSize: 0.35,
                minChildSize: 0.2,
                maxChildSize: 0.8,
                builder: (context, scrollController) {
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
                          // Delivery ID and Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Delivery #$deliveryId',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(currentStatus),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getStatusDisplay(currentStatus),
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
                          
                          // Package Location Card (for WAITING status)
                          if (currentStatus == 'WAITING')
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2,
                                        color: Colors.orange[700],
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Waiting for Rider',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Package is ready for pickup',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
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
                                              'Pickup Address',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              deliveryData?['pickup_address'] ?? 'Address not available',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'From: $senderName',
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
                                ),
                              ],
                            ),
            
                          // Rider Information Card (for other statuses)
                          if (currentStatus != 'WAITING')
                            Container(
                              padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                  children: [
                    // Rider Info Row
                    Row(
                      children: [
                        // Rider Avatar
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.blue[700],
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Rider Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                riderName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                riderPhone.isNotEmpty ? riderPhone : 'Phone not available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Contact Button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone,
                                color: Colors.blue[700],
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Contact',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Addresses Section
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pickup Address
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
                                      'Pickup Address',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      deliveryData?['pickup_address'] ?? 'Address not available',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'From: $senderName',
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
                          
                          // Dotted Line
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const SizedBox(width: 4),
                                Container(
                                  width: 2,
                                  height: 20,
                                  child: CustomPaint(
                                    painter: DottedLinePainter(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    child: CustomPaint(
                                      painter: DottedLinePainter(horizontal: true),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Delivery Address
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
                                      'Delivery Address',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      deliveryData?['dropoff_address'] ?? 'Address not available',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'To: $receiverName',
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Timeline Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline
                  ...timelineSteps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    final isLast = index == timelineSteps.length - 1;
                    
                    return _buildTimelineItem(step, isLast);
                  }).toList(),
                ],
              ),
            ),
                        ],
                      ),
                    ),
                  ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
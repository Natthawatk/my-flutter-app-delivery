import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../widgets/custom_bottom_nav.dart';


class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({Key? key}) : super(key: key);

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? currentUser;
  List<Map<String, dynamic>> senderDeliveries = [];
  List<Map<String, dynamic>> receiverDeliveries = [];
  String selectedStatus = 'All';
  bool isLoading = true;
  Timer? _realTimeTimer;


  final List<String> statusFilters = ['All', 'WAITING', 'ASSIGNED', 'ON_ROUTE', 'DELIVERED'];
  
  // Status display mapping
  final Map<String, String> statusDisplayMap = {
    'WAITING': 'Waiting',
    'ASSIGNED': 'Rider Assigned', 
    'ON_ROUTE': 'On the way',
    'DELIVERED': 'Delivered'
  };

  final Map<String, String> statusFilterMap = {
    'All': 'All',
    'WAITING': 'Waiting',
    'ASSIGNED': 'Rider Assigned',
    'ON_ROUTE': 'On the way', 
    'DELIVERED': 'Delivered'
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _realTimeTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadDeliveries();
    }
  }

  Future<void> _loadUserData() async {
    final user = await ApiService.getCurrentUser();
    if (user != null) {
      setState(() {
        currentUser = user;
      });
      _loadDeliveries();
    }
  }

  Future<void> _loadDeliveries() async {
    if (currentUser == null) return;

    setState(() {
      isLoading = true;
    });

    final userId = currentUser!['user_id'] ?? currentUser!['id'];
    print('📦 Loading deliveries for user: $userId, tab: ${_tabController.index}, status: $selectedStatus');
    
    if (_tabController.index == 0) {
      // Sender tab
      final deliveries = await ApiService.getSenderDeliveries(
        userId, 
        status: selectedStatus == 'All' ? null : selectedStatus
      );
      print('📤 Sender deliveries loaded: ${deliveries.length} items');
      setState(() {
        senderDeliveries = deliveries;
        isLoading = false;
      });

    } else {
      // Receiver tab
      final deliveries = await ApiService.getReceiverDeliveries(
        userId,
        status: selectedStatus == 'All' ? null : selectedStatus
      );
      print('📥 Receiver deliveries loaded: ${deliveries.length} items');
      setState(() {
        receiverDeliveries = deliveries;
        isLoading = false;
      });

    }
    
    _startRealTimeUpdates();
  }

  void _startRealTimeUpdates() {
    _realTimeTimer?.cancel();
    _realTimeTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadDeliveries();
    });
  }



  String _getStatusDisplay(String status) {
    switch (status) {
      case 'WAITING':
        return 'Waiting for Rider';
      case 'ASSIGNED':
        return 'Going to Pickup';
      case 'ON_ROUTE':
        return 'Delivering';
      case 'DELIVERED':
        return 'Delivered';
      default:
        return status;
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

  Widget _buildDeliveryItem(Map<String, dynamic> delivery, bool isSender) {
    final status = delivery['status'] ?? 'Unknown';
    final statusDisplay = statusDisplayMap[status] ?? status;
    final note = delivery['note'] ?? 'No details';
    final deliveryId = delivery['delivery_id']?.toString() ?? '0';
    final personName = isSender 
        ? delivery['receiver_name'] ?? 'Unknown'
        : delivery['sender_name'] ?? 'Unknown';
    final riderName = delivery['rider_name'] ?? 'Not assigned';
    final isActive = ['WAITING', 'ASSIGNED', 'ON_ROUTE'].contains(status);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/track',
          arguments: delivery,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: Colors.blue, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        statusDisplay,
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isSender ? 'Receiver' : 'Sender'}: $personName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Parcel ID: $deliveryId',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          status == 'WAITING' ? Icons.schedule : Icons.person, 
                          size: 14, 
                          color: Colors.blue
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status == 'WAITING' 
                            ? 'Waiting for rider assignment'
                            : 'Rider: $riderName',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: 30,
                  ),
                  if (isActive)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'WAITING':
        return Icons.schedule;
      case 'ASSIGNED':
        return Icons.person_pin;
      case 'ON_ROUTE':
        return Icons.local_shipping;
      case 'DELIVERED':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Deliveries',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: 'Sender'),
            Tab(text: 'Receiver'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Active Deliveries Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Deliveries',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                // Status Filter
                DropdownButton<String>(
                  value: selectedStatus,
                  underline: Container(),
                  items: statusFilters.map((String status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(statusFilterMap[status] ?? status),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedStatus = newValue;
                      });
                      _loadDeliveries();
                    }
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Deliveries List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Sender Tab
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : senderDeliveries.isEmpty
                        ? const Center(
                            child: Text(
                              'No deliveries found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: senderDeliveries.length,
                            itemBuilder: (context, index) {
                              return _buildDeliveryItem(senderDeliveries[index], true);
                            },
                          ),
                
                // Receiver Tab
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : receiverDeliveries.isEmpty
                        ? const Center(
                            child: Text(
                              'No deliveries found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: receiverDeliveries.length,
                            itemBuilder: (context, index) {
                              return _buildDeliveryItem(receiverDeliveries[index], false);
                            },
                          ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 1),
    );
  }
}
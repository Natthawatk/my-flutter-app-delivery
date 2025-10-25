import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../widgets/rider_bottom_nav.dart';


class RiderJobsScreen extends StatefulWidget {
  const RiderJobsScreen({Key? key}) : super(key: key);

  @override
  State<RiderJobsScreen> createState() => _RiderJobsScreenState();
}

class _RiderJobsScreenState extends State<RiderJobsScreen> {
  Map<String, dynamic>? currentUser;
  List<Map<String, dynamic>> availableJobs = [];
  bool isLoading = true;
  Timer? _realTimeTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _realTimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = await ApiService.getCurrentUser();
    if (user != null) {
      setState(() {
        currentUser = user;
      });
      await _loadAvailableJobs();
      _startRealTimeUpdates();
    }
  }

  Future<void> _loadAvailableJobs() async {
    if (currentUser == null) return;

    setState(() {
      isLoading = true;
    });

    try {
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

  void _startRealTimeUpdates() {
    _realTimeTimer?.cancel();
    _realTimeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadAvailableJobs();
    });
  }

  Future<void> _acceptJob(Map<String, dynamic> job) async {
    if (currentUser == null) return;

    // Check if rider already has an active job
    final riderId = currentUser!['user_id'] ?? currentUser!['id'];
    final currentJob = await ApiService.getRiderCurrentJob(riderId);
    
    if (currentJob != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have an active job. Complete it first.')),
      );
      return;
    }

    try {
      final deliveryId = job['delivery_id'];
      
      final success = await ApiService.acceptDeliveryJob(deliveryId, riderId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job accepted successfully!')),
        );
        
        // Navigate back to dashboard to show active job
        Navigator.pushReplacementNamed(context, '/rider_dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept job. It may have been taken by another rider.')),
        );
        // Refresh jobs list
        _loadAvailableJobs();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildJobItem(Map<String, dynamic> job, int index) {
    final pickupAddress = job['pickup_address'] ?? 'Address not available';
    final deliveryAddress = job['delivery_address'] ?? 'Address not available';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'รับ: ${_shortenAddress(pickupAddress)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.flag, size: 16, color: Colors.red[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'ส่ง: ${_shortenAddress(deliveryAddress)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _acceptJob(job),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'รับงาน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }



  String _shortenAddress(String address) {
    if (address.length > 20) {
      return '${address.substring(0, 20)}...';
    }
    return address;
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
          'Available Jobs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAvailableJobs,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Jobs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (isLoading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Jobs List
              if (availableJobs.isEmpty && !isLoading)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.work_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No available jobs at the moment',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...availableJobs.asMap().entries.map((entry) => 
                  _buildJobItem(entry.value, entry.key)).toList(),
              
              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
      bottomNavigationBar: const RiderBottomNav(currentIndex: 1),
    );
  }
}
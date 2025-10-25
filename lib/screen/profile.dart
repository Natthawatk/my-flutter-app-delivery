import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/rider_bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await ApiService.getCurrentUser();
      setState(() {
        _userProfile = user ?? {
          'name': 'Unknown User',
          'phone': 'No phone',
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _userProfile = {
          'name': 'Error loading user',
          'phone': 'No phone',
        };
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'LuxusryDeliveries',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  
                  // Profile Avatar
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF4D1AE), Color(0xFFE8B896)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: (_userProfile?['url'] != null && _userProfile!['url'].toString().isNotEmpty)
                          ? Image.network(
                              _userProfile!['url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white,
                                );
                              },
                            )
                          : const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Name
                  Text(
                    _userProfile?['name'] ?? 'Unknown User',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Phone Number Section
                  _buildInfoSection(
                    'Phone Number',
                    _userProfile?['phone'] ?? 'No phone number',
                  ),
                  const SizedBox(height: 32),

                  // Role Section
                  _buildInfoSection(
                    'Role',
                    _userProfile?['role'] ?? 'CUSTOMER',
                  ),
                  const SizedBox(height: 32),

                  // User ID Section
                  _buildInfoSection(
                    'User ID',
                    _userProfile?['user_id']?.toString() ?? 'Unknown',
                  ),
                  
                  // Spacer to push logout button to bottom
                  const SizedBox(height: 100),

                  // Logout Button - moved to bottom
                  Container(
                    width: double.infinity,
                    height: 56,
                    margin: const EdgeInsets.only(bottom: 20),
                    child: OutlinedButton(
                      onPressed: () async {
                        await ApiService.logout();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFFE53E3E),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Color(0xFFE53E3E),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _userProfile?['role'] == 'RIDER' 
          ? const RiderBottomNav(currentIndex: 2)
          : const CustomBottomNav(currentIndex: 3),
    );
  }

  Widget _buildInfoSection(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }
}
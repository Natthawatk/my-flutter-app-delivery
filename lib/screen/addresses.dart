import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/custom_bottom_nav.dart';
import 'select_location_map.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({Key? key}) : super(key: key);

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  Map<String, dynamic>? currentUser;
  List<Map<String, dynamic>> addresses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await ApiService.getCurrentUser();
    if (user != null) {
      setState(() {
        currentUser = user;
      });
      _loadAddresses();
    }
  }

  Future<void> _loadAddresses() async {
    if (currentUser == null) return;

    setState(() {
      isLoading = true;
    });

    final userId = currentUser!['user_id'] ?? currentUser!['id'];
    final addressList = await ApiService.getUserAddresses(userId);
    
    setState(() {
      addresses = addressList;
      isLoading = false;
    });
  }

  IconData _getAddressIcon(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'vacation home':
      case 'vacation':
        return Icons.beach_access;
      default:
        return Icons.location_on;
    }
  }

  void _showAddAddressDialog() async {
    final labelController = TextEditingController();
    final addressController = TextEditingController();
    bool isDefault = false;
    double? selectedLat;
    double? selectedLng;

    // Open map to select location
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectLocationMapScreen(),
      ),
    );

    if (result == null) return; // User cancelled

    selectedLat = result['lat'];
    selectedLng = result['lng'];
    addressController.text = result['address'] ?? '';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Address'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: 'Label (e.g., Home, Work)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'GPS: ${selectedLat?.toStringAsFixed(6)}, ${selectedLng?.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: isDefault,
                          onChanged: (value) {
                            setDialogState(() {
                              isDefault = value ?? false;
                            });
                          },
                        ),
                        const Text('Set as default address'),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (labelController.text.isNotEmpty && 
                        addressController.text.isNotEmpty &&
                        selectedLat != null &&
                        selectedLng != null) {
                      final userId = currentUser!['user_id'];
                      
                      await ApiService.addAddress(
                        userId: userId,
                        label: labelController.text,
                        addressLine: addressController.text,
                        lat: selectedLat!,
                        lng: selectedLng!,
                        isDefault: isDefault,
                      );
                      
                      Navigator.pop(context);
                      _loadAddresses();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address added successfully!')),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditAddressDialog(Map<String, dynamic> address) async {
    final labelController = TextEditingController(text: address['label']);
    final addressController = TextEditingController(text: address['address_line']);
    bool isDefault = address['is_default'] == 1;
    double? selectedLat = address['lat'];
    double? selectedLng = address['lng'];

    // Show option to change location
    final shouldChangeLocation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Address'),
        content: const Text('Do you want to change the location on map?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, keep current'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, change location'),
          ),
        ],
      ),
    );

    if (shouldChangeLocation == true) {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => SelectLocationMapScreen(
            initialLat: selectedLat,
            initialLng: selectedLng,
          ),
        ),
      );

      if (result != null) {
        selectedLat = result['lat'];
        selectedLng = result['lng'];
        addressController.text = result['address'] ?? addressController.text;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Address'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: 'Label (e.g., Home, Work)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'GPS: ${selectedLat?.toStringAsFixed(6)}, ${selectedLng?.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: isDefault,
                          onChanged: (value) {
                            setDialogState(() {
                              isDefault = value ?? false;
                            });
                          },
                        ),
                        const Text('Set as default address'),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    await ApiService.deleteAddress(address['address_id']);
                    Navigator.pop(context);
                    _loadAddresses();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address deleted')),
                    );
                  },
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (labelController.text.isNotEmpty && 
                        addressController.text.isNotEmpty &&
                        selectedLat != null &&
                        selectedLng != null) {
                      await ApiService.updateAddress(
                        addressId: address['address_id'],
                        label: labelController.text,
                        addressLine: addressController.text,
                        lat: selectedLat!,
                        lng: selectedLng!,
                        isDefault: isDefault,
                      );
                      
                      Navigator.pop(context);
                      _loadAddresses();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address updated successfully!')),
                      );
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAddressItem(Map<String, dynamic> address) {
    final label = address['label'] ?? 'Unknown';
    final addressLine = address['address_line'] ?? 'No address';
    final isDefault = address['is_default'] == 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDefault ? Border.all(color: Colors.blue, width: 2) : null,
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
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getAddressIcon(label),
              color: Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  addressLine,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: () => _showEditAddressDialog(address),
          ),
        ],
      ),
    );
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
          'Addresses',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Saved Addresses Header
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Saved Addresses',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          
          // Addresses List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : addresses.isEmpty
                    ? const Center(
                        child: Text(
                          'No addresses found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: addresses.length,
                        itemBuilder: (context, index) {
                          return _buildAddressItem(addresses[index]);
                        },
                      ),
          ),
          
          // Add New Address Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _showAddAddressDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Add New Address',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';

class NewDelivery extends StatefulWidget {
  const NewDelivery({Key? key}) : super(key: key);

  @override
  State<NewDelivery> createState() => _NewDeliveryState();
}

class _NewDeliveryState extends State<NewDelivery> {
  Map<String, dynamic>? selectedCustomer;
  Map<String, dynamic>? selectedAddress;
  List<Map<String, dynamic>> customerAddresses = [];
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemDescriptionController = TextEditingController();
  bool isLoadingAddresses = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get customer data from navigation arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && selectedCustomer == null) {
      setState(() {
        selectedCustomer = args;
      });
      _loadCustomerAddresses();
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerAddresses() async {
    if (selectedCustomer != null) {
      setState(() {
        isLoadingAddresses = true;
      });
      
      final customerId = selectedCustomer!['id'];
      final addresses = await ApiService.getUserAddresses(customerId);
      
      setState(() {
        customerAddresses = addresses;
        if (customerAddresses.isNotEmpty) {
          // Find default address or use first one
          final defaultAddress = customerAddresses.firstWhere(
            (addr) => addr['is_default'] == 1,
            orElse: () => customerAddresses.first,
          );
          selectedAddress = defaultAddress;
        }
        isLoadingAddresses = false;
      });
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _showAddAddressDialog() {
    final labelController = TextEditingController();
    final addressController = TextEditingController();
    bool isDefault = customerAddresses.isEmpty; // Set as default if it's the first address

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Address for Customer'),
              content: Column(
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
                    maxLines: 2,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (labelController.text.isNotEmpty && 
                        addressController.text.isNotEmpty) {
                      final customerId = selectedCustomer!['id'];
                      
                      final result = await ApiService.addAddress(
                        userId: customerId,
                        label: labelController.text,
                        addressLine: addressController.text,
                        lat: 37.7749, // Mock coordinates
                        lng: -122.4194,
                        isDefault: isDefault,
                      );
                      
                      Navigator.pop(context);
                      
                      if (result['success'] == true) {
                        _loadCustomerAddresses(); // Reload addresses
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address added successfully!')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to add address')),
                        );
                      }
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

  Future<void> _createDelivery() async {
    if (selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customer selected')),
      );
      return;
    }

    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an address')),
      );
      return;
    }

    if (_itemNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อสินค้า')),
      );
      return;
    }

    if (_itemDescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรายละเอียดสินค้า')),
      );
      return;
    }

    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาถ่ายรูปสินค้า')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Create delivery via API
      final result = await ApiService.createDelivery(
        customerId: selectedCustomer!['id'],
        addressId: selectedAddress!['address_id'],
        itemName: _itemNameController.text.trim(),
        itemDescription: _itemDescriptionController.text.trim(),
        photoFile: selectedImage!,
      );

      // Close loading dialog
      Navigator.pop(context);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery created successfully!')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create delivery: ${result['message']}')),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating delivery: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'New Delivery',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // Customer Avatar
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange[100],
                ),
                child: const Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.orange,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Customer Name Field
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  selectedCustomer?['name'] ?? 'No customer selected',
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedCustomer != null ? Colors.black : Colors.grey[600],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Address Selection
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isLoadingAddresses
                          ? const Text('Loading addresses...')
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<Map<String, dynamic>>(
                                value: selectedAddress,
                                hint: Text(
                                  'Select Address',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                isExpanded: true,
                                items: customerAddresses.map((Map<String, dynamic> address) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: address,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              address['label'] ?? 'Address',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (address['is_default'] == 1) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue,
                                                  borderRadius: BorderRadius.circular(8),
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
                                        Text(
                                          address['address_line'] ?? 'No address',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (Map<String, dynamic>? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      selectedAddress = newValue;
                                    });
                                  }
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              
              
              const SizedBox(height: 8),
              
              // Add New Address Button (if no addresses)
              if (customerAddresses.isEmpty && !isLoadingAddresses)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: TextButton.icon(
                    onPressed: () => _showAddAddressDialog(),
                    icon: const Icon(Icons.add_location, color: Colors.blue),
                    label: const Text(
                      'Add Address for Customer',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
              
              const SizedBox(height: 12),
              
              // Item Name
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _itemNameController,
                        decoration: const InputDecoration(
                          hintText: 'name',
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Item Description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _itemDescriptionController,
                  decoration: const InputDecoration(
                    hintText: 'description',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 16),
                  maxLines: 3,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Add Photo Section
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: selectedImage != null
                      ? Column(
                          children: [
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(selectedImage!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Tap to change photo',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          children: [
                            Icon(Icons.camera_alt, color: Colors.grey),
                            SizedBox(width: 12),
                            Text(
                              'Add Photo',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Create Delivery Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createDelivery,
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
                    'Add New Delivery',
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
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://my-node-app-lvf0.onrender.com/api';
  
  static Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String name,
    String role = 'CUSTOMER',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'name': name,
        'role': role,
      }),
    );
    
    return jsonDecode(response.body);
  }
  
  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      print('Attempting login to: $baseUrl/auth/login');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      // Check if response is HTML (server error)
      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        return {
          'error': 'Server error (${response.statusCode}): API not available',
          'details': 'The server returned an HTML error page instead of JSON'
        };
      }
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        // Save user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(data['user']));
      }
      
      return data;
    } catch (e) {
      print('Login error: $e');
      return {'error': 'Connection failed: $e'};
    }
  }
  
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
  }
  
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      return jsonDecode(userString);
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      print('Fetching customers from: $baseUrl/users/customers');
      final response = await http.get(
        Uri.parse('$baseUrl/users/customers'),
        headers: {'Content-Type': 'application/json'},
      );
      
      print('Customers response status: ${response.statusCode}');
      print('Customers response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['customers'] ?? []);
      } else {
        print('Failed to fetch customers: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching customers: $e');
      return [];
    }
  }

  static Future<List<String>> getCustomerAddresses(int customerId) async {
    try {
      print('Fetching addresses for customer: $customerId');
      final response = await http.get(
        Uri.parse('$baseUrl/users/$customerId/addresses'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['addresses'] ?? []);
      } else {
        print('Failed to fetch addresses: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching addresses: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getSenderDeliveries(int userId, {String? status}) async {
    try {
      String url = '$baseUrl/deliveries/sender/$userId';
      if (status != null && status != 'All') {
        url += '?status=$status';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['deliveries'] ?? []);
      } else {
        print('Failed to fetch sender deliveries: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching sender deliveries: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getReceiverDeliveries(int userId, {String? status}) async {
    try {
      String url = '$baseUrl/deliveries/receiver/$userId';
      if (status != null && status != 'All') {
        url += '?status=$status';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['deliveries'] ?? []);
      } else {
        print('Failed to fetch receiver deliveries: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching receiver deliveries: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUserAddresses(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/addresses'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['addresses'] ?? []);
      } else {
        print('Failed to fetch addresses: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching addresses: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addAddress({
    required int userId,
    required String label,
    required String addressLine,
    required double lat,
    required double lng,
    bool isDefault = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/addresses'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'label': label,
          'address_line': addressLine,
          'lat': lat,
          'lng': lng,
          'is_default': isDefault,
        }),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      print('Error adding address: $e');
      return {'error': 'Failed to add address'};
    }
  }

  static Future<Map<String, dynamic>> updateAddress({
    required int addressId,
    required String label,
    required String addressLine,
    required double lat,
    required double lng,
    bool isDefault = false,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/addresses/$addressId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'label': label,
          'address_line': addressLine,
          'lat': lat,
          'lng': lng,
          'is_default': isDefault,
        }),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      print('Error updating address: $e');
      return {'error': 'Failed to update address'};
    }
  }

  static Future<Map<String, dynamic>> deleteAddress(int addressId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/addresses/$addressId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      print('Error deleting address: $e');
      return {'error': 'Failed to delete address'};
    }
  }

  // Real-time rider tracking
  static Future<List<Map<String, dynamic>>> getRiderLocations(List<int> deliveryIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/riders/locations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'delivery_ids': deliveryIds}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['riders'] ?? []);
      } else {
        print('Failed to fetch rider locations: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching rider locations: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getDeliveryStatus(int deliveryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/deliveries/$deliveryId/status'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to fetch delivery status: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Error fetching delivery status: $e');
      return {};
    }
  }

  // Get available jobs for riders (WAITING status only)
  static Future<List<Map<String, dynamic>>> getAvailableJobs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/deliveries/available'));
      print('Available jobs response status: ${response.statusCode}');
      print('Available jobs response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['jobs'] ?? []);
      } else {
        print('Failed to get available jobs: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting available jobs: $e');
      return [];
    }
  }

  // Get rider's current job
  static Future<Map<String, dynamic>?> getRiderCurrentJob(int riderId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/deliveries/rider/$riderId/current'));
      print('Rider current job response status: ${response.statusCode}');
      print('Rider current job response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['job'];
      } else if (response.statusCode == 404) {
        return null; // No current job
      } else {
        print('Failed to get rider current job: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting rider current job: $e');
      return null;
    }
  }

  // Clean up stale rider assignments
  static Future<bool> cleanupRiderAssignments(int riderId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rider/$riderId/cleanup'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        print('Cleanup completed successfully');
        return true;
      } else {
        print('Failed to cleanup: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error cleaning up: $e');
      return false;
    }
  }

  // Accept delivery job
  static Future<bool> acceptDeliveryJob(int deliveryId, int riderId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deliveries/$deliveryId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rider_id': riderId}),
      );
      
      print('Accept job response status: ${response.statusCode}');
      print('Accept job response body: ${response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error accepting job: $e');
      return false;
    }
  }

  // Update delivery status
  static Future<bool> updateDeliveryStatus(int deliveryId, String status, {File? photoFile}) async {
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/deliveries/$deliveryId/status'),
      );
      
      request.fields['status'] = status;
      
      if (photoFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photoFile.path),
        );
      }
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      print('Update status response status: ${response.statusCode}');
      print('Update status response body: ${response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating status: $e');
      return false;
    }
  }

  // Create new delivery
  static Future<Map<String, dynamic>> createDelivery({
    required int customerId,
    required int addressId,
    required String itemName,
    required String itemDescription,
    required File photoFile,
  }) async {
    try {
      // Get current user (sender)
      final currentUser = await getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final senderId = currentUser['user_id'];

      print('Creating delivery with:');
      print('Sender ID: $senderId');
      print('Customer ID: $customerId');
      print('Address ID: $addressId');
      print('Item Name: $itemName');
      print('Item Description: $itemDescription');

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/deliveries'));
      
      // Add fields
      request.fields['sender_id'] = senderId.toString();
      request.fields['receiver_id'] = customerId.toString();
      request.fields['address_id'] = addressId.toString();
      request.fields['item_name'] = itemName;
      request.fields['item_description'] = itemDescription;
      
      // Add photo file
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        photoFile.path,
      ));

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      print('Create delivery response status: ${response.statusCode}');
      print('Create delivery response body: ${response.body}');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'delivery': data['delivery']};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to create delivery'};
      }
    } catch (e) {
      print('Error creating delivery: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Save rider location
  static Future<bool> saveRiderLocation(int riderId, double lat, double lng, {int? deliveryId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rider/$riderId/location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': lat,
          'lng': lng,
          'delivery_id': deliveryId,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error saving rider location: $e');
      return false;
    }
  }

  // Get rider location for delivery
  static Future<Map<String, dynamic>?> getRiderLocation(int deliveryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/delivery/$deliveryId/rider-location'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting rider location: $e');
      return null;
    }
  }
}

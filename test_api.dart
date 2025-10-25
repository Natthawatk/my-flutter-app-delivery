import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'https://my-node-app-lvf0.onrender.com/api';

void main() async {
  print('🧪 Testing API endpoints...\n');
  
  // Test 1: Root endpoint
  await testEndpoint('Root', '$baseUrl/../', expectJson: false);
  
  // Test 2: Available jobs
  await testEndpoint('Available Jobs', '$baseUrl/deliveries/available');
  
  // Test 3: Login (should fail without credentials, but endpoint should exist)
  await testEndpoint('Login', '$baseUrl/auth/login', method: 'POST', body: {
    'phone': '0911234567',
    'password': 'wrongpassword'
  });
  
  print('\n✅ API testing completed!');
}

Future<void> testEndpoint(String name, String url, {String method = 'GET', Map<String, dynamic>? body, bool expectJson = true}) async {
  try {
    print('Testing: $name');
    print('URL: $url');
    
    http.Response response;
    
    if (method == 'POST') {
      response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body ?? {}),
      ).timeout(Duration(seconds: 10));
    } else {
      response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
    }
    
    print('Status: ${response.statusCode}');
    
    if (expectJson) {
      try {
        final data = jsonDecode(response.body);
        print('Response: ${jsonEncode(data).substring(0, 100)}${jsonEncode(data).length > 100 ? "..." : ""}');
      } catch (e) {
        print('Response (not JSON): ${response.body.substring(0, 100)}${response.body.length > 100 ? "..." : ""}');
      }
    } else {
      print('Response: ${response.body.substring(0, 100)}${response.body.length > 100 ? "..." : ""}');
    }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('✅ Success\n');
    } else if (response.statusCode == 401 || response.statusCode == 400) {
      print('⚠️  Expected error (endpoint exists)\n');
    } else {
      print('❌ Failed\n');
    }
    
  } catch (e) {
    print('❌ Error: $e\n');
  }
}

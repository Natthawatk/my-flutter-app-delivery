import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SelectLocationMapScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const SelectLocationMapScreen({
    Key? key,
    this.initialLat,
    this.initialLng,
  }) : super(key: key);

  @override
  State<SelectLocationMapScreen> createState() => _SelectLocationMapScreenState();
}

class _SelectLocationMapScreenState extends State<SelectLocationMapScreen> {
  late WebViewController controller;
  bool _isMapLoaded = false;
  double? selectedLat;
  double? selectedLng;
  String selectedAddress = '';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    selectedLat = widget.initialLat ?? 13.7563;
    selectedLng = widget.initialLng ?? 100.5018;
    _initializeWebView();
  }

  void _initializeWebView() {
    final apiKey = dotenv.env['MAP_API_KEY']?.replaceAll("'", "") ?? '647cdc5c6e2b848425fbae73021b3fa8';
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isMapLoaded = true;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'LocationSelected',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            setState(() {
              selectedLat = data['lat'];
              selectedLng = data['lng'];
              selectedAddress = data['address'] ?? '';
            });
            print('📍 Location selected: $selectedLat, $selectedLng');
            print('📍 Address: $selectedAddress');
          } catch (e) {
            print('Error parsing location: $e');
          }
        },
      )
      ..loadHtmlString(
        _generateMapHtml(apiKey),
        baseUrl: 'https://mydelivery.com/',
      );
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final apiKey = dotenv.env['MAP_API_KEY']?.replaceAll("'", "") ?? '647cdc5c6e2b848425fbae73021b3fa8';
      final url = 'https://search.longdo.com/mapsearch/json/search?keyword=$query&limit=5&key=$apiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          setState(() {
            _searchResults = List<Map<String, dynamic>>.from(
              data['data'].map((item) => {
                'name': item['name'] ?? '',
                'address': item['address'] ?? '',
                'lat': item['lat'] ?? 0.0,
                'lon': item['lon'] ?? 0.0,
              })
            );
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      print('Search error: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    setState(() {
      selectedLat = result['lat'];
      selectedLng = result['lon'];
      selectedAddress = result['address'];
      _searchController.clear();
      _searchResults = [];
    });

    // Move map to selected location
    controller.runJavaScript('''
      if (map) {
        map.location({lon: ${result['lon']}, lat: ${result['lat']}});
        map.zoom(16);
      }
    ''');
  }

  String _generateMapHtml(String apiKey) {
    final lat = selectedLat ?? 13.7563;
    final lng = selectedLng ?? 100.5018;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <title>Select Location</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
    }
    #map {
      width: 100%;
      height: 100%;
      position: absolute;
      top: 0;
      left: 0;
    }
    #crosshair {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 40px;
      height: 40px;
      pointer-events: none;
      z-index: 1000;
    }
    #crosshair::before,
    #crosshair::after {
      content: '';
      position: absolute;
      background: #FF0000;
    }
    #crosshair::before {
      width: 2px;
      height: 100%;
      left: 50%;
      transform: translateX(-50%);
    }
    #crosshair::after {
      width: 100%;
      height: 2px;
      top: 50%;
      transform: translateY(-50%);
    }
    #pin {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -100%);
      width: 40px;
      height: 50px;
      pointer-events: none;
      z-index: 1000;
    }
  </style>
  <script type="text/javascript" src="https://api.longdo.com/map/?key=$apiKey"></script>
</head>
<body>
  <div id="map"></div>
  <div id="pin">
    <svg width="40" height="50" viewBox="0 0 40 50" xmlns="http://www.w3.org/2000/svg">
      <path d="M20 0C11.716 0 5 6.716 5 15c0 8.284 15 35 15 35s15-26.716 15-35c0-8.284-6.716-15-15-15z" fill="#FF0000"/>
      <circle cx="20" cy="15" r="6" fill="#FFFFFF"/>
    </svg>
  </div>
  
  <script>
    var map;
    var selectedLocation = {lat: $lat, lon: $lng};
    
    function initMap() {
      if (typeof longdo === 'undefined') {
        setTimeout(initMap, 500);
        return;
      }
      
      try {
        map = new longdo.Map({
          placeholder: document.getElementById('map'),
          language: 'th'
        });
        
        map.location({lon: $lng, lat: $lat});
        map.zoom(15);
        
        // Listen to map move events
        map.Event.bind('overlayDrop', function() {
          updateLocation();
        });
        
        map.Event.bind('drag', function() {
          updateLocation();
        });
        
        map.Event.bind('zoom', function() {
          updateLocation();
        });
        
        console.log('Map initialized successfully');
      } catch (error) {
        console.error('Error initializing map:', error);
        setTimeout(initMap, 1000);
      }
    }
    
    function updateLocation() {
      var center = map.location();
      selectedLocation = {
        lat: center.lat,
        lon: center.lon
      };
      
      // Send location to Flutter immediately
      if (typeof LocationSelected !== 'undefined') {
        LocationSelected.postMessage(JSON.stringify({
          lat: selectedLocation.lat,
          lng: selectedLocation.lon,
          address: ''
        }));
      }
      
      // Try to get address using Longdo Search API
      try {
        var searchUrl = 'https://search.longdo.com/mapsearch/json/search?keyword=' + 
                        selectedLocation.lat + ',' + selectedLocation.lon + 
                        '&limit=1&key=$apiKey';
        
        fetch(searchUrl)
          .then(response => response.json())
          .then(data => {
            var address = '';
            if (data && data.data && data.data.length > 0) {
              var result = data.data[0];
              address = result.address || result.name || '';
            }
            
            // Send updated location with address to Flutter
            if (typeof LocationSelected !== 'undefined') {
              LocationSelected.postMessage(JSON.stringify({
                lat: selectedLocation.lat,
                lng: selectedLocation.lon,
                address: address
              }));
            }
          })
          .catch(error => {
            console.log('Geocoding error:', error);
          });
      } catch (error) {
        console.log('Error fetching address:', error);
      }
    }
    
    // Start initialization
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', initMap);
    } else {
      initMap();
    }
  </script>
</body>
</html>
    ''';
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
          'Select Location',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          // Search bar at top
          if (_isMapLoaded)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ค้นหาสถานที่...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (value) {
                        _searchLocation(value);
                      },
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.red),
                            title: Text(
                              result['name'],
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              result['address'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSearchResult(result),
                          );
                        },
                      ),
                    ),
                  if (_isSearching)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
          if (!_isMapLoaded)
            Container(
              color: Colors.blue[50],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Map...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Info card at bottom
          if (_isMapLoaded)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (selectedAddress.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedAddress,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${selectedLat?.toStringAsFixed(6)}, Lng: ${selectedLng?.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, {
                            'lat': selectedLat,
                            'lng': selectedLng,
                            'address': selectedAddress,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirm Location',
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
        ],
      ),
    );
  }
}

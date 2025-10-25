import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math' as math;

class LongdoMapWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final double zoom;
  final List<MapMarker>? markers;
  final double height;
  final bool showDistance;

  const LongdoMapWidget({
    Key? key,
    this.latitude,
    this.longitude,
    this.zoom = 15,
    this.markers,
    this.height = 200,
    this.showDistance = true,
  }) : super(key: key);

  @override
  State<LongdoMapWidget> createState() => _LongdoMapWidgetState();
}

class _LongdoMapWidgetState extends State<LongdoMapWidget> {
  late WebViewController controller;
  bool _isMapLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void didUpdateWidget(LongdoMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload map when markers change
    if (oldWidget.markers != widget.markers) {
      print('🔄 Markers changed, reloading map...');
      setState(() {
        _isMapLoaded = false;
      });
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    final apiKey = dotenv.env['MAP_API_KEY']?.replaceAll("'", "") ?? '647cdc5c6e2b848425fbae73021b3fa8';
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('🗺️ Map page started loading: $url');
          },
          onPageFinished: (String url) {
            print('✅ Map page finished loading: $url');
            // Enable JavaScript console logging
            controller.runJavaScript('console.log("WebView ready")');
            setState(() {
              _isMapLoaded = true;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ Map loading error: ${error.description}');
            print('Error type: ${error.errorType}');
            print('Error code: ${error.errorCode}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterLog',
        onMessageReceived: (JavaScriptMessage message) {
          print('📱 JS Log: ${message.message}');
        },
      )
      ..loadHtmlString(
        _generateMapHtml(apiKey),
        baseUrl: 'https://mydelivery.com/',
      );
  }

  String _generateMapHtml(String apiKey) {
    final lat = widget.latitude ?? 13.7563;
    final lng = widget.longitude ?? 100.5018;
    
    final markersJs = widget.markers?.map((marker) => '''
      {
        lat: ${marker.latitude},
        lon: ${marker.longitude},
        title: "${marker.title}",
        type: "${marker.type.name}"
      }
    ''').join(',') ?? '';
    
    print('🔧 Generating map HTML with ${widget.markers?.length ?? 0} markers');
    if (widget.markers != null) {
      for (var marker in widget.markers!) {
        print('   Marker: ${marker.type.name} at ${marker.latitude}, ${marker.longitude}');
      }
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <title>Longdo Map</title>
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
  </style>
  <script type="text/javascript" src="https://api.longdo.com/map/?key=$apiKey"></script>
</head>
<body>
  <div id="map"></div>
  
  <script>
    console.log('Starting Longdo Map initialization...');
    console.log('API Key: $apiKey');
    
    var map;
    var markers = [$markersJs];
    var initAttempts = 0;
    var maxAttempts = 10;
    
    function initMap() {
      initAttempts++;
      console.log('Init attempt: ' + initAttempts);
      
      if (typeof longdo === 'undefined') {
        console.log('Longdo not loaded yet...');
        if (initAttempts < maxAttempts) {
          setTimeout(initMap, 500);
        } else {
          console.error('Failed to load Longdo API after ' + maxAttempts + ' attempts');
        }
        return;
      }
      
      try {
        console.log('Creating Longdo Map instance...');
        
        map = new longdo.Map({
          placeholder: document.getElementById('map'),
          language: 'th'
        });
        
        console.log('Map created, setting location...');
        map.location({lon: $lng, lat: $lat});
        map.zoom(${widget.zoom});
        
        console.log('Location set: lat=$lat, lon=$lng, zoom=${widget.zoom}');
        
        // Add markers based on what's provided
        console.log('Total markers to add: ' + markers.length);
        console.log('Markers data:', JSON.stringify(markers));
        
        if (markers.length > 0) {
          console.log('Adding ' + markers.length + ' markers...');
          
          markers.forEach(function(markerData, index) {
            console.log('Processing marker ' + index + ':', JSON.stringify(markerData));
            
            var markerColor = '#4CAF50';
            var markerIcon = '📦';
            var markerTitle = markerData.title;
            var iconSize = '24px';
            
            // Determine marker style based on type
            console.log('Marker type:', markerData.type);
            if (markerData.type === 'rider') {
              markerColor = '#2196F3';
              markerIcon = '🏍️';
              iconSize = '26px';
              console.log('Set as RIDER marker');
            } else if (markerData.type === 'pickup') {
              markerColor = '#4CAF50';
              markerIcon = '📦';
              iconSize = '28px';
              console.log('Set as PICKUP marker');
            } else if (markerData.type === 'destination') {
              markerColor = '#F44336';
              markerIcon = '🎯';
              iconSize = '26px';
              console.log('Set as DESTINATION marker');
            } else {
              console.log('Unknown marker type, using default');
            }
            
            // Create marker with appropriate style
            var marker = new longdo.Marker({
              lon: markerData.lon,
              lat: markerData.lat
            }, {
              title: markerTitle,
              icon: {
                html: '<div style="position: relative; width: 60px; height: 70px;">' +
                      // Pin pointer (bottom triangle)
                      '<div style="position: absolute; bottom: 0; left: 50%; transform: translateX(-50%); width: 0; height: 0; border-left: 10px solid transparent; border-right: 10px solid transparent; border-top: 18px solid ' + markerColor + '; z-index: 1;"></div>' +
                      // Pin circle (rotated teardrop shape)
                      '<div style="position: absolute; bottom: 15px; left: 50%; transform: translateX(-50%) rotate(-45deg); background: ' + markerColor + '; width: 50px; height: 50px; border-radius: 50% 50% 50% 0; border: 4px solid white; box-shadow: 0 4px 10px rgba(0,0,0,0.4); z-index: 2;"></div>' +
                      // Icon (centered, not rotated, with white background for visibility)
                      '<div style="position: absolute; bottom: 28px; left: 50%; transform: translateX(-50%); font-size: ' + iconSize + '; z-index: 999; line-height: 1; text-shadow: 0 0 3px white, 0 0 3px white, 0 0 3px white;">' + markerIcon + '</div>' +
                      '</div>'
              }
            });
            map.Overlays.add(marker);
            
            console.log('Marker ' + (index + 1) + ' added: ' + markerData.type);
          });
          
          // Note: Skip map.bound() as it may cause issues with Longdo API
          // The map is already centered with map.location() and map.zoom()
        }
        
        console.log('Longdo Map initialized successfully!');
        
      } catch (error) {
        console.error('Error initializing map:', error);
        if (initAttempts < maxAttempts) {
          setTimeout(initMap, 1000);
        }
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
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            WebViewWidget(controller: controller),
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
                        'กำลังโหลด Longdo Map...',
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
            // Show distance if enabled
            if (_isMapLoaded && widget.showDistance && widget.markers != null && widget.markers!.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_calculateDistance(
                      widget.latitude ?? 13.7563,
                      widget.longitude ?? 100.5018,
                      widget.markers!.first.latitude,
                      widget.markers!.first.longitude,
                    ).toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLon = (lon2 - lon1) * (math.pi / 180);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) + 
        math.cos(lat1 * (math.pi / 180)) * math.cos(lat2 * (math.pi / 180)) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}



class MapMarker {
  final double latitude;
  final double longitude;
  final String title;
  final String? iconUrl;
  final MarkerType type;

  MapMarker({
    required this.latitude,
    required this.longitude,
    required this.title,
    this.iconUrl,
    this.type = MarkerType.destination,
  });
}

enum MarkerType {
  rider,       // ตำแหน่ง Rider
  pickup,      // จุดรับของ
  destination, // จุดส่งของ
}



import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; 
import 'package:pain_suffering/listview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';  


void main() {
  runApp(LocationFormApp());
}

class LocationFormApp extends StatefulWidget {
  @override
  _LocationFormAppState createState() => _LocationFormAppState();
}

class _LocationFormAppState extends State<LocationFormApp> {
  int _selectedIndex = 0;

  // List of screens to navigate between
  final List<Widget> _screens = [
    LocationFormScreen(latitude: 0.0, longitude: 0.0), // Default values
    Dashboard(),
  ];

  // Method to handle tab selection
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Location Form with Map'),
        ),
        body: _screens[_selectedIndex], // Display selected screen
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: 'Users',
            ),
          ],
        ),
      ),
    );
  }
}

class LocationFormScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  LocationFormScreen({required this.latitude, required this.longitude});
  
  @override
  _LocationFormScreenState createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _pseudoController = TextEditingController();

  GoogleMapController? _mapController;
  Marker? _locationMarker;

  @override
  void initState() {
    super.initState();

    // Initialize the controllers with the received latitude and longitude
    _latitudeController.text = widget.latitude.toString();
    _longitudeController.text = widget.longitude.toString();

    // Set initial marker on map
    _locationMarker = Marker(
      markerId: MarkerId('initialLocation'),
      position: LatLng(widget.latitude, widget.longitude),
      infoWindow: InfoWindow(
        title: 'Location',
      ),
    );
  }

  Future<void> _updateMapLocation() async {
    final String latitudeStr = _latitudeController.text;
    final String longitudeStr = _longitudeController.text;
    final String numero = _numeroController.text;
    final String pseudo = _pseudoController.text;

    if (latitudeStr.isNotEmpty && longitudeStr.isNotEmpty) {
      final double latitude = double.parse(latitudeStr);
      final double longitude = double.parse(longitudeStr);

      final Map<String, dynamic> data = {
        'latitude': latitude,
        'longitude': longitude,
        'numero': numero,
        'pseudo': pseudo,
      };

      final response = await http.post(
        Uri.parse("http://192.168.1.29/servicephp/insert.php"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        String msg = response.body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}')),
        );
      }

      // Update marker and map camera position
      setState(() {
        _locationMarker = Marker(
          markerId: MarkerId('locationMarker'),
          position: LatLng(latitude, longitude),
          infoWindow: InfoWindow(
            title: _pseudoController.text,
            snippet: "Numero: $numero",
          ),
        );
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(latitude, longitude)),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both latitude and longitude')),
      );
    }
  }

  Future<void> _checkLocationPermission() async {
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      // Permission granted, you can now access the location
      _getCurrentLocation();
    } else if (status.isDenied) {
      // Permission denied, show a message or prompt the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission is denied')),
      );
    } else if (status.isPermanentlyDenied) {
      // If the permission is permanently denied, guide the user to settings
      openAppSettings();  // Opens the app settings to allow the user to manually enable the permission
    }
  }




  
Timer? _locationTimer;
 Future<void> _getCurrentLocation() async {
  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _latitudeController.text = position.latitude.toString();
      _longitudeController.text = position.longitude.toString();
      _updateMapLocation(); 
    });

    _locationTimer?.cancel();

    _locationTimer = Timer.periodic(Duration(minutes: 10), (timer) {
      _getCurrentLocation();  
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to get location: $e')),
    );
  }
}





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _latitudeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Latitude'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter latitude';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _longitudeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Longitude'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter longitude';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _numeroController,
                    decoration: InputDecoration(labelText: 'Numero'),
                  ),
                  TextFormField(
                    controller: _pseudoController,
                    decoration: InputDecoration(labelText: 'Pseudo'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _updateMapLocation,
                    child: Text('Show Location on Map'),
                  ),
                  ElevatedButton(
                    onPressed: _getCurrentLocation,
                    child: Text('Get Current Location'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.latitude, widget.longitude),
                zoom: 14,
              ),
              markers: _locationMarker != null ? {_locationMarker!} : {},
              onTap: (LatLng position) {
                // Update the form with the tapped coordinates
                setState(() {
                  _latitudeController.text = position.latitude.toString();
                  _longitudeController.text = position.longitude.toString();
                  // Update marker and map camera position
                  _locationMarker = Marker(
                    markerId: MarkerId('tappedLocation'),
                    position: position,
                    infoWindow: InfoWindow(
                      title: 'Tapped Location',
                    ),
                  );
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(position),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

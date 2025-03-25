import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'dart:math' as math;

class LocationTrackerScreen extends StatefulWidget {
  const LocationTrackerScreen({super.key});

  @override
  _LocationTrackerScreenState createState() => _LocationTrackerScreenState();
}

class _LocationTrackerScreenState extends State<LocationTrackerScreen> {
  final Location _location = Location();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  double? _currentLatitude;
  double? _currentLongitude;
  double _doctorLatitude = 30.2972793;
  double _doctorLongitude = 31.7338918;
  String _result = '';

  Future<LocationData?> _getCurrentLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return null;
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted) return null;
    }

    return await _location.getLocation();
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  Future<void> _checkAttendance() async {
    final locationData = await _getCurrentLocation();
    if (locationData != null) {
      final distance = _calculateDistance(
        locationData.latitude!,
        locationData.longitude!,
        _doctorLatitude,
        _doctorLongitude,
      );

      setState(() {
        _currentLatitude = locationData.latitude;
        _currentLongitude = locationData.longitude;
        _result = distance <= 0.015
            ? 'You are within the attendance range.'
            : 'You are too far from the doctor\'s location.';
      });
    } else {
      setState(() {
        _result = 'Failed to get current location.';
      });
    }
  }

  void _copyCoordinate(String label, double? value) {
    if (value != null) {
      Clipboard.setData(ClipboardData(text: value.toString()));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard!'),
          backgroundColor: Colors.indigo,
        ),
      );
    }
  }

  void _updateDoctorLocation() {
    setState(() {
      double? newLatitude = double.tryParse(_latitudeController.text);
      double? newLongitude = double.tryParse(_longitudeController.text);

      if (newLatitude != null && newLongitude != null) {
        _doctorLatitude = newLatitude;
        _doctorLongitude = newLongitude;
        _result = 'Doctor\'s location updated successfully!';
      } else {
        _result = '❌ Please enter valid coordinates.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on),
            SizedBox(width: 8),
            Text('GPS Location Tracker 📍'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.withOpacity(0.1), Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              _buildLocationCard(
                title: 'Your Current Location',
                latitude: _currentLatitude ?? 0.0,
                longitude: _currentLongitude ?? 0.0,
                onRefresh: _getCurrentLocation,
                onCopyLatitude: () =>
                    _copyCoordinate("Latitude", _currentLatitude),
                onCopyLongitude: () =>
                    _copyCoordinate("Longitude", _currentLongitude),
              ),
              const SizedBox(height: 16),
              _buildLocationCard(
                title: 'Doctor\'s Location',
                latitude: _doctorLatitude,
                longitude: _doctorLongitude,
                onRefresh: _updateDoctorLocation,
                onCopyLatitude: () =>
                    _copyCoordinate("Doctor's Latitude", _doctorLatitude),
                onCopyLongitude: () =>
                    _copyCoordinate("Doctor's Longitude", _doctorLongitude),
              ),
              const SizedBox(height: 16),
              _buildCustomTextField(
                controller: _latitudeController,
                labelText: 'Doctor\'s Latitude',
              ),
              const SizedBox(height: 12),
              _buildCustomTextField(
                controller: _longitudeController,
                labelText: 'Doctor\'s Longitude',
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _checkAttendance,
                icon: const Icon(Icons.calculate, color: Colors.white),
                label: const Text(
                  'Check Attendance',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Text(_result),
              const SizedBox(height: 24),
              Container(
                  // Add your additional widgets here
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required double latitude,
    required double longitude,
    required VoidCallback onRefresh,
    required VoidCallback onCopyLatitude,
    required VoidCallback onCopyLongitude,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Latitude: $latitude'),
            Text('Longitude: $longitude'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: onRefresh,
                  child: const Text('Refresh'),
                ),
                ElevatedButton(
                  onPressed: onCopyLatitude,
                  child: const Text('Copy Latitude'),
                ),
                ElevatedButton(
                  onPressed: onCopyLongitude,
                  child: const Text('Copy Longitude'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String labelText,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
    );
  }
}

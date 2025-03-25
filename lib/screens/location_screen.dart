import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class LocationScreen extends StatefulWidget {
  final Map<String, dynamic> courseData;
  final Map<String, dynamic> studentData;

  const LocationScreen({
    Key? key,
    required this.courseData,
    required this.studentData,
  }) : super(key: key);

  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _locationController = TextEditingController();
  bool _isVerifying = false;

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled.'),
        ),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are denied'),
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.'),
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    _locationController.text =
        'Lat: ${position.latitude}, Long: ${position.longitude}';
  }

  Future<void> _verifyLocation() async {
    setState(() => _isVerifying = true);

    try {
      final position = await Geolocator.getCurrentPosition();

      // Send raw coordinates, not formatted string
      final requestBody = {
        'student_id': widget.studentData['id'],
        'course_id': widget.courseData['id'],
        'latitude': position.latitude,
        'longitude': position.longitude
      };

      print('Sending location data: $requestBody'); // For debugging

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/attendance/verify-location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final result = jsonDecode(response.body);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Success! Distance: ${result['distance'].toStringAsFixed(1)}m'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Location'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Your Location',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isVerifying
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Verify Location',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

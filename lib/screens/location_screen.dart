import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/theming/colors.dart';
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
  Position? _currentPosition;
  bool _isVerifying = false;
  bool _isLoading = true;
  double? _distance;
  bool _isLocationVerified = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      await _determinePosition();
      _calculateDistance();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateDistance() {
    if (_currentPosition == null) {
      print('Current position is null');
      return;
    }

    try {
      // Print all course data for debugging
      print('Full Course Data: ${widget.courseData}');

      // Get course location data
      final location = widget.courseData['location'];
      print('Course Location String: $location');

      if (location == null || location.toString().isEmpty) {
        print('Course location is not set');
        throw Exception('Course location is not set. Please contact your instructor.');
      }

      // Parse location string (expected format: "latitude,longitude")
      final List<String> parts = location.toString().split(',');
      if (parts.length != 2) {
        print('Invalid location format: $location');
        throw Exception('Invalid course location format');
      }

      // Parse latitude and longitude
      final double? courseLat = double.tryParse(parts[0].trim());
      final double? courseLong = double.tryParse(parts[1].trim());

      if (courseLat == null || courseLong == null) {
        print('Failed to parse coordinates: lat=$courseLat, long=$courseLong');
        throw Exception('Invalid course coordinates');
      }

      // Log coordinates for comparison
      print('Course coordinates: lat=$courseLat, long=$courseLong');
      print('Student coordinates: lat=${_currentPosition!.latitude}, long=${_currentPosition!.longitude}');

      // Calculate distance
      _distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        courseLat,
        courseLong,
      );

      print('Calculated distance: $_distance meters');

      setState(() {});
    } catch (e) {
      print('Error calculating distance: $e');
      setState(() {
        _distance = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception('Location permissions are required');
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // Increased timeout
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _calculateDistance(); // Recalculate distance after getting position
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _verifyLocation() async {
    if (!mounted) return;
    
    setState(() => _isVerifying = true);

    try {
      if (_currentPosition == null) {
        throw Exception('Cannot get your current location');
      }

      if (_distance == null) {
        throw Exception('Unable to calculate distance to lecture location');
      }

      // Check if within allowed distance (25 meters)
      if (_distance! > 25) {
        throw Exception('You are ${_distance!.toStringAsFixed(1)} meters away from the lecture location. Must be within 25 meters.');
      }

      // Get fresh position for verification
      final freshPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final requestBody = {
        'student_id': widget.studentData['id'].toString(),
        'course_id': widget.courseData['id'].toString(),
        'latitude': freshPosition.latitude.toString(),
        'longitude': freshPosition.longitude.toString(),
      };

      print('Sending verification request: $requestBody');

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/attendance/verify-location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('Server response: ${response.body}');

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Server error: ${response.statusCode}');
      }

      final result = jsonDecode(response.body);

      if (result['success'] == true) {
        setState(() => _isLocationVerified = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Location verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(result['message'] ?? 'Location verification failed');
      }
    } catch (e) {
      print('Verification error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: BackButton(color: Colors.white),
        title: const Text('Verify Location', style: TextStyle(color: Colors.white)),
        backgroundColor: ColorsManager.darkBlueColor1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Student: ${widget.studentData['name']}',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: ColorsManager.darkBlueColor1,
                    ),
                  ),
                  SizedBox(height: 30.h),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: ColorsManager.darkBlueColor1,
                              size: 24.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Your Location',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        if (_currentPosition != null) ...[
                          Text(
                            'Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                            style: TextStyle(fontSize: 16.sp),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(fontSize: 16.sp),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  if (_distance != null)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: _distance! <= 25 ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _distance! <= 25 ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Text(
                        'Distance to course: ${_distance!.toStringAsFixed(1)}m',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: _distance! <= 25 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  SizedBox(height: 32.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorsManager.darkBlueColor1,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isVerifying
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Verify Location',
                              style: TextStyle(fontSize: 16.sp, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

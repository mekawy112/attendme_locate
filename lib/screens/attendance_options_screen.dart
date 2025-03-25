import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'face_rec_screen/RecognitionScreen.dart';
// import 'location_screen.dart'; // Import the new LocationScreen
import 'dart:convert';
import 'package:http/http.dart' as http;

class AttendanceOptionsScreen extends StatelessWidget {
  final Map<String, dynamic> courseData;
  final Map<String, dynamic> studentData; // Add this parameter

  const AttendanceOptionsScreen(
      {Key? key, required this.courseData, required this.studentData})
      : super(key: key);

  Future<void> _navigateToLocationScreen(BuildContext context) async {
    final location = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationScreen(
          courseData:
              courseData, // This comes from the AttendanceOptionsScreen constructor
          studentData:
              studentData, // You need to add this parameter to AttendanceOptionsScreen
        ),
      ),
    );

    if (location != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location saved: $location'),
        ),
      );
    }
  }

  Future<void> _verifyAttendance(BuildContext context) async {
    try {
      // Call API to verify GPS and face recognition
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/attendance/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentData['id'],
          'course_id': courseData['id'],
        }),
      );

      final result = jsonDecode(response.body);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Send attendance data to the doctor
        final doctorResponse = await http.post(
          Uri.parse('${ApiService.baseUrl}/attendance/send-to-doctor'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'course_id': courseData['id'],
          }),
        );

        if (doctorResponse.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance sent to the doctor.'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
          content: Text('Error verifying attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Options'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => RecognitionScreen(
                                studentId: studentData['id'].toString(),
                                studentData: studentData,
                              )),
                    );
                  },
                  child: const Text('Face Recognition'),
                ),
                const Icon(Icons.check_circle, color: Colors.green), // Check icon
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _navigateToLocationScreen(context),
                  child: const Text('GPS'),
                ),
                const Icon(Icons.check_circle, color: Colors.green), // Check icon
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Confirm attendance and send data to the doctor
                final response = await http.post(
                  Uri.parse('${ApiService.baseUrl}/attendance/confirm'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'student_id': studentData['id'],
                    'student_name': studentData['name'],
                    'course_id': courseData['id'],
                  }),
                );

                final result = jsonDecode(response.body);

                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Attendance confirmed and sent to the doctor.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message']),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Confirm Attendance'),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationScreen extends StatefulWidget {
  final Map<String, dynamic> courseData; // Add this parameter
  final Map<String, dynamic> studentData; // Add this parameter

  const LocationScreen(
      {Key? key, required this.courseData, required this.studentData})
      : super(key: key);

  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final TextEditingController _locationController = TextEditingController();
  bool _isVerifying = false;

  Future<void> _verifyLocation() async {
    setState(() => _isVerifying = true);

    try {
      final position = await Geolocator.getCurrentPosition();

      // Send raw latitude and longitude values, not formatted string
      final requestBody = {
        'student_id': widget.studentData['id'],
        'course_id': widget.courseData['id'],
        'latitude': position.latitude, // Send as numeric value
        'longitude': position.longitude // Send as numeric value
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

  // Update _determinePosition to show clean coordinates
  Future<void> _determinePosition() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _locationController.text =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          children: [
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Your Location'),
              readOnly: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _determinePosition,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('Get Current Location'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isVerifying ? null : _verifyLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 45),
              ),
              child: _isVerifying
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Verify Distance with Doctor Location'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:attend_me_locate/core/theming/colors.dart';
import 'package:attend_me_locate/core/theming/font_weight_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import '../services/course_service.dart';
import 'attendance_days_screen.dart';
import 'attendance_details_screen.dart';
import './attendance_summary_screen.dart';
import 'course_detail_screen.dart';
import 'doctor_settings_screen.dart';

class DoctorDashboard extends StatefulWidget {
  final Map<String, dynamic> doctorData;

  const DoctorDashboard({Key? key, required this.doctorData}) : super(key: key);

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final _courseNameController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _courseDescriptionController = TextEditingController();
  final _courseDayController = TextEditingController();
  final _courseTimeController = TextEditingController();
  final _courseLocationController =
      TextEditingController(); // New controller for location

  List<Map<String, dynamic>> courses = [];
  bool _isLoading = false;
  bool _isAttendanceOpen = false; // New variable for attendance state

  final CourseService _courseService = CourseService();

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    _courseCodeController.dispose();
    _courseDescriptionController.dispose();
    _courseDayController.dispose();
    _courseTimeController.dispose();
    _courseLocationController.dispose(); // Dispose the new controller
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await _courseService.getDoctorCourses(
        widget.doctorData['id'],
      );
      if (response['success']) {
        setState(() {
          courses = List<Map<String, dynamic>>.from(response['courses']);
        });
      } else {
        _showSnackBar(response['message'], Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error loading courses: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addCourse() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Course'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: _courseNameController,
                    decoration: const InputDecoration(labelText: 'Course Name'),
                  ),
                  TextField(
                    controller: _courseCodeController,
                    decoration: const InputDecoration(labelText: 'Course Code'),
                  ),
                  TextField(
                    controller: _courseDayController,
                    decoration: const InputDecoration(labelText: 'Course Day'),
                  ),
                  TextField(
                    controller: _courseTimeController,
                    decoration: const InputDecoration(labelText: 'Course Time'),
                  ),
                  TextField(
                    controller: _courseDescriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes',
                    ),
                  ),
                  TextField(
                    controller:
                        _courseLocationController, // Use the new controller
                    decoration: const InputDecoration(
                      labelText: 'Add Location',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        ColorsManager.darkBlueColor1,
                      ),
                    ),
                    onPressed: _determinePosition,
                    child: const Text(
                      'Get Current Location',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: ColorsManager.darkBlueColor1,
                    fontSize: 18,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (_courseNameController.text.isEmpty ||
                      _courseCodeController.text.isEmpty ||
                      _courseDayController.text.isEmpty ||
                      _courseTimeController.text.isEmpty) {
                    _showSnackBar(
                      'Please fill all required fields',
                      Colors.red,
                    );
                    return;
                  }

                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    final response = await _courseService.addCourse(
                      code: _courseCodeController.text,
                      name: _courseNameController.text,
                      day: _courseDayController.text,
                      time: _courseTimeController.text,
                      description: _courseDescriptionController.text,
                      location:
                          _courseLocationController.text, // Include location
                      doctorId: widget.doctorData['id'],
                    );

                    if (response['success']) {
                      _courseNameController.clear();
                      _courseCodeController.clear();
                      _courseDayController.clear();
                      _courseTimeController.clear();
                      _courseDescriptionController.clear();
                      _courseLocationController
                          .clear(); // Clear the location field
                      Navigator.pop(context);
                      _showSnackBar(
                        'Course added successfully. Enrollment code: ${response['course']['enrollment_code']}',
                        Colors.green,
                      );
                      _loadCourses();
                    } else {
                      _showSnackBar(response['message'], Colors.red);
                    }
                  } catch (e) {
                    _showSnackBar('Error adding course: $e', Colors.red);
                  } finally {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                child: const Text(
                  'Add',
                  style: TextStyle(
                    color: ColorsManager.darkBlueColor1,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _determinePosition() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        // Store location in correct format
        _courseLocationController.text =
            '${position.latitude},${position.longitude}';
      });
    } catch (e) {
      _showSnackBar('Error getting location: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _toggleAttendance(bool value) {
    setState(() {
      _isAttendanceOpen = value;
    });
    _showSnackBar(
      _isAttendanceOpen
          ? 'Attendance registration is now open.'
          : 'Attendance registration is now closed.',
      Colors.green,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Doctor Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: ColorsManager.darkBlueColor1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadCourses,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          DoctorSettingsScreen(userData: widget.doctorData),
                ),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : courses.isEmpty
              ? const Center(child: Text('No courses available'))
              : ListView.builder(
                itemCount: courses.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return GestureDetector(
                    onTap: () {
                      if (course['isAttendanceOpen']) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => CourseDetailScreen(
                                  course: course,
                                  studentData: widget.doctorData,
                                ),
                          ),
                        );
                      } else {
                        _showSnackBar(
                          'Attendance registration is currently closed for this course. Please wait for the lecture time.',
                          Colors.red,
                        );
                      }
                    },
                    child: Card(
                      color: ColorsManager.blueColor,
                      margin: const EdgeInsets.only(
                        bottom: 10,
                      ), // Reduced margin
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12), // Reduced padding
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course['name'] ?? 'Unknown Name',
                              style: const TextStyle(
                                fontSize: 20, // Reduced font size
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4), // Reduced space
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Day: ${course['day'] ?? 'N/A'}",
                                        style: TextStyle(
                                          fontSize: 14, // Reduced font size
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        "Time: ${course['time'] ?? 'N/A'}",
                                        style: TextStyle(
                                          fontSize: 14, // Reduced font size
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Code: ${course['enrollment_code'] ?? 'N/A'}",
                                        style: TextStyle(
                                          fontSize: 14, // Reduced font size
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        "Students: ${course['students'] ?? 0}",
                                        style: TextStyle(
                                          fontSize: 14, // Reduced font size
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "Location: ${course['location'] ?? 'N/A'}",
                              style: TextStyle(
                                fontSize: 14, // Reduced font size
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4), // Reduce spacing
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => AttendanceDaysScreen(
                                                courseId: course['id'],
                                                courseName:
                                                    course['name'] ??
                                                    'Unknown Course',
                                              ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'View Attendance',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  AttendanceSummaryScreen(
                                                    courseId: course['id'],
                                                    courseName:
                                                        course['name'] ??
                                                        'Unknown Course',
                                                  ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Attendance Summary',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8), // Reduced space
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Attendance Registration',
                                  style: TextStyle(
                                    fontSize: 14, // Reduced font size
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Switch(
                                  value: course['isAttendanceOpen'] ?? false,
                                  onChanged: (value) async {
                                    try {
                                      final response = await _courseService
                                          .updateAttendanceState(
                                            course['id'],
                                            value,
                                          );

                                      if (response['success']) {
                                        setState(() {
                                          course['isAttendanceOpen'] = value;
                                        });
                                        _showSnackBar(
                                          value
                                              ? 'Attendance registration is now open for ${course['name']}.'
                                              : 'Attendance registration is now closed for ${course['name']}.',
                                          Colors.green,
                                        );
                                      } else {
                                        _showSnackBar(
                                          'Failed to update attendance state: ${response['message']}',
                                          Colors.red,
                                        );
                                      }
                                    } catch (e) {
                                      _showSnackBar(
                                        'Error updating attendance state: $e',
                                        Colors.red,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCourse,
        backgroundColor: ColorsManager.darkBlueColor1,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

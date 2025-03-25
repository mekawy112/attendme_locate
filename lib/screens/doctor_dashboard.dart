import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/course_service.dart';
import 'attendance_details_screen.dart';
import 'course_detail_screen.dart'; // Import the CourseDetailScreen

class DoctorDashboard extends StatefulWidget {
  final Map<String, dynamic> doctorData;

  const DoctorDashboard({
    Key? key,
    required this.doctorData,
  }) : super(key: key);

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
      final response =
          await _courseService.getDoctorCourses(widget.doctorData['id']);
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
      builder: (context) => AlertDialog(
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
                decoration:
                    const InputDecoration(labelText: 'Additional Notes'),
              ),
              TextField(
                controller: _courseLocationController, // Use the new controller
                decoration: const InputDecoration(labelText: 'Add Location'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _determinePosition,
                child: const Text('Get Current Location'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_courseNameController.text.isEmpty ||
                  _courseCodeController.text.isEmpty ||
                  _courseDayController.text.isEmpty ||
                  _courseTimeController.text.isEmpty) {
                _showSnackBar('Please fill all required fields', Colors.red);
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
                  location: _courseLocationController.text, // Include location
                  doctorId: widget.doctorData['id'],
                );

                if (response['success']) {
                  _courseNameController.clear();
                  _courseCodeController.clear();
                  _courseDayController.clear();
                  _courseTimeController.clear();
                  _courseDescriptionController.clear();
                  _courseLocationController.clear(); // Clear the location field
                  Navigator.pop(context);
                  _showSnackBar(
                      'Course added successfully. Enrollment code: ${response['course']['enrollment_code']}',
                      Colors.green);
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
            child: const Text('Add'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _toggleAttendance(bool value) {
    setState(() {
      _isAttendanceOpen = value;
    });
    _showSnackBar(
        _isAttendanceOpen
            ? 'Attendance registration is now open.'
            : 'Attendance registration is now closed.',
        Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourses,
          ),
        ],
      ),
      body: _isLoading
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
                              builder: (context) => CourseDetailScreen(
                                course: course,
                                studentData: widget.doctorData,
                              ),
                            ),
                          );
                        } else {
                          _showSnackBar(
                              'Attendance registration is currently closed for this course. Please wait for the lecture time.',
                              Colors.red);
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(course['name'] ?? 'Unknown Name',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              Text("Day: ${course['day'] ?? 'N/A'}"),
                              Text("Time: ${course['time'] ?? 'N/A'}"),
                              Text("Code: ${course['enrollment_code'] ?? 'N/A'}"),
                              Text("${course['students'] ?? 0} students"),
                              Text("Location: ${course['location'] ?? 'N/A'}"),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Attendance Registration'),
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
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AttendanceDetailsScreen(courseId: course['id']),
                                        ),
                                      );
                                    },
                                    child: const Text('View Attendance'),
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
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

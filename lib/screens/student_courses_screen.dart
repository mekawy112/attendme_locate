import 'package:flutter/material.dart';


import '../core/theming/colors.dart';
import '../services/course_service.dart';
import 'attendance_options_screen.dart' as attendanceOptions;
import 'course_detail_screen.dart';


class StudentCoursesScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const StudentCoursesScreen({
    Key? key,
    required this.studentData,
  }) : super(key: key);

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  final _courseCodeController = TextEditingController();
  final _courseService = CourseService();

  List<Map<String, dynamic>> courses = [];
  bool _isLoading = true;
  bool _isEnrolling = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Make sure we're handling the student ID properly
      final studentId = widget.studentData['id'];
      print(
          'Loading courses for student ID: $studentId (type: ${studentId.runtimeType})');

      final response = await _courseService.getStudentCourses(studentId);

      if (response['success']) {
        setState(() {
          courses = List<Map<String, dynamic>>.from(response['courses']);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error in _loadCourses: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading courses: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _enrollInCourse() async {
    if (_courseCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an enrollment code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isEnrolling = true;
    });

    try {
      // Convert student ID to string if it's an integer
      final studentId = widget.studentData['id'];

      final response = await _courseService.enrollInCourse(
        studentId: studentId, // Pass as is, let the service handle conversion
        enrollmentCode: _courseCodeController.text.trim(),
      );

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
            backgroundColor: Colors.green,
          ),
        );
        _courseCodeController.clear();
        _loadCourses(); // Refresh the course list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enrolling in course: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isEnrolling = false;
      });
    }
  }

  Future<void> _unenrollFromCourse(int courseId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _courseService.unenrollFromCourse(
        studentId: widget.studentData['id'],
        courseId: courseId,
      );

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully unenrolled from course'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCourses(); // Refresh the course list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error unenrolling from course: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
        backgroundColor: ColorsManager.darkBlueColor1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Course enrollment section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enroll in a New Course',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FloatingActionButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Enroll in Course'),
                                  content: TextField(
                                    controller: _courseCodeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Enter Enrollment Code',
                                      border: OutlineInputBorder(),
                                      hintText: 'e.g. ABC123',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: _isEnrolling
                                          ? null
                                          : () {
                                              Navigator.pop(context);
                                              _enrollInCourse();
                                            },
                                      child: _isEnrolling
                                          ? const CircularProgressIndicator()
                                          : const Text('Enroll'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isEnrolling ? null : _enrollInCourse,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorsManager.darkBlueColor1,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _isEnrolling
                                  ? const CircularProgressIndicator(
                                      color: ColorsManager.whiteColor)
                                  : const Text(
                                      'Enroll',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Courses list
                Expanded(
                  child: courses.isEmpty
                      ? const Center(
                          child: Text(
                            'You are not enrolled in any courses yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: ColorsManager.greyColor,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: courses.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final course = courses[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CourseDetailScreen(
                                      course: course,
                                      studentData: widget.studentData,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            course['code'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: ColorsManager.greyColor,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: ColorsManager.lightBrown),
                                            onPressed: () =>
                                                _unenrollFromCourse(
                                                    course['id']),
                                            tooltip: 'Unenroll from course',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        course['name'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        course['description'] ??
                                            'No description available',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: ColorsManager.darkGrayColor,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          if (course['isAttendanceOpen'] ==
                                              true) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    attendanceOptions
                                                        .AttendanceOptionsScreen(
                                                  courseData: course,
                                                  studentData:
                                                      widget.studentData,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Attendance is not open for this course'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: ColorsManager.darkBlueColor1,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 12),
                                        ),
                                        child: const Text(
                                          'Take Attendance',
                                          style: TextStyle(
                                            color: ColorsManager.whiteColor,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

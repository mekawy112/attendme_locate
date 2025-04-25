import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart';
import '../services/course_service.dart';
import 'attendance_options_screen.dart';
import 'course_detail_screen.dart';
import 'attendance_notifications_screen.dart';
import 'student_attendance_screen.dart';
import '../core/theming/colors.dart';
import '../widgets/application_app_bar.dart';
import '../widgets/course_loading_widget.dart';
import '../widgets/welcome_text.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'face_rec_screen/DB/DatabaseHelper.dart';
import 'face_rec_screen/RegistrationScreen.dart';
import 'settings_screen.dart'; // Import SettingsScreen

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _courses = [];
  bool _isLoading = true;
  final TextEditingController _courseCodeController = TextEditingController();
  List<Map<String, dynamic>> _attendanceNotifications = [];
  Map<String, List<Map<String, dynamic>>> _groupedNotifications = {};

  // Bottom navigation bar state
  int _selectedIndex = 0;

  bool isFaceVerified = false;
  bool isLocationVerified = false;

  // Handle tapping on bottom navigation bar items
  void _onItemTapped(int index) {
    if (index == _selectedIndex)
      return; // Don't navigate if already on the selected tab

    if (index == 0) {
      // Already on Home tab
      setState(() {
        _selectedIndex = 0;
      });
    } else if (index == 1) {
      // Navigate to Attendances tab
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => StudentAttendanceScreen(userData: widget.userData),
        ),
      );
    } else if (index == 2) {
      // Navigate to Settings tab
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettingsScreen(userData: widget.userData),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    print("Home Screen init state called");
    _fetchCourses();
    _createHardcodedNotifications();

    // Force sample notifications to appear for testing
    Future.delayed(Duration(milliseconds: 500), () {
      if (_groupedNotifications.isEmpty) {
        print("No notifications displayed, trying again");
        _createHardcodedNotifications();
      }
    });
  }

  Future<void> _fetchCourses() async {
    try {
      final courses = await CourseService().getStudentCourses(
        widget.userData['id'],
      );
      setState(() {
        _courses = courses['courses'];
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching courses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _enrollInCourse() async {
    final courseCode = _courseCodeController.text;
    if (courseCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a course code'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
          margin: EdgeInsets.only(bottom: 100, left: 20, right: 20),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CourseService().enrollInCourse(
        studentId: widget.userData['id'],
        enrollmentCode: courseCode,
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enrolled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchCourses(); // Refresh the courses list
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
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkIfFaceRegistered(String studentId) async {
    try {
      final dbHelper = DatabaseHelper(); // تأكد من استيراد DatabaseHelper
      final allFaces = await dbHelper.queryAllRows();
      return allFaces.any((row) => row['studentId'] == studentId);
    } catch (e) {
      print('Error checking face registration: $e');
      return false;
    }
  }

  Future<void> _checkFaceRegistration(BuildContext context) async {
    try {
      // API call to check if the face is already registered
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/face/check-registration/${widget.userData['id']}',
        ),
      );

      final result = jsonDecode(response.body);

      if (result['isRegistered']) {
        // Show message if face is already registered
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your face is already registered.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Navigate to face registration screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => RegistrationScreen(studentData: widget.userData),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking face registration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _createHardcodedNotifications() {
    // Today's date
    DateTime today = DateTime.now();
    String todayStr = DateFormat('yyyy-MM-dd').format(today);

    // Yesterday's date
    DateTime yesterday = today.subtract(Duration(days: 1));
    String yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    // Create notification objects
    List<Map<String, dynamic>> notifications = [
      {
        'student_id': widget.userData['id'].toString(),
        'course_id': '101',
        'course_name': 'Introduction to Computer Science',
        'timestamp': today.subtract(Duration(hours: 2)).toIso8601String(),
        'date': todayStr,
        'already_recorded': false,
      },
      {
        'student_id': widget.userData['id'].toString(),
        'course_id': '102',
        'course_name': 'Data Structures',
        'timestamp': today.subtract(Duration(hours: 4)).toIso8601String(),
        'date': todayStr,
        'already_recorded': true,
      },
      {
        'student_id': widget.userData['id'].toString(),
        'course_id': '103',
        'course_name': 'Database Systems',
        'timestamp': yesterday.subtract(Duration(hours: 3)).toIso8601String(),
        'date': yesterdayStr,
        'already_recorded': false,
      },
    ];

    // Group notifications by date
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var notification in notifications) {
      String date = notification['date'];
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(notification);
    }

    setState(() {
      _attendanceNotifications = notifications;
      _groupedNotifications = grouped;
    });

    print(
      "Created hardcoded notifications - ${notifications.length} items in ${grouped.length} groups",
    );
  }

  @override
  Widget build(BuildContext context) {
    print(
      "Building HomeScreen. Notifications: ${_attendanceNotifications.length}, Grouped: ${_groupedNotifications.length}",
    );
    return Scaffold(
      appBar: buildApplicationAppBar(title: 'Home'),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WelcomeText(userData: widget.userData),
            SizedBox(height: 10.sp),

            // Existing Courses Section
            _isLoading
                ? CoursesLoadingWidget()
                : Expanded(
                  child: GridView.builder(
                    itemCount: _courses.length,
                    padding: EdgeInsets.symmetric(horizontal: 15.w),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                    itemBuilder: (context, i) {
                      final course = _courses[i];
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => CourseDetailScreen(
                                    course: course,
                                    studentData:
                                        widget
                                            .userData, // Pass user data as student data
                                  ),
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 15.w,
                            vertical: 20.h,
                          ),
                          decoration: BoxDecoration(
                            color: ColorsManager.blueColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 2,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course['name'],
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  color: ColorsManager.darkBlueColor1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                course['code'],
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: ColorsManager.darkBlueColor1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        unselectedFontSize: 16,
        selectedFontSize: 18,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home,
              color: ColorsManager.darkBlueColor1,
              size: 32.sp,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.calendar_month_sharp,
              color: ColorsManager.darkBlueColor1,
              size: 32.sp,
            ),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings,
              color: ColorsManager.darkBlueColor1,
              size: 32.sp,
            ),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "faceReg",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => RegistrationScreen(
                        studentId: widget.userData['id'].toString(),
                        studentData: widget.userData,
                      ),
                ),
              );
            },
            backgroundColor: ColorsManager.blueColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.sp),
            ),
            child: Icon(
              Icons.face,
              color: ColorsManager.darkBlueColor1,
              size: 35,
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "addCourse",
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text('Add Course'),
                      content: TextField(
                        controller: _courseCodeController,
                        decoration: InputDecoration(
                          labelText: 'Enter course code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _enrollInCourse();
                            Navigator.of(context).pop();
                          },
                          child: Text('Add'),
                        ),
                      ],
                    ),
              );
            },
            backgroundColor: ColorsManager.blueColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.sp),
            ),
            child: Icon(
              Icons.add,
              color: ColorsManager.darkBlueColor1,
              size: 35,
            ),
          ),
        ],
      ),
    );
  }
}

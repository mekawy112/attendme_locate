import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart';
import '../services/course_service.dart';
import 'attendance_options_screen.dart';
import 'course_detail_screen.dart';
import '../core/theming/colors.dart';
import '../widgets/application_app_bar.dart';
import '../widgets/course_loading_widget.dart';
import '../widgets/welcome_text.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'face_rec_screen/DB/DatabaseHelper.dart';
import 'face_rec_screen/RegistrationScreen.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    try {
      final courses =
      await CourseService().getStudentCourses(widget.userData['id']);
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
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
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
            '${ApiService.baseUrl}/face/check-registration/${widget.userData['id']}'),
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
            builder: (context) =>
                RegistrationScreen(studentData: widget.userData),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildApplicationAppBar(title: 'Home'),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WelcomeText(),
            SizedBox(
              height: 10.sp,
            ),
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
                          builder: (context) => CourseDetailScreen(
                            course: course,
                            studentData: widget
                                .userData, // Pass user data as student data
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 15.w, vertical: 20.h),
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
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            course['code'],
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.white60,
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
              icon: Icon(Icons.calendar_month_sharp,
                  color: ColorsManager.darkBlueColor1, size: 32.sp),
              label: 'Attendaces'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings,
                color: ColorsManager.darkBlueColor1, size: 32.sp),
            label: 'Settings',
          )
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
                  builder: (context) => RegistrationScreen(
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
                builder: (context) => AlertDialog(
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
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "verifyAttendance",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceOptionsScreen(
                    studentData: widget.userData,
                    courseData: {}, // Pass course data here
                  ),
                ),
              );
            },
            backgroundColor: ColorsManager.blueColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.sp),
            ),
            child: Icon(
              Icons.check,
              color: ColorsManager.darkBlueColor1,
              size: 35,
            ),
          ),
        ],
      ),
    );
  }
}

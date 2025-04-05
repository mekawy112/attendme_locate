import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/theming/colors.dart';
import '../widgets/application_app_bar.dart';

class AttendanceNotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AttendanceNotificationsScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _AttendanceNotificationsScreenState createState() => _AttendanceNotificationsScreenState();
}

class _AttendanceNotificationsScreenState extends State<AttendanceNotificationsScreen> {
  List<Map<String, dynamic>> _attendanceNotifications = [];
  Map<String, List<Map<String, dynamic>>> _groupedNotifications = {};

  @override
  void initState() {
    super.initState();
    _loadAttendanceNotifications();
  }

  // Load attendance history from SharedPreferences
  Future<void> _loadAttendanceNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? notificationStrings = prefs.getStringList('attendance_notifications');
      
      if (notificationStrings != null && notificationStrings.isNotEmpty) {
        print("Found ${notificationStrings.length} notification records");
        
        List<Map<String, dynamic>> notifications = notificationStrings
            .map((str) => Map<String, dynamic>.from(jsonDecode(str)))
            .toList();
        
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
      } else {
        print("No attendance records found in SharedPreferences");
        // Only create sample data in development for testing
        if (false) { // Set to true for testing, false for production
          _createSampleNotifications();
        }
      }
    } catch (e) {
      print('Error loading attendance notifications: $e');
    }
  }

  // This method creates sample notifications for testing only
  void _createSampleNotifications() {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildApplicationAppBar(title: 'Attendance History'),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16.h),
              
              // Attendance Notifications Section
              Padding(
                padding: EdgeInsets.only(left: 10.w, bottom: 10.h),
                child: Text(
                  'Your Attendance Records',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // Display notifications grouped by date
              ..._groupedNotifications.entries.map((entry) {
                String dateStr = entry.key;
                List<Map<String, dynamic>> dayNotifications = entry.value;
                DateTime notificationDate = DateTime.parse(dateStr);
                String formattedDate = DateFormat('EEEE, MMM d, yyyy').format(notificationDate);
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header with styling
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 15.w),
                      margin: EdgeInsets.only(top: 10.h, bottom: 8.h),
                      decoration: BoxDecoration(
                        color: ColorsManager.blueColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        formattedDate,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                    
                    // Notifications for this date
                    ...dayNotifications.map((notification) {
                      bool isAlreadyRecorded = notification['already_recorded'] ?? false;
                      String courseName = notification['course_name'] ?? 'Unknown Course';
                      
                      String message = isAlreadyRecorded
                          ? "Attendance already recorded for $courseName"
                          : "Successfully attended $courseName";
                          
                      return Container(
                        margin: EdgeInsets.only(bottom: 12.h, left: 5.w, right: 5.w),
                        padding: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isAlreadyRecorded ? Colors.orange[600] : Colors.green[600],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAlreadyRecorded ? Icons.info_outline : Icons.check,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    DateFormat('h:mm a').format(DateTime.parse(notification['timestamp'])),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
              
              // Empty state if no notifications
              if (_groupedNotifications.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 50.h),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_off,
                          size: 48.sp,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No attendance records found',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}

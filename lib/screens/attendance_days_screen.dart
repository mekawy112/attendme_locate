import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../core/theming/colors.dart';
import '../services/api_service.dart';
import '../services/course_service.dart';
import 'attendance_details_screen.dart';
import 'attendance_summary_screen.dart';

class AttendanceDaysScreen extends StatefulWidget {
  final int courseId;
  final String courseName;

  const AttendanceDaysScreen({
    Key? key, 
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  State<AttendanceDaysScreen> createState() => _AttendanceDaysScreenState();
}

class _AttendanceDaysScreenState extends State<AttendanceDaysScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<String> _dates = [];
  
  @override
  void initState() {
    super.initState();
    _fetchAttendanceDates();
  }

  Future<void> _fetchAttendanceDates() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // استخدام خدمة المقررات بدلاً من HTTP مباشرة
      final courseService = CourseService();
      
      // البحث عن التواريخ المتاحة للمقرر
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/doctor/course-attendance/dates?course_id=${widget.courseId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        // إذا فشل جلب التواريخ، قم بالتنقل مباشرة إلى صفحة حضور اليوم
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceDetailsScreen(
              courseId: widget.courseId,
              courseName: widget.courseName,
            ),
          ),
        );
        return;
      }
      
      final data = jsonDecode(response.body);
      
      // استخراج التواريخ الفريدة من البيانات
      if (data['dates'] != null) {
        _dates = List<String>.from(data['dates']);
      } else {
        _dates = [];
      }
      
      // ترتيب التواريخ تنازلياً (الأحدث أولاً)
      _dates.sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));

      setState(() {
        _isLoading = false;
      });
      
      // إذا لم تكن هناك تواريخ متاحة، انتقل إلى صفحة اليوم الحالي
      if (_dates.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceDetailsScreen(
              courseId: widget.courseId,
              courseName: widget.courseName,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error fetching attendance dates: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      // في حالة حدوث خطأ، انتقل إلى صفحة اليوم الحالي
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AttendanceDetailsScreen(
            courseId: widget.courseId,
            courseName: widget.courseName,
          ),
        ),
      );
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd (EEEE)', 'en').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance: ${widget.courseName}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: ColorsManager.darkBlueColor1,
        actions: [
          // إضافة زر ملخص الحضور الإجمالي
          IconButton(
            icon: const Icon(Icons.summarize, color: Colors.white),
            tooltip: 'Attendance Summary',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceSummaryScreen(
                    courseId: widget.courseId,
                    courseName: widget.courseName,
                  ),
                ),
              );
            },
          ),
          // إضافة زر لعرض حضور اليوم مباشرة
          IconButton(
            icon: const Icon(Icons.today, color: Colors.white),
            tooltip: 'Today\'s Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceDetailsScreen(
                    courseId: widget.courseId,
                    courseName: widget.courseName,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAttendanceDates,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(child: Text('Error: $_errorMessage'))
              : _dates.isEmpty
                  ? const Center(child: Text('No attendance data available'))
                  : ListView.builder(
                      itemCount: _dates.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final date = _dates[index];
                        final formattedDate = _formatDate(date);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            leading: const Icon(
                              Icons.calendar_today,
                              color: ColorsManager.darkBlueColor1,
                            ),
                            title: Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AttendanceDetailsScreen(
                                    courseId: widget.courseId,
                                    courseName: widget.courseName,
                                    // تمرير التاريخ المختار
                                    date: date,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}

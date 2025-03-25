import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../core/theming/colors.dart';

class AttendanceDetailsScreen extends StatefulWidget {
  final int courseId;

  const AttendanceDetailsScreen({Key? key, required this.courseId}) : super(key: key);

  @override
  State<AttendanceDetailsScreen> createState() => _AttendanceDetailsScreenState();
}

class _AttendanceDetailsScreenState extends State<AttendanceDetailsScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _students = [];
  List<String> _dates = [];
  Map<String, Map<String, bool>> _attendanceData = {};
  
  // تخزين البيانات المجمعة
  Map<int, Map<String, dynamic>> _consolidatedData = {};
  
  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // جلب بيانات الطلاب المسجلين في المقرر
      final studentsResponse = await http.get(
        Uri.parse('http://192.168.1.68:5000/courses/${widget.courseId}/students'),
      );

      if (studentsResponse.statusCode != 200) {
        throw Exception('Failed to load students data');
      }

      final studentsData = jsonDecode(studentsResponse.body);
      _students = List<Map<String, dynamic>>.from(studentsData['students']);

      // جلب سجلات الحضور للمقرر
      final attendanceResponse = await http.get(
        Uri.parse('http://192.168.1.68:5000/courses/${widget.courseId}/attendance'),
      );

      if (attendanceResponse.statusCode != 200) {
        throw Exception('Failed to load attendance data');
      }

      final attendanceData = jsonDecode(attendanceResponse.body);
      List<dynamic> records = attendanceData['records'];

      // معالجة التواريخ وبناء البيانات المطلوبة
      _processAttendanceData(records);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _processAttendanceData(List<dynamic> records) {
    // استخراج التواريخ الفريدة
    Set<String> uniqueDates = {};
    Map<int, Map<String, dynamic>> studentData = {};

    // تهيئة بيانات الطلاب
    for (var student in _students) {
      int studentId = student['id'];
      studentData[studentId] = {
        'name': student['name'],
        'student_id': student['student_id'],
        'attendance': <String, bool>{},
      };
    }

    // تجميع بيانات الحضور حسب الطالب والتاريخ
    for (var record in records) {
      String date = record['date'];
      uniqueDates.add(date);
      
      int studentId = record['student_id'];
      
      if (studentData.containsKey(studentId)) {
        Map<String, dynamic> studentInfo = studentData[studentId]!;
        Map<String, bool> attendance = studentInfo['attendance'] as Map<String, bool>;
        attendance[date] = record['face_verified'] && record['location_verified'];
      }
    }

    // تحويل التواريخ إلى قائمة مرتبة
    _dates = uniqueDates.toList();
    _dates.sort(); // ترتيب التواريخ تصاعدياً

    // ضمان أن جميع الطلاب لديهم سجلات لكل التواريخ
    for (var studentId in studentData.keys) {
      Map<String, dynamic> studentInfo = studentData[studentId]!;
      Map<String, bool> attendance = studentInfo['attendance'] as Map<String, bool>;
      
      for (var date in _dates) {
        if (!attendance.containsKey(date)) {
          attendance[date] = false;
        }
      }
    }

    _consolidatedData = studentData;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
            color: Colors.white
        ),
        title: const Text('Attendance Sheet',style: TextStyle(
          color: Colors.white
        ),),
        backgroundColor: ColorsManager.darkBlueColor1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white,),
            onPressed: _fetchAttendanceData,
          ),
          IconButton(
            icon: const Icon(Icons.save_alt, color: Colors.white,),
            onPressed: () {
              // يمكن إضافة تصدير البيانات لاحقاً
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming Soon ..')),
              );
            },
            tooltip: 'Expert File',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(child: Text('Oops! an error occurred: $_errorMessage'))
              : _buildAttendanceTable(),
    );
  }

  Widget _buildAttendanceTable() {
    if (_consolidatedData.isEmpty) {
      return const Center(child: Text('لا توجد بيانات حضور للعرض'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
          border: TableBorder.all(color: Colors.grey.shade300),
          columns: [
            const DataColumn(label: Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.bold))),
            ..._dates.map((date) => DataColumn(
                  label: Text(
                    _formatDate(date),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )),
            const DataColumn(label: Text('نسبة الحضور', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _consolidatedData.values.map((studentInfo) {
            // حساب نسبة الحضور
            int attendedCount = 0;
            Map<String, bool> attendance = studentInfo['attendance'] as Map<String, bool>;
            
            for (var isPresent in attendance.values) {
              if (isPresent) attendedCount++;
            }
            
            double attendanceRate = attendance.isEmpty ? 0 : attendedCount / attendance.length * 100;
            
            return DataRow(
              cells: [
                DataCell(Text(studentInfo['name'] ?? 'غير معروف')),
                DataCell(Text(studentInfo['student_id'] ?? 'غير معروف')),
                ..._dates.map((date) {
                  bool isPresent = attendance[date] ?? false;
                  return DataCell(
                    Container(
                      color: isPresent ? Colors.green.shade100 : Colors.red.shade100,
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Icon(
                          isPresent ? Icons.check_circle : Icons.cancel,
                          color: isPresent ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                DataCell(Text('${attendanceRate.toStringAsFixed(1)}%')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../core/theming/colors.dart';
import '../services/course_service.dart';

class AttendanceDetailsScreen extends StatefulWidget {
  final int courseId;
  final String courseName;
  final String? date;

  const AttendanceDetailsScreen({
    Key? key, 
    required this.courseId,
    this.courseName = "",
    this.date,
  }) : super(key: key);

  @override
  State<AttendanceDetailsScreen> createState() => _AttendanceDetailsScreenState();
}

class _AttendanceDetailsScreenState extends State<AttendanceDetailsScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _students = [];
  String _selectedDate = '';
  double _attendancePercentage = 0;
  int _totalStudents = 0;
  int _presentStudents = 0;
  int _absentStudents = 0;
  
  final CourseService _courseService = CourseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date ?? DateTime.now().toString().split(' ')[0];
    _fetchAttendanceData();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // استخدام الخدمة المحدثة لجلب بيانات الحضور
      final response = await _courseService.getAttendanceRecords(
        widget.courseId,
        date: _selectedDate,
      );

      if (response['success']) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(response['students']);
          _totalStudents = response['total_students'];
          _presentStudents = response['present_students'];
          _absentStudents = response['absence_students'];
          _attendancePercentage = response['attendance_percentage'].toDouble();
          _isLoading = false;
        });
      } else {
        throw Exception(response['message']);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _searchStudent() async {
    if (_searchQuery.isEmpty) {
      _fetchAttendanceData();
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _courseService.searchStudentAttendance(
        widget.courseId,
        _searchQuery,
        date: _selectedDate,
      );

      if (response['success']) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(response['students']);
          _totalStudents = response['total_students'];
          _presentStudents = response['present_students'];
          _absentStudents = response['absence_students'];
          _attendancePercentage = response['attendance_percentage'].toDouble();
          _isLoading = false;
        });
      } else {
        throw Exception(response['message']);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate.toString().split(' ')[0];
        _fetchAttendanceData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.white),
        title: Text(
          'حضور ${widget.courseName}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: ColorsManager.darkBlueColor1,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAttendanceData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(child: Text('خطأ: $_errorMessage'))
              : _buildAttendanceScreen(),
    );
  }

  Widget _buildAttendanceScreen() {
    return Column(
      children: [
        // معلومات إحصائية
        _buildAttendanceSummary(),
        
        // بحث عن طالب
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'بحث عن طالب بالرقم',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  _searchQuery = _searchController.text.trim();
                  _searchStudent();
                },
              ),
            ),
            onSubmitted: (value) {
              _searchQuery = value.trim();
              _searchStudent();
            },
          ),
        ),
        
        // قائمة الطلاب
        Expanded(child: _buildStudentsList()),
      ],
    );
  }
  
  Widget _buildAttendanceSummary() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('التاريخ', _selectedDate),
          _buildSummaryItem('إجمالي الطلاب', '$_totalStudents'),
          _buildSummaryItem('الحضور', '$_presentStudents'),
          _buildSummaryItem('الغياب', '$_absentStudents'),
          _buildSummaryItem('نسبة الحضور', '${_attendancePercentage.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }
  
  Widget _buildSummaryItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: title == 'الغياب' ? Colors.red : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsList() {
    if (_students.isEmpty) {
      return const Center(child: Text('لا توجد بيانات للعرض'));
    }

    return ListView.builder(
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final bool isPresent = student['is_present'] ?? false;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPresent ? Colors.green : Colors.red,
              child: Icon(
                isPresent ? Icons.check : Icons.close,
                color: Colors.white,
              ),
            ),
            title: Text(
              student['student_name'] ?? 'غير معروف',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('رقم الطالب: ${student['student_number'] ?? 'غير متوفر'}'),
            trailing: Text(
              isPresent ? 'حاضر' : 'غائب',
              style: TextStyle(
                color: isPresent ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
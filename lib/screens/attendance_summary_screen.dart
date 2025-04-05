import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../core/theming/colors.dart';
import '../services/course_service.dart';

class AttendanceSummaryScreen extends StatefulWidget {
  final int courseId;
  final String courseName;

  const AttendanceSummaryScreen({
    Key? key, 
    required this.courseId,
    this.courseName = "",
  }) : super(key: key);

  @override
  State<AttendanceSummaryScreen> createState() => _AttendanceSummaryScreenState();
}

class _AttendanceSummaryScreenState extends State<AttendanceSummaryScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _students = [];
  String _courseName = '';
  String _courseCode = '';
  int _totalStudents = 0;
  int _totalLectures = 0;
  
  final CourseService _courseService = CourseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _courseName = widget.courseName;
    _fetchAttendanceSummary();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAttendanceSummary() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _courseService.getCourseAttendanceSummary(widget.courseId);

      if (response['success']) {
        // Process the students data to ensure unique daily attendance
        final List<Map<String, dynamic>> rawStudents = List<Map<String, dynamic>>.from(response['students'] ?? []);
        
        // Create a map to store processed student attendance
        final Map<String, Map<String, dynamic>> processedStudents = {};
        
        // Process each student's attendance
        for (var student in rawStudents) {
          final studentId = student['student_number'].toString();
          final attendanceDate = student['attendance_date']?.toString().split('T')[0];
          
          if (!processedStudents.containsKey(studentId)) {
            // Initialize student record with basic info
            processedStudents[studentId] = {
              'student_name': student['student_name'],
              'student_number': student['student_number'],
              'attendance_count': 0,
              'attendance_dates': <String>{}, // Using Set to store unique dates
            };
          }
          
          // Only count attendance once per day
          if (attendanceDate != null) {
            processedStudents[studentId]!['attendance_dates'].add(attendanceDate);
            processedStudents[studentId]!['attendance_count'] = 
                processedStudents[studentId]!['attendance_dates'].length;
          }
        }

        setState(() {
          _courseName = response['course_name'] ?? widget.courseName;
          _courseCode = response['course_code'] ?? '';
          _totalStudents = response['total_students'] ?? 0;
          _totalLectures = response['total_lectures'] ?? 0;
          // Convert processed students back to list
          _students = processedStudents.values.map((student) => {
            'student_name': student['student_name'],
            'student_number': student['student_number'],
            'attendance_count': student['attendance_count'],
          }).toList();
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

  List<Map<String, dynamic>> get _filteredStudents {
    if (_searchQuery.isEmpty) {
      return _students;
    }
    
    return _students.where((student) {
      final studentName = student['student_name']?.toString().toLowerCase() ?? '';
      final studentNumber = student['student_number']?.toString().toLowerCase() ?? '';
      
      return studentName.contains(_searchQuery.toLowerCase()) || 
             studentNumber.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.white),
        title: Text(
          'Attendance Summary: $_courseName',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: ColorsManager.darkBlueColor1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAttendanceSummary,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(child: Text('Error: $_errorMessage'))
              : _buildSummaryScreen(),
    );
  }

  Widget _buildSummaryScreen() {
    return Column(
      children: [
        // Course summary statistics
        _buildCourseSummary(),
        
        // Student search
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search by ID or Name',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  setState(() {
                    _searchQuery = _searchController.text.trim();
                  });
                },
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
              });
            },
          ),
        ),
        
        // Table header
        Container(
          color: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Student Name',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Student ID',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Attendance Count',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        
        // Student list
        Expanded(child: _buildStudentsList()),
      ],
    );
  }
  
  Widget _buildCourseSummary() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_courseName ($_courseCode)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total Lectures', '$_totalLectures'),
              _buildSummaryItem('Total Students', '$_totalStudents'),
            ],
          ),
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
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsList() {
    if (_filteredStudents.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return ListView.builder(
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final student = _filteredStudents[index];
        final int attendanceCount = student['attendance_count'] ?? 0;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    student['student_name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(student['student_number'] ?? 'N/A'),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '$attendanceCount',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

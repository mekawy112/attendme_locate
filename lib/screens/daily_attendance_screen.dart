import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../core/theming/colors.dart';
import '../services/api_service.dart';

class DailyAttendanceScreen extends StatefulWidget {
  final int courseId;
  final String courseName;

  const DailyAttendanceScreen({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  State<DailyAttendanceScreen> createState() => _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends State<DailyAttendanceScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  int _presentCount = 0;
  int _absentCount = 0;
  final TextEditingController _searchController = TextEditingController();
  final String _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchTodayAttendance();
  }

  void _filterStudents(String query) {
    setState(() {
      _filteredStudents = _students.where((student) {
        final studentId = student['student_id'].toString().toLowerCase();
        final studentName = student['name'].toString().toLowerCase();
        final searchLower = query.toLowerCase();
        return studentId.contains(searchLower) || studentName.contains(searchLower);
      }).toList();
    });
  }

  Future<void> _fetchTodayAttendance() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Fetch all enrolled students
      final studentsResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/courses/${widget.courseId}/students'),
      );

      if (studentsResponse.statusCode != 200) {
        throw Exception('Failed to load students data');
      }

      final studentsData = jsonDecode(studentsResponse.body);
      final enrolledStudents = List<Map<String, dynamic>>.from(studentsData['students']);

      // Fetch today's attendance records
      final attendanceResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/courses/${widget.courseId}/attendance?date=$_today'),
      );

      if (attendanceResponse.statusCode != 200) {
        throw Exception('Failed to load attendance data');
      }

      final attendanceData = jsonDecode(attendanceResponse.body);
      final attendanceRecords = List<Map<String, dynamic>>.from(attendanceData['records']);

      // Create a Set to track unique student IDs that have been marked present
      final Set<int> presentStudentIds = {};

      // Mark attendance status for each student (only count once per day)
      _students = enrolledStudents.map((student) {
        final studentId = student['id'];
        // Check if this student has already been marked present today
        final hasAttendance = attendanceRecords.any((record) {
          if (record['student_id'] == studentId &&
              record['face_verified'] == true &&
              record['location_verified'] == true) {
            return presentStudentIds.add(studentId); // Returns true only if ID wasn't already in set
          }
          return false;
        });

        return {
          ...student,
          'is_present': hasAttendance,
        };
      }).toList();

      // Update counts based on unique present students
      _presentCount = presentStudentIds.length;
      _absentCount = _students.length - _presentCount;

      // Initialize filtered list
      _filteredStudents = List.from(_students);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'حضور ${widget.courseName} - $_today',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: ColorsManager.darkBlueColor1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchTodayAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'البحث عن طالب بالاسم أو الرقم',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _filterStudents,
            ),
          ),

          // Attendance Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryCard(
                  'الحضور',
                  _presentCount,
                  Colors.green.shade100,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'الغياب',
                  _absentCount,
                  Colors.red.shade100,
                  Colors.red,
                ),
              ],
            ),
          ),

          // Students List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? Center(child: Text('حدث خطأ: $_errorMessage'))
                    : _filteredStudents.isEmpty
                        ? const Center(child: Text('لا يوجد طلاب'))
                        : ListView.builder(
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 4.0,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: student['is_present']
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    child: Icon(
                                      student['is_present']
                                          ? Icons.check
                                          : Icons.close,
                                      color: student['is_present']
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  title: Text(student['name']),
                                  subtitle: Text('رقم الطالب: ${student['student_id']}'),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, int count, Color bgColor, Color textColor) {
    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Text(
              count.toString(),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 24.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
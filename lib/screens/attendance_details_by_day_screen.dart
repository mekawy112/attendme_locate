import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../core/theming/colors.dart';
import '../services/api_service.dart';

class AttendanceDetailsByDayScreen extends StatefulWidget {
  final int courseId;
  final String courseName;
  final String date;
  final String formattedDate;

  const AttendanceDetailsByDayScreen({
    Key? key,
    required this.courseId,
    required this.courseName,
    required this.date,
    required this.formattedDate,
  }) : super(key: key);

  @override
  State<AttendanceDetailsByDayScreen> createState() => _AttendanceDetailsByDayScreenState();
}

class _AttendanceDetailsByDayScreenState extends State<AttendanceDetailsByDayScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _attendanceRecords = [];
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredRecords = [];

  @override
  void initState() {
    super.initState();
    _fetchAttendanceDetailsByDay();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterRecords(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredRecords = List.from(_attendanceRecords);
      });
      return;
    }

    setState(() {
      _filteredRecords = _attendanceRecords.where((record) {
        final studentId = record['student_id'].toString().toLowerCase();
        final studentName = record['student_name'].toString().toLowerCase();
        final searchLower = query.toLowerCase();
        return studentId.contains(searchLower) || studentName.contains(searchLower);
      }).toList();
    });
  }

  Future<void> _fetchAttendanceDetailsByDay() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Fetch students enrolled in the course
      final studentsResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/courses/${widget.courseId}/students'),
      );

      if (studentsResponse.statusCode != 200) {
        throw Exception('Failed to load students data');
      }

      final studentsData = jsonDecode(studentsResponse.body);
      final students = Map<int, Map<String, dynamic>>.fromEntries(
        List<Map<String, dynamic>>.from(studentsData['students'])
            .map((student) => MapEntry(student['id'], student)),
      );

      // Fetch attendance records for the course
      final attendanceResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/courses/${widget.courseId}/attendance'),
      );

      if (attendanceResponse.statusCode != 200) {
        throw Exception('Failed to load attendance data');
      }

      final attendanceData = jsonDecode(attendanceResponse.body);
      List<dynamic> allRecords = attendanceData['records'];
      
      // Filter records for the specific date and valid attendance (both face and location verified)
      List<Map<String, dynamic>> dateRecords = [];
      
      // Deduplicate records by student_id
      Map<int, Map<String, dynamic>> studentRecords = {};
      
      for (var record in allRecords) {
        if (record['date'] == widget.date &&
            record['face_verified'] == true &&
            record['location_verified'] == true) {
          
          int studentId = record['student_id'];
          
          // Skip if we already have a record for this student on this date
          if (studentRecords.containsKey(studentId)) {
            continue;
          }
          
          // Add student information to the record
          if (students.containsKey(studentId)) {
            record['student_name'] = students[studentId]!['name'];
            record['student_id_code'] = students[studentId]!['student_id'];
          } else {
            record['student_name'] = 'Unknown';
            record['student_id_code'] = 'Unknown';
          }
          
          // Format the time
          if (record['created_at'] != null) {
            try {
              DateTime createdAt = DateTime.parse(record['created_at']);
              record['formatted_time'] = DateFormat('HH:mm:ss').format(createdAt);
            } catch (e) {
              record['formatted_time'] = 'Invalid time';
            }
          } else {
            record['formatted_time'] = 'N/A';
          }
          
          studentRecords[studentId] = Map<String, dynamic>.from(record);
        }
      }
      
      // Convert to list
      dateRecords = studentRecords.values.toList();
      
      // Sort by time of attendance
      dateRecords.sort((a, b) {
        return a['created_at'].compareTo(b['created_at']);
      });
      
      setState(() {
        _attendanceRecords = dateRecords;
        _filteredRecords = List.from(dateRecords);
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
          'u062du0636u0648u0631 ${widget.formattedDate}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: ColorsManager.darkBlueColor1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAttendanceDetailsByDay,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'u0627u0644u0628u062du062b u0639u0646 u0637u0627u0644u0628 u0628u0627u0644u0627u0633u0645 u0623u0648 u0627u0644u0631u0642u0645',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _filterRecords,
            ),
          ),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
                ? Center(child: Text('u062eu0637u0623: $_errorMessage'))
                : _filteredRecords.isEmpty
                  ? const Center(child: Text('u0644u0627 u064au0648u062cu062f u0637u0644u0627u0628 u062du0627u0636u0631u064au0646 u0641u064a u0647u0630u0627 u0627u0644u064au0648u0645'))
                  : ListView.builder(
                    itemCount: _filteredRecords.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final record = _filteredRecords[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: ColorsManager.darkBlueColor1,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            record['student_name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${record['student_id_code'] ?? 'Unknown'}'),
                              const SizedBox(height: 2),
                              Text('u0648u0642u062a u0627u0644u062du0636u0648u0631: ${record['formatted_time'] ?? 'N/A'}'),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                          isThreeLine: true,
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

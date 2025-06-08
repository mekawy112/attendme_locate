import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theming/colors.dart';
import '../services/attendance_service.dart';
import '../widgets/application_app_bar.dart';

class CourseAttendanceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int courseId;
  final String courseName;

  const CourseAttendanceDetailsScreen({
    Key? key,
    required this.userData,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  _CourseAttendanceDetailsScreenState createState() => _CourseAttendanceDetailsScreenState();
}

class _CourseAttendanceDetailsScreenState extends State<CourseAttendanceDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _courseDetails = {};
  List<Map<String, dynamic>> _attendanceRecords = [];
  final AttendanceService _attendanceService = AttendanceService();
  String _filterStatus = 'All'; // 'All', 'Present', 'Absent'

  @override
  void initState() {
    super.initState();
    _loadCourseAttendanceDetails();
  }

  Future<void> _loadCourseAttendanceDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final studentId = widget.userData['id'];
      final response = await _attendanceService.getCourseAttendanceDetails(
        studentId,
        widget.courseId,
      );

      if (response['success']) {
        setState(() {
          _courseDetails = {
            'course_id': response['course_id'],
            'course_name': response['course_name'],
            'attendance_percentage': response['attendance_percentage'],
            'total_lectures': response['total_lectures'],
            'attended': response['attended'],
            'absences': response['absences'],
            'remaining_absences': response['remaining_absences'],
          };
          _attendanceRecords = List<Map<String, dynamic>>.from(response['attendance_records']);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load course attendance details')),
        );
      }
    } catch (e) {
      print('Error loading course attendance details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredRecords {
    if (_filterStatus == 'All') {
      return _attendanceRecords;
    }
    return _attendanceRecords.where((record) => record['status'] == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildApplicationAppBar(title: widget.courseName),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Course attendance summary card
                _buildSummaryCard(),
                
                // Filter options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Attendance Records',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<String>(
                        value: _filterStatus,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(value: 'Present', child: Text('Present')),
                          DropdownMenuItem(value: 'Absent', child: Text('Absent')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterStatus = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                
                // Attendance records list
                Expanded(
                  child: filteredRecords.isEmpty
                      ? const Center(child: Text('No attendance records found'))
                      : ListView.builder(
                          itemCount: filteredRecords.length,
                          itemBuilder: (context, index) {
                            final record = filteredRecords[index];
                            final bool wasPresent = record['status'] == 'Present';
                            
                            // Parse date for better formatting
                            DateTime? recordDate;
                            try {
                              recordDate = DateTime.parse(record['date']);
                            } catch (e) {
                              // If date parsing fails, leave it as null
                            }
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: wasPresent ? Colors.green : Colors.red,
                                  child: Icon(
                                    wasPresent ? Icons.check : Icons.close,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  recordDate != null
                                      ? DateFormat('EEEE, MMMM d, yyyy').format(recordDate)
                                      : record['date'],
                                ),
                                subtitle: Text('Time: ${record['timestamp']}'),
                                trailing: Text(
                                  wasPresent ? 'Present' : 'Absent',
                                  style: TextStyle(
                                    color: wasPresent ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
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

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              _courseDetails['course_name'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 100,
                  width: 100,
                  child: Stack(
                    children: [
                      Center(
                        child: SizedBox(
                          height: 100,
                          width: 100,
                          child: CircularProgressIndicator(
                            value: _courseDetails['attendance_percentage'] / 100,
                            strokeWidth: 10,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getStatusColor(_courseDetails['attendance_percentage']),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_courseDetails['attendance_percentage'].toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Total Classes', _courseDetails['total_lectures'].toString()),
                    _buildDetailRow('Present', _courseDetails['attended'].toString(), color: Colors.green),
                    _buildDetailRow('Absent', _courseDetails['absences'].toString(), color: Colors.red),
                    _buildDetailRow('Remaining Absences', _courseDetails['remaining_absences'].toString(), 
                      color: _courseDetails['remaining_absences'] > 0 ? Colors.orange : Colors.red),
                  ],
                ),
              ],
            ),
            if (_courseDetails['remaining_absences'] <= 0)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Warning: You have reached the maximum allowed absences for this course!',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 75) return Colors.blue;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }
}

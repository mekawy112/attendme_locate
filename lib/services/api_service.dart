// lib/services/api_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/api_exception.dart';

class ApiService {
  // المصدر المركزي لعنوان IP - قم بتغيير هذا العنوان فقط عند الحاجة
  static const String baseUrl = 'http://192.168.1.10:5000';

  Future<List<dynamic>> fetchData() async {
    try {
      print('Attempting to fetch data from: $baseUrl/data');
      final response = await http.get(
        Uri.parse('$baseUrl/data'),
        headers: {'Content-Type': 'application/json'},
      );
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Network error: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<void> postData(String name, String location) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/data'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'location': location}),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to post data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to server: $e');
    }
  }
}

class DataList extends StatefulWidget {
  @override
  _DataListState createState() => _DataListState();
}

class _DataListState extends State<DataList> {
  final ApiService _apiService = ApiService();
  List data = [];
  bool isLoading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await _apiService.fetchData();
      setState(() {
        data = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $error'),
            ElevatedButton(onPressed: fetchData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchData,
      child: ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) {
          return ListTile(title: Text(data[index]['columnName']));
        },
      ),
    );
  }
}

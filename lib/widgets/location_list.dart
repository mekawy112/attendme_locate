import 'package:flutter/material.dart';
import '../models/location_data.dart';
import '../services/api_service.dart';

class LocationList extends StatefulWidget {
  const LocationList({super.key});

  @override
  State<LocationList> createState() => _LocationListState();
}

class _LocationListState extends State<LocationList> {
  final ApiService _apiService = ApiService();
  List<LocationData> data = [];
  bool isLoading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    print('=== Starting fetchData ===');
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      print('Making API call to: ${ApiService.baseUrl}/data');
      final result = await _apiService.fetchData();
      print('API Response received:');
      print('Data length: ${result.length}');
      print('Data content: $result');

      setState(() {
        data = result.map((item) => LocationData.fromJson(item)).toList();
        isLoading = false;
      });
      print('Data processed successfully. Items count: ${data.length}');
    } catch (e) {
      print('Error in fetchData: $e');
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
            ElevatedButton(
              onPressed: fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchData,
      child: ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(data[index].name),
            subtitle: Text(data[index].location),
          );
        },
      ),
    );
  }
}

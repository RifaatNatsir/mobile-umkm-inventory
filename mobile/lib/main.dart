import 'package:flutter/material.dart';
import 'src/services/api_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UMKM Inventory',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HealthCheckPage(),
    );
  }
}

class HealthCheckPage extends StatefulWidget {
  const HealthCheckPage({super.key});

  @override
  State<HealthCheckPage> createState() => _HealthCheckPageState();
}

class _HealthCheckPageState extends State<HealthCheckPage> {
  final ApiClient _apiClient = ApiClient();
  late Future<String> _futureMessage;

  @override
  void initState() {
    super.initState();
    _futureMessage = _apiClient.healthCheck();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tes Koneksi Backend'),
      ),
      body: Center(
        child: FutureBuilder<String>(
          future: _futureMessage,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              return Text('Respon API: ${snapshot.data}');
            }
          },
        ),
      ),
    );
  }
}
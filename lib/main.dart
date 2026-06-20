import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Placeholder for API configurations
const String API_BASE_URL = "https://your-api-server.com/api";
const String API_TOKEN = "YOUR_API_TOKEN";
const String USER_ID = "YOUR_USER_ID";

// Notification plugin for foreground service
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initNotifications();
  runApp(const MyApp());
}

Future<void> _initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

@pragma('vm:entry-point')
void startCallback() {
  // تهيئة خيارات الخدمة الخلفية بشكل كامل وصحيح وبدون أي بتر
  FlutterForegroundTask.init(
    androidNotificationOptions: const AndroidNotificationOptions(
      channelId: 'foreground_service_channel',
      channelName: 'Foreground Service Notification',
      channelDescription: 'This notification keeps the app running in the background.',
      channelImportance: NotificationImportance.LOW,
      priority: NotificationPriority.LOW,
      iconData: NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000, // 5 seconds
      isOnceEvent: false,
      autoRunOnBoot: true,
      allowWakeLock: true,
    ),
  );

  // بدء الخدمة
  FlutterForegroundTask.startService(
    notificationTitle: 'Data Sync App',
    notificationText: 'Application is running in the background for data synchronization.',
    callback: updateCallback,
  );
}

@pragma('vm:entry-point')
void updateCallback() {
  FlutterForegroundTask.updateTask(
    notificationTitle: 'Data Sync App',
    notificationText: 'Data synchronization active: ${DateTime.now().toIso8601String()}',
    callback: updateCallback,
  );

  _checkServerStatus();
}

Future<void> _checkServerStatus() async {
  try {
    final response = await http.get(Uri.parse('$API_BASE_URL/status'));
    if (response.statusCode == 200) {
      print('Server status: Online');
    } else {
      print('Server status: Offline');
    }
  } catch (e) {
    print('Error checking server status: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const DataSyncScreen(),
    );
  }
}

class DataSyncScreen extends StatefulWidget {
  const DataSyncScreen({super.key});

  @override
  _DataSyncScreenState createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends State<DataSyncScreen> {
  bool isSyncing = false;
  String statusMessage = "";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.notification, Permission.storage].request();
  }

  Future<void> _toggleSyncing() async {
    if (isSyncing) {
      await FlutterForegroundTask.stopService();
      setState(() {
        isSyncing = false;
        statusMessage = "Data synchronization stopped.";
      });
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Data Sync App',
        notificationText: 'Application is running in the background for data synchronization.',
        callback: startCallback,
      );
      setState(() {
        isSyncing = true;
        statusMessage = "Data synchronization started.";
      });
    }
  }

  Future<void> _sendData() async {
    setState(() {
      statusMessage = "Sending data...";
    });
    try {
      final url = Uri.parse('$API_BASE_URL/send_message');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $API_TOKEN',
        },
        body: json.encode({
          'userId': USER_ID,
          'message': 'Hello from Flutter Data Sync App!',
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          statusMessage = "Text data sent successfully!";
        });
      } else {
        setState(() {
          statusMessage = "Failed to send text data: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = "Error sending text data: $e";

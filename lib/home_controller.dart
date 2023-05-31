import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class HomeController extends GetxController {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  RxBool isLoading = false.obs;

  Database? _database;

  @override
  void onInit() {
    super.onInit();
    initDatabase();
  }

  Future<void> initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final _path = path.join(databasesPath, 'form.db');

    _database = await openDatabase(
      _path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE form (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            email TEXT
          )
        ''');
      },
    );
  }

  void submitForm() async {
    String name = nameController.text;
    String email = emailController.text;

    isLoading.value = true;

    // Save data to the database
    await saveToDatabase(name, email);

    // Save data to Google Sheets
    await saveToGoogleSheets(name, email);

    // Reset form
    nameController.clear();
    emailController.clear();

    isLoading.value = false;
    Get.dialog(
      AlertDialog(
        title: const Text('Form Submitted'),
        content: Text('Name: $name\nEmail: $email'),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // Get.snackbar('Success', 'Form submitted successfully');
  }

  Future<void> saveToDatabase(String name, String email) async {
    final formMap = {'name': name, 'email': email};

    final id = await _database?.insert('form', formMap);

    if (id == null) {
      Get.snackbar('Error', 'Failed to save data to the database');
    }
  }

  Future<void> saveToGoogleSheets(String name, String email) async {
    const _credentials = 'assets/credentials.json';
    const _scopes = [sheets.SheetsApi.spreadsheetsScope];

    final credentials = await auth.clientViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(
          await _loadCredentials(_credentials)),
      _scopes,
    );

    final sheetsApi = sheets.SheetsApi(credentials);
    final spreadsheetId = '191-rVBo223O9P3DdpT890fu6UWti7bFGdYrKova9uTw';

    final values = [
      [name, email],
    ];

    final range = 'Sheet1!A1:B1';

    final request = sheets.ValueRange()..values = values;
    await sheetsApi.spreadsheets.values
        .append(request, spreadsheetId, range, valueInputOption: 'RAW');
  }

  Future<String> _loadCredentials(String credentials) async {
    return await rootBundle.loadString(credentials);
  }
}

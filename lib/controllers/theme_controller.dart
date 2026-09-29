import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  final _storage = GetStorage();
  final _key = 'isDarkMode';

  // Observable boolean to track current mode
  var isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Load from storage, default to false (Light Mode) if not found
    isDarkMode.value = _storage.read(_key) ?? false;
  }

  // Getter for ThemeMode based on isDarkMode
  ThemeMode get themeMode => isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  // Function to switch theme
  void switchTheme() {
    isDarkMode.value = !isDarkMode.value;
    // Save to storage
    _storage.write(_key, isDarkMode.value);
    // Apply theme
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/main.dart';
import 'transaction_controller.dart';

class UserController extends GetxController {
  var name = 'Pengguna'.obs;
  var role = ''.obs;
  var useBiometric = false.obs;
  var usePin = false.obs;
  var encryptData = false.obs;
  var isRegistered = false.obs;
  var isLoggedIn = false.obs;

  /// State loading reaktif untuk dipakai oleh Obx di View.
  var isLoading = false.obs;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    name.value = prefs.getString('user_name') ?? 'Pengguna';
    role.value = prefs.getString('user_role') ?? '';
    useBiometric.value = prefs.getBool('use_biometric') ?? false;
    usePin.value = prefs.getBool('use_pin') ?? false;
    encryptData.value = prefs.getBool('encrypt_data') ?? false;

    // Cek sesi aktif Supabase
    final session = supabase.auth.currentSession;
    if (session != null) {
      isRegistered.value = true;
      isLoggedIn.value = true;
    }
  }

  Future<void> saveProfile(String newName, String newRole) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', newName);
    await prefs.setString('user_role', newRole);
    name.value = newName;
    role.value = newRole;
  }

  // ============ REGISTRASI AKUN (SUPABASE AUTH) ============

  Future<bool> registerAccount({
    required String fullName,
    required String roleText,
    required String username, // harus format email untuk Supabase
    required String password,
  }) async {
    isLoading.value = true;
    try {
      final response = await supabase.auth.signUp(
        email: username,
        password: password,
        data: {
          'full_name': fullName,
          'role': roleText,
        },
      );

      if (response.user != null) {
        // Simpan profil lokal agar nama muncul di UI tanpa refetch
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', fullName);
        await prefs.setString('user_role', roleText);
        name.value = fullName;
        role.value = roleText;

        isRegistered.value = true;
        isLoggedIn.value = true;
        
        // 🔥 Ambil data transaksi dari Supabase untuk user baru
        try {
          Get.find<TransactionController>().loadTransactions();
        } catch (_) {}

        isLoading.value = false;
        return true;
      } else {
        Get.snackbar(
          'Gagal Daftar',
          'Pendaftaran gagal. Periksa email dan coba lagi.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
        );
        isLoading.value = false;
        return false;
      }
    } on AuthException catch (e) {
      Get.snackbar(
        'Gagal Daftar',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      isLoading.value = false;
      return false;
    } catch (e) {
      Get.snackbar('Error', 'Terjadi kesalahan: $e');
      isLoading.value = false;
      return false;
    }
  }

  // ============ LOGIN MANUAL (EMAIL + SANDI via Supabase) ============

  Future<bool> loginManual(String username, String password) async {
    isLoading.value = true;
    try {
      final response = await supabase.auth.signInWithPassword(
        email: username,
        password: password,
      );

      if (response.user != null) {
        // Muat nama dari metadata Supabase jika ada
        final meta = response.user!.userMetadata;
        if (meta != null) {
          final prefs = await SharedPreferences.getInstance();
          final savedName = meta['full_name'] as String? ?? 'Pengguna';
          final savedRole = meta['role'] as String? ?? '';
          await prefs.setString('user_name', savedName);
          await prefs.setString('user_role', savedRole);
          name.value = savedName;
          role.value = savedRole;
        }

        isLoggedIn.value = true;

        // 🔥 Ambil data transaksi dari Supabase untuk user yang login
        try {
          Get.find<TransactionController>().loadTransactions();
        } catch (_) {}

        isLoading.value = false;
        return true;
      }
      isLoading.value = false;
      return false;
    } on AuthException catch (e) {
      debugPrint('Login error: ${e.message}');
      Get.snackbar(
        'Login Gagal',
        e.message == 'Email not confirmed' 
            ? 'Email belum dikonfirmasi. Silakan periksa kotak masuk email Anda.' 
            : e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      isLoading.value = false;
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      Get.snackbar(
        'Login Gagal',
        'Terjadi kesalahan koneksi: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      isLoading.value = false;
      return false;
    }
  }

  // ============ LOGIN BIOMETRIK (SIDIK JARI / FACE ID) ============

  Future<bool> loginBiometric() async {
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      bool isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) return false;

      bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Sentuh sensor sidik jari untuk masuk MoneyTrack',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        // Pastikan sesi Supabase masih aktif
        final session = supabase.auth.currentSession;
        if (session != null) {
          isLoggedIn.value = true;
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ============ TOGGLE BIOMETRIK ============

  Future<void> toggleBiometric(bool value) async {
    if (value) {
      bool canCheck = await _localAuth.canCheckBiometrics;
      bool isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        Get.snackbar(
          'Tidak Didukung',
          'Perangkat Anda tidak mendukung fitur sidik jari / Face ID',
        );
        useBiometric.value = false;
        return;
      }

      bool didAuthenticate = await _localAuth.authenticate(
        localizedReason:
            'Sentuh sensor sidik jari untuk mengaktifkan fitur ini',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (didAuthenticate) {
        useBiometric.value = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('use_biometric', true);
        Get.snackbar('Berhasil', 'Autentikasi biometrik diaktifkan!');
      } else {
        useBiometric.value = false;
      }
    } else {
      useBiometric.value = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_biometric', false);
    }
  }

  // ============ SIMPAN PENGATURAN KEAMANAN ============

  Future<void> saveSecuritySettings({
    required bool pin,
    required bool biometric,
    required bool encrypt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_pin', pin);
    await prefs.setBool('use_biometric', biometric);
    await prefs.setBool('encrypt_data', encrypt);
    usePin.value = pin;
    useBiometric.value = biometric;
    encryptData.value = encrypt;
  }

  // ============ UPDATE KREDENSIAL (via Supabase) ============

  Future<void> updateCredentials(
      String newUsername, String newPassword) async {
    try {
      await supabase.auth.updateUser(
        UserAttributes(email: newUsername, password: newPassword),
      );
      Get.snackbar('Berhasil', 'Kredensial keamanan berhasil diperbarui!');
    } on AuthException catch (e) {
      Get.snackbar('Gagal', e.message);
    }
  }

  Future<String?> getStoredUsername() async {
    return supabase.auth.currentUser?.email;
  }

  // ============ LOGOUT ============

  Future<void> logout() async {
    await supabase.auth.signOut();
    isLoggedIn.value = false;
    // 🔥 Bersihkan data transaksi dari memori saat logout
    try {
      Get.find<TransactionController>().transactions.clear();
    } catch (_) {}
  }

  // ============ HAPUS AKUN (RESET TOTAL) ============

  Future<void> deleteAccount() async {
    await supabase.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    name.value = 'Guest';
    role.value = 'User';
    usePin.value = false;
    useBiometric.value = false;
    encryptData.value = false;
    isRegistered.value = false;
    isLoggedIn.value = false;
  }
}

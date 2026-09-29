import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'controllers/transaction_controller.dart';
import 'controllers/user_controller.dart';
import 'controllers/theme_controller.dart';
import 'screens/login_screen.dart';
import 'package:flutter_application_1/screens/home_screen.dart';
import 'utils/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await GetStorage.init();

  // 2. INISIALISASI KONEKSI SUPABASE CLOUD
  await Supabase.initialize(
    url: 'https://ylrbbmufbjiisquwpzkr.supabase.co',
    publishableKey: 'sb_publishable_odPaJ6SEdCUAilxrcOpmRg_TrmM9jbP',
  );

  Get.put(ThemeController());
  Get.put(TransactionController());
  Get.put(UserController());

  runApp(const MoneyTrackApp());
}

// 3. VARIABEL GLOBAL BIAR GAMPANG DI-CALL DI CONTROLLER MANAPUN
final supabase = Supabase.instance.client;

class MoneyTrackApp extends StatelessWidget {
  const MoneyTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();

    return GetMaterialApp(
      title: 'MoneyTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.themeMode,
      home: const AuthGate(),
    );
  }
}

/// Gerbang autentikasi: menentukan halaman awal berdasarkan status sesi cloud Supabase.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  Widget _targetScreen = const LoginScreen(); // Default fallback ke Login

  @override
  void initState() {
    super.initState();
    _checkAuthFlow();
  }

  Future<void> _checkAuthFlow() async {
    try {
      // 🔥 CEK SESI USER DARI SUPABASE CLOUD
      final session = supabase.auth.currentSession;

      if (session != null) {
        // Jika sesi aktif ditemukan (user sudah login), langsung arahkan ke Dashboard Utama
        _targetScreen =
            const HomeScreen(); // ⚠️ Sesuaikan dengan nama class Halaman Utama kamu
      } else {
        // Jika tidak ada sesi login aktif, arahkan user ke halaman login
        _targetScreen = const LoginScreen();
      }
    } catch (e) {
      _targetScreen = const LoginScreen();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B7A42), Color(0xFF064D2E)],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 64,
                  color: Colors.white,
                ),
                SizedBox(height: 16),
                Text(
                  'MoneyTrack',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 24),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2.5,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _targetScreen;
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint('⚠️ Supabase credentials not provided. Set SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.');
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: anonKey,
        debug: kDebugMode,
      );
      debugPrint(' Supabase successfully initialized.');
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}

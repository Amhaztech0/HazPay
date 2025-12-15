import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'config.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'utils/native_deeplink.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/unified_notification_handler.dart';
import 'services/local_message_cache_service.dart';
import 'services/offline_message_processor.dart';
import 'services/version_service.dart';
import 'services/call_manager.dart';
import 'providers/theme_provider.dart';
import 'design/hazpay_design_system.dart';
import 'widgets/version_update_dialog.dart';
import '../../design/hazpay_colors.dart';
// Global Supabase client
final supabase = Supabase.instance.client;

// Global navigator key for routing from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📬 Background message received: ${message.messageId}');
  debugPrint('📋 Background message data: ${message.data}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Initialize local message cache
  try {
    await LocalMessageCacheService().initialize();
    debugPrint('✅ Local message cache initialized');
  } catch (e) {
    debugPrint('⚠️ Local cache init failed: $e');
  }

  // Initialize offline message processor (for auto-retry when connectivity restores)
  try {
    await OfflineMessageProcessor().initialize();
    debugPrint('✅ Offline message processor initialized');
  } catch (e) {
    debugPrint('⚠️ Offline processor init failed: $e');
  }

  // Initialize Firebase and notifications
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService().initialize();
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase init failed: $e');
  }

  // Initialize AdMob (best effort - continue if fails)
  try {
    await MobileAds.instance.initialize();
    debugPrint('✅ AdMob initialized');
  } catch (e) {
    debugPrint('⚠️ AdMob init failed: $e');
  }

  // Set up global error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  // Run the app
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const ZinChatApp(),
    ),
  );
}

class ZinChatApp extends StatefulWidget {
  const ZinChatApp({super.key});

  @override
  State<ZinChatApp> createState() => _ZinChatAppState();
}

class _ZinChatAppState extends State<ZinChatApp> {
  @override
  void initState() {
    super.initState();
    // Initialize unified notification handler
    _initializeNotifications();
    // Initialize call manager for incoming calls
    _initializeCallManager();
  }

  Future<void> _initializeNotifications() async {
    try {
      await UnifiedNotificationHandler().initialize();
      debugPrint('✅ Unified notification handler initialized');
    } catch (e) {
      debugPrint('❌ Error initializing notification handler: $e');
    }
  }

  Future<void> _initializeCallManager() async {
    try {
      // Wait a bit for navigator to be ready
      await Future.delayed(const Duration(milliseconds: 500));
      await CallManager().initialize(navigatorKey);
      debugPrint('✅ Call manager initialized');
    } catch (e) {
      debugPrint('❌ Error initializing call manager: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final appTheme = themeProvider.currentTheme;
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'ZinChat',
          debugShowCheckedModeBanner: false,
          theme: appTheme.toMaterial3ThemeData(),
          home: const AuthChecker(),
        );
      },
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
    // Handle deep links
    _initDeepLinkListener();
  }

  void _initDeepLinkListener() async {
    // Get initial link if app was opened from a link
    NativeDeepLink.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingUri(uri);
    });
    // Listen for future links
    NativeDeepLink.startListening((uri) {
      _handleIncomingUri(uri);
    });
  }

  void _handleIncomingUri(String uriString) async {
    try {
      final uri = Uri.parse(uriString);
      final token = uri.queryParameters['token'] ?? uri.queryParameters['otp'];
      final email = uri.queryParameters['email'];
      if (token != null && email != null) {
        await AuthService().verifyEmailOTP(email, token);
        final profile = await AuthService().getCurrentUserProfile();
        if (profile == null) {
          debugPrint('Warning: Profile not found after verification');
        }
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to handle incoming uri: $e');
    }
  }

  Future<void> _checkAuth() async {
    try {
      // Check authentication with timeout (5 seconds)
      // If timeout occurs, allow offline access if user was previously authenticated
      final session = supabase.auth.currentSession;

      if (session != null) {
        debugPrint('✅ User authenticated: ${session.user.email}');
        await _checkVersionAndProceed();
      } else {
        debugPrint('❌ No authenticated session found');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Auth check error: $e');
      // On network error, check if we can load cached session
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

/*************  ✨ Windsurf Command ⭐  *************/
  /// Checks for version updates with a timeout of 5 seconds.
  ///
  /// If a version update is available, shows a dialog with an option to update or dismiss.
  /// If the update is required, blocks the app until the update is installed.
  ///
  /// If the update is optional, allows the user to dismiss the dialog and proceed to the home screen.
  /// If the version check fails (e.g., due to network error), shows the home screen if the user is authenticated.
  ///
  /// Logs version check events for analytics purposes.
/*******  d3748b75-7605-4bba-ad17-905603084185  *******/
  Future<void> _checkVersionAndProceed() async {
    try {
      final versionService = VersionService();
      // Check version with timeout - don't block app if network is slow
      final versionInfo = await versionService
          .checkForUpdate()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );

      if (!mounted) return;

      if (versionInfo != null && versionInfo.isUpdateAvailable) {
        await versionService.logVersionCheck(
          versionInfo.currentVersion,
          versionInfo.latestVersion,
          true,
        );

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: !versionInfo.isRequired,
            builder: (context) => VersionUpdateDialog(
              versionInfo: versionInfo,
              onDismiss: () {
                if (!versionInfo.isRequired && mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                }
              },
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking version: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<ThemeProvider>().currentTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.primaryGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 120,
                  height: 120,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: HazPayColors.primary,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Image.asset(
                    'assets/images/owl_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ZinChat',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Zance da abokai',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


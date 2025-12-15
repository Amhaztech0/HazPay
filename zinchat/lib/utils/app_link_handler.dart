import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import '../services/auth_service.dart';

/// Small AppLinks-based handler. It listens for incoming app links and
/// attempts to complete sign-in flows: if an OTP token + email are present
/// it will call verifyEmailOTP; if fragment contains access_token it logs it
/// so you can wire a session setter later.
class AppLinkHandler extends StatefulWidget {
  final Widget child;
  const AppLinkHandler({required this.child, super.key});

  @override
  State<AppLinkHandler> createState() => _AppLinkHandlerState();
}

class _AppLinkHandlerState extends State<AppLinkHandler> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _sub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Cold start
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _processUri(initialUri);
      }
    } catch (e) {
      debugPrint('getInitialLink error: $e');
    }

    // Listen for links while app is running
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _processUri(uri);
    }, onError: (err) {
      debugPrint('uriLinkStream error: $err');
    });
  }

  Future<void> _processUri(Uri uri) async {
    debugPrint('App link received: $uri');

    // If link contains fragment with tokens (e.g., access_token=...), log it
    if (uri.fragment.isNotEmpty) {
      final frag = Uri.splitQueryString(uri.fragment);
      if (frag.containsKey('access_token')) {
        debugPrint('Received access token in fragment: ${frag['access_token']}');
        // TODO: call Supabase set session if API available
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Received auth token (see logs)')),
          );
        }
        return;
      }
    }

    // If link contains ?token= and ?email=, verify email OTP
    final token = uri.queryParameters['token'] ?? uri.queryParameters['otp'];
    final email = uri.queryParameters['email'];
    if (token != null && email != null) {
      try {
        await AuthService().verifyEmailOTP(email, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signed in via magic link')),
          );
        }
      } catch (e) {
        debugPrint('verifyEmailOTP failed: $e');
      }
    } else {
      debugPrint('No token/email params found in uri: $uri');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

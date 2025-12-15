// Deep link handler removed because of plugin compatibility issues.
// The app still registers the custom URL scheme in AndroidManifest and
// Info.plist so links like `zinchat://auth-callback` will open the app.
// To complete the sign-in automatically you can add a small handler
// using a package compatible with your SDK (for example `app_links`)
// or implement platform channels to read the initial intent/URL.

import 'package:flutter/widgets.dart';

class DeepLinkHandlerPlaceholder extends StatelessWidget {
  final Widget child;
  const DeepLinkHandlerPlaceholder({required this.child, super.key});

  @override
  Widget build(BuildContext context) => child;
}

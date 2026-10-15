import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_style.dart';
import '../services/facebook_auth_config.dart';
import '../services/google_auth_config.dart';

/// Explains the Google Cloud Console fix when OAuth is rejected.
///
/// `origin_mismatch` / `redirect_uri_mismatch` are configuration problems, not
/// user errors — showing a bare red snackbar sends people hunting for bugs in
/// their own input. This dialog names the exact screen and field to edit.
Future<void> showGoogleAuthSetupDialog(
  BuildContext context, {
  required String reason,
  bool native = false,
}) {
  final steps = native
      ? GoogleAuthConfig.nativeSetupSteps
      : GoogleAuthConfig.webSetupSteps;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.settings_suggest_rounded,
        color: AppStyle.coral,
        size: 30,
      ),
      title: const Text('Login Google belum siap'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppStyle.ink,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );
}

/// Explains the Firebase and Meta Developer Console fix when Facebook Login is not ready.
Future<void> showFacebookAuthSetupDialog(
  BuildContext context, {
  required String reason,
}) {
  final steps = FacebookAuthConfig.setupSteps;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.settings_suggest_rounded,
        color: AppStyle.coral,
        size: 30,
      ),
      title: const Text('Login Facebook belum siap'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppStyle.ink,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );
}

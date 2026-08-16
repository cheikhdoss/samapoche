import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:samapoche/l10n/l10n.dart';
import 'package:samapoche/router.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/widgets/widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = context.isDark ? AppDark.accent : AppColors.accent;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.savings_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.appName,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.03,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tagline,
              style: TextStyle(
                fontSize: 17,
                color: context.isDark ? AppDark.muted : AppColors.muted,
              ),
            ),
            const Spacer(),
            AppButton(
              label: l10n.signIn,
              primary: true,
              large: true,
              onPressed: () => context.go(Routes.login),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: l10n.createAccount,
              outline: true,
              large: true,
              onPressed: () => context.go(Routes.signup),
            ),
          ],
        ),
      ),
    );
  }
}

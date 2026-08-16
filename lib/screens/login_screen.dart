import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:samapoche/l10n/l10n.dart';
import 'package:samapoche/router.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPass = false;
  bool _remember = false;
  bool _loading = false;
  String? _emailError;
  String? _passError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = context.l10n;
    final email = _email.text.trim();
    final pass = _password.text;
    setState(() {
      _emailError = email.isEmpty ? l10n.emailRequired : null;
      _passError = pass.isEmpty ? l10n.passwordRequired : null;
    });
    if (_emailError != null || _passError != null) return;

    setState(() => _loading = true);
    final err = await context.read<AppState>().login(email, pass);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      showToast(context, err, ToastType.error);
    } else {
      showToast(context, l10n.loginSuccess, ToastType.success);
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = context.isDark;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final meta = isDark ? AppDark.meta : AppColors.meta;
    final accent = isDark ? AppDark.accent : AppColors.accent;
    final muted = isDark ? AppDark.muted : AppColors.muted;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => context.go(Routes.welcome),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      l10n.back,
                      style: const TextStyle(fontSize: 14, fontFamily: 'Inter'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.welcomeTitle,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.loginSubtitle,
              style: TextStyle(fontSize: 16, color: muted),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.email,
                labelStyle: TextStyle(
                  color: meta,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                floatingLabelStyle: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w500,
                ),
                errorText: _emailError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: !_showPass,
              decoration: InputDecoration(
                labelText: l10n.password,
                labelStyle: TextStyle(
                  color: meta,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                floatingLabelStyle: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w500,
                ),
                errorText: _passError,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                    color: meta,
                  ),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _remember = !_remember),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _remember ? accent : Colors.transparent,
                          border: Border.all(
                            color: _remember ? accent : borderSoft,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _remember
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.rememberMe,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppDark.fg2 : AppColors.fg2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      showToast(context, l10n.resetEmailSent, ToastType.info),
                  child: Text(
                    l10n.forgotPassword,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppButton(
              label: l10n.continueButton,
              primary: true,
              loading: _loading,
              onPressed: _login,
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                l10n.noAccount,
                style: TextStyle(fontSize: 14, color: muted),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: GestureDetector(
                onTap: () => context.go(Routes.signup),
                child: Text(
                  l10n.createAccount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: borderSoft)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    l10n.orConnectWith,
                    style: TextStyle(fontSize: 12, color: meta),
                  ),
                ),
                Expanded(child: Divider(color: borderSoft)),
              ],
            ),
            const SizedBox(height: 14),
            AppButton(
              label: 'Apple',
              ghost: true,
              onPressed: () =>
                  showToast(context, l10n.appleSoon, ToastType.info),
              icon: const Icon(Icons.apple_rounded, size: 18),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Google',
              ghost: true,
              onPressed: () =>
                  showToast(context, l10n.googleSoon, ToastType.info),
              icon: const Icon(
                Icons.g_mobiledata_rounded,
                size: 24,
                color: Color(0xFF4285F4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

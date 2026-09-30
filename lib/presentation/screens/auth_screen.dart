import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/app_typography.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../data/services/cloud_sync_service.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/circa_pulsing_logo.dart';
import '../widgets/circa_text_field.dart';
import '../widgets/kalkan_ui.dart';
import 'account_setup_screen.dart';
import 'main_shell.dart';

class AuthScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const AuthScreen({super.key, required this.bleBridge});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || pass.isEmpty || (_isSignUp && name.isEmpty)) {
      setState(() => _errorMessage = AppStrings.tr('auth_err_empty'));
      return;
    }

    if (!email.contains('@')) {
      setState(() => _errorMessage = AppStrings.tr('auth_err_email'));
      return;
    }

    if (pass.length < 6) {
      setState(() => _errorMessage = AppStrings.tr('auth_err_pass_length'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool navigated = false;
    try {
      if (Firebase.apps.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Облачный сервис авторизации недоступен. Проверьте интернет или конфигурацию.';
          });
        }
        return;
      }

      String? firebaseDisplayName;
      try {
        if (_isSignUp) {
          final cred = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: email,
                password: pass,
              )
              .timeout(const Duration(seconds: 10));
          if (name.isNotEmpty) {
            await cred.user?.updateDisplayName(name).timeout(const Duration(seconds: 5));
          }
          firebaseDisplayName = name;
        } else {
          final cred = await FirebaseAuth.instance
              .signInWithEmailAndPassword(
                email: email,
                password: pass,
              )
              .timeout(const Duration(seconds: 10));
          firebaseDisplayName = cred.user?.displayName;
        }
      } on FirebaseAuthException catch (e) {
        debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
              _errorMessage = 'Неверный email или пароль.';
            } else if (e.code == 'email-already-in-use') {
              _errorMessage = 'Этот email уже занят. Нажмите «Войти».';
            } else if (e.code == 'network-request-failed') {
              _errorMessage = 'Ошибка сети. Проверьте подключение к интернету.';
            } else {
              _errorMessage = e.message ?? 'Ошибка авторизации (${e.code})';
            }
          });
        }
        return;
      } on TimeoutException {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Превышено время ожидания ответа сервера. Попробуйте еще раз.';
          });
        }
        return;
      } catch (e) {
        debugPrint('Auth error: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Не удалось авторизоваться: $e';
          });
        }
        return;
      }

      UserProfile effectiveProfile;
      if (!_isSignUp) {
        // Вход в существующий аккаунт:
        // Сначала пробуем получить данные из облака, чтобы НЕ затирать профиль и не спрашивать пол/возраст повторно
        UserProfile? remoteProfile;
        try {
          remoteProfile = await CloudSyncService.pullProfile();
        } catch (e) {
          debugPrint('Auth pullProfile note: $e');
        }

        final currentProfile = await UserProfileRepository.loadProfile();
        if (remoteProfile != null) {
          effectiveProfile = remoteProfile.copyWith(
            email: email,
            name: remoteProfile.name.isNotEmpty
                ? remoteProfile.name
                : (firebaseDisplayName?.isNotEmpty == true ? firebaseDisplayName! : currentProfile.name),
            isAuthenticated: true,
          );
        } else {
          effectiveProfile = currentProfile.copyWith(
            email: email,
            name: firebaseDisplayName?.isNotEmpty == true
                ? firebaseDisplayName!
                : (currentProfile.name.isNotEmpty ? currentProfile.name : ''),
            isAuthenticated: true,
          );
        }
        await UserProfileRepository.saveProfile(effectiveProfile);
        unawaited(CloudSyncService.afterLogin(effectiveProfile).catchError((e) {
          debugPrint('CloudSync background note: $e');
        }));
      } else {
        // Регистрация нового аккаунта:
        // Явно сбрасываем hasCompletedProfile в false, чтобы новый пользователь обязательно прошёл AccountSetupScreen
        effectiveProfile = UserProfile(
          email: email,
          name: name.isNotEmpty ? name : (firebaseDisplayName ?? ''),
          isAuthenticated: true,
          hasCompletedProfile: false,
        );
        await UserProfileRepository.saveProfile(effectiveProfile);
        unawaited(CloudSyncService.pushProfile(effectiveProfile).catchError((e) {
          debugPrint('CloudSync pushProfile note: $e');
        }));
      }

      navigated = true;
      if (!mounted) return;

      // Если это вход в существующий аккаунт с уже заполненным профилем — сразу в MainShell
      // Если это регистрация ИЛИ профиль ещё не заполнен — обязательно в AccountSetupScreen
      if (!_isSignUp && effectiveProfile.hasCompletedProfile && effectiveProfile.name.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainShell(bleBridge: widget.bleBridge),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AccountSetupScreen(bleBridge: widget.bleBridge),
          ),
        );
      }
    } finally {
      if (!navigated && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: palette.bg,
          body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: KalkanUi.pagePadding, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),

                          // Богатое пульсирующее лого КАЛКАН
                          const Center(
                            child: CircaPulsingLogo(
                              size: 110,
                              primaryColor: AppColors.sage,
                              secondaryColor: AppColors.amber,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Заголовок экрана входа
                          Text(
                            _isSignUp
                                ? AppStrings.tr('auth_signup_title', language)
                                : AppStrings.tr('auth_login_title', language),
                            textAlign: TextAlign.center,
                            style: AppTypography.metricMedium(palette.fg),
                          ),
                          const SizedBox(height: 24),

                          // Форма ввода
                          if (_isSignUp) ...[
                            CircaTextField(
                              label: AppStrings.tr('auth_name_label', language),
                              hint: AppStrings.tr('auth_name_hint', language),
                              controller: _nameController,
                              prefixIcon: Icon(Icons.person_outline, color: palette.muted, size: 20),
                            ),
                            const SizedBox(height: 14),
                          ],

                          CircaTextField(
                            label: AppStrings.tr('auth_email_label', language),
                            hint: 'name@example.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icon(Icons.alternate_email, color: palette.muted, size: 20),
                          ),
                          const SizedBox(height: 14),

                          CircaTextField(
                            label: AppStrings.tr('auth_password_label', language),
                            hint: '••••••••',
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            prefixIcon: Icon(Icons.lock_outline, color: palette.muted, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: palette.muted,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),

                          // Ошибка
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.rose.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                                border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.rose, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: AppTypography.bodyMuted(AppColors.rose),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 22),

                          // Кнопка входа
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.sage,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(44, KalkanUi.minTapTarget),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _isSignUp
                                        ? AppStrings.tr('auth_button_signup', language)
                                        : AppStrings.tr('auth_button_login', language),
                                    style: AppTypography.buttonLabel.copyWith(color: Colors.white, letterSpacing: 1.0),
                                  ),
                          ),

                          const SizedBox(height: 12),

                          // Переключение Вход / Регистрация
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                                _errorMessage = null;
                              });
                            },
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, KalkanUi.minTapTarget),
                            ),
                            child: Text(
                              _isSignUp
                                  ? AppStrings.tr('auth_to_login', language)
                                  : AppStrings.tr('auth_to_signup', language),
                              style: AppTypography.bodySemibold(palette.secondary),
                            ),
                          ),

                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: 8,
                    right: 16,
                    child: TextButton(
                      onPressed: () => AppLocaleNotifier.toggleLanguage(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, KalkanUi.minTapTarget),
                      ),
                      child: Text(
                        '${language.flag} ${language.shortTitle}',
                        style: AppTypography.monoLabel(palette.secondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        );
      },
    );
  }
}

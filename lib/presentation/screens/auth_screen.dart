import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../data/services/cloud_sync_service.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/circa_pulsing_logo.dart';
import '../widgets/circa_text_field.dart';
import 'main_shell.dart';

class AuthScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const AuthScreen({super.key, required this.bleBridge});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  final _emailController = TextEditingController(text: 'barys@circa.health');
  final _passwordController = TextEditingController(text: 'circabiotracker2026');
  final _nameController = TextEditingController(text: 'Алихан');
  Gender _selectedGender = Gender.male;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    UserProfileRepository.loadProfile().then((p) {
      if (mounted) {
        setState(() {
          _selectedGender = p.gender;
        });
      }
    });
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

    String? firebaseDisplayName;
    bool navigated = false;

    try {
      if (Firebase.apps.isNotEmpty) {
        if (_isSignUp) {
          final cred = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: email,
                password: pass,
              )
              .timeout(const Duration(seconds: 8));
          if (name.isNotEmpty) {
            await cred.user?.updateDisplayName(name).timeout(const Duration(seconds: 4));
          }
          firebaseDisplayName = name;
        } else {
          final cred = await FirebaseAuth.instance
              .signInWithEmailAndPassword(
                email: email,
                password: pass,
              )
              .timeout(const Duration(seconds: 8));
          firebaseDisplayName = cred.user?.displayName;
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 200));
        firebaseDisplayName = name.isNotEmpty ? name : 'Искандер';
      }

      // 1. Немедленно сохраняем локальный профиль (автономная надежность)
      final currentProfile = await UserProfileRepository.loadProfile();
      final updatedProfile = currentProfile.copyWith(
        email: email,
        name: firebaseDisplayName ?? (_isSignUp ? name : (currentProfile.name.isNotEmpty ? currentProfile.name : 'Искандер')),
        gender: _selectedGender,
        cycleDay: _selectedGender == Gender.female ? (currentProfile.cycleDay ?? 14) : null,
        lastPeriodStartDate: _selectedGender == Gender.female
            ? (currentProfile.lastPeriodStartDate ?? DateTime.now().subtract(const Duration(days: 14)))
            : null,
        isAuthenticated: true,
      );
      await UserProfileRepository.saveProfile(updatedProfile);

      // 2. Фоновая облачная синхронизация БЕЗ блокировки UI (не подвешивает переход)
      unawaited(CloudSyncService.afterLogin(updatedProfile).catchError((e) {
        debugPrint('CloudSync background note: $e');
      }));

      navigated = true;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainShell(bleBridge: widget.bleBridge),
        ),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      String userFriendly;
      switch (e.code) {
        case 'user-not-found':
          userFriendly = 'Пользователь не найден. Переключитесь на «Создать аккаунт».';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          userFriendly = 'Неверный пароль или email. Проверьте правильность ввода.';
          break;
        case 'email-already-in-use':
          userFriendly = 'Этот email уже зарегистрирован. Нажмите «Уже есть аккаунт? Войти».';
          break;
        case 'weak-password':
          userFriendly = 'Пароль слишком простой (минимум 6 символов).';
          break;
        case 'invalid-email':
          userFriendly = 'Некорректный формат email адреса.';
          break;
        case 'network-request-failed':
          userFriendly = 'Ошибка сети. Проверьте соединение или используйте «Быстрый вход».';
          break;
        default:
          userFriendly = e.message ?? 'Ошибка авторизации (${e.code})';
      }
      if (mounted) {
        setState(() => _errorMessage = userFriendly);
      }
    } on TimeoutException catch (_) {
      debugPrint('Auth request timed out');
      if (mounted) {
        setState(() => _errorMessage = 'Таймаут соединения с сервером. Воспользуйтесь кнопкой «Быстрый вход».');
      }
    } catch (e) {
      debugPrint('Auth unexpected error: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Ошибка входа: $e');
      }
    } finally {
      if (!navigated && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _quickGuestLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool navigated = false;
    try {
      final currentProfile = await UserProfileRepository.loadProfile();
      final updatedProfile = currentProfile.copyWith(
        name: currentProfile.name.isNotEmpty ? currentProfile.name : 'Искандер',
        email: currentProfile.email.isNotEmpty ? currentProfile.email : 'barys@kalkan.sport',
        gender: _selectedGender,
        isAuthenticated: true,
      );
      await UserProfileRepository.saveProfile(updatedProfile);

      // Фоновая синхронизация
      unawaited(CloudSyncService.afterLogin(updatedProfile).catchError((e) {
        debugPrint('Guest sync background note: $e');
      }));

      navigated = true;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainShell(bleBridge: widget.bleBridge),
        ),
      );
    } catch (e) {
      debugPrint('Quick guest login error: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Сбой локального входа: $e');
      }
    } finally {
      if (!navigated && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: AppColors.stage,
          body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 24),

                          // Богатое пульсирующее лого КАЛКАН
                          Center(
                            child: CircaPulsingLogo(
                              size: 110,
                              primaryColor: AppColors.amber,
                              secondaryColor: AppColors.sage,
                            ),
                          ),
                          SizedBox(height: 20),

                          // Заголовок экрана входа
                          Text(
                            _isSignUp
                                ? AppStrings.tr('auth_signup_title', language)
                                : AppStrings.tr('auth_login_title', language),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.fg,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 24),

                          // Форма ввода
                          if (_isSignUp) ...[
                            CircaTextField(
                              label: AppStrings.tr('auth_name_label', language),
                              hint: AppStrings.tr('auth_name_hint', language),
                              controller: _nameController,
                              prefixIcon: Icon(Icons.person_outline, color: AppColors.muted, size: 20),
                            ),
                            SizedBox(height: 14),
                          ],

                          CircaTextField(
                            label: AppStrings.tr('auth_email_label', language),
                            hint: 'barys@circa.health',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icon(Icons.alternate_email, color: AppColors.muted, size: 20),
                          ),
                          SizedBox(height: 14),

                          CircaTextField(
                            label: AppStrings.tr('auth_password_label', language),
                            hint: '••••••••',
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            prefixIcon: Icon(Icons.lock_outline, color: AppColors.muted, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.muted,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),

                          // Ошибка
                          if (_errorMessage != null) ...[
                            SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.rose.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: AppColors.rose, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(color: AppColors.rose, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          SizedBox(height: 22),

                          // Кнопка входа
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.amber,
                              foregroundColor: AppColors.stage,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.stage),
                                  )
                                : Text(
                                    _isSignUp
                                        ? AppStrings.tr('auth_button_signup', language)
                                        : AppStrings.tr('auth_button_login', language),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),

                          SizedBox(height: 12),

                          // Переключение Вход / Регистрация
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                                _errorMessage = null;
                              });
                            },
                            child: Text(
                              _isSignUp
                                  ? AppStrings.tr('auth_to_login', language)
                                  : AppStrings.tr('auth_to_signup', language),
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          SizedBox(height: 16),

                          // Кнопка быстрого автономного входа (для тестов и автономного режима)
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _quickGuestLogin,
                            icon: Icon(Icons.flash_on, color: AppColors.sage, size: 16),
                            label: Text(
                              'БЫСТРЫЙ ВХОД (АВТОНОМНЫЙ РЕЖИМ)',
                              style: TextStyle(
                                color: AppColors.sage,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.line),
                              backgroundColor: AppColors.surface,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      onPressed: () {
                        final next = language == AppLanguage.kyrgyz
                            ? AppLanguage.russian
                            : AppLanguage.kyrgyz;
                        AppLocaleNotifier.setLanguage(next);
                      },
                      child: Text(
                        language == AppLanguage.kyrgyz ? 'KY / RU' : 'RU / KY',
                        style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w600),
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

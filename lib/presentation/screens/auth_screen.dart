import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/circa_ai_language_pill.dart';
import '../widgets/circa_film_grain.dart';
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
    try {
      if (Firebase.apps.isNotEmpty) {
        if (_isSignUp) {
          final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: pass,
          );
          if (name.isNotEmpty) {
            await cred.user?.updateDisplayName(name);
          }
          firebaseDisplayName = name;
        } else {
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: pass,
          );
          firebaseDisplayName = cred.user?.displayName;
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
        firebaseDisplayName = name.isNotEmpty ? name : 'Искандер';
      }
    } catch (e) {
      // Автономный fallback: если нет сети или Firebase не настроен, работаем 100% локально
      debugPrint('Auth offline fallback mode: $e');
      firebaseDisplayName = name.isNotEmpty ? name : email.split('@').first;
    }

    // Сохраняем профиль локально (автономная база данных SharedPreferences)
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

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainShell(bleBridge: widget.bleBridge),
      ),
    );
  }

  Future<void> _quickGuestLogin() async {
    setState(() => _isLoading = true);
    final currentProfile = await UserProfileRepository.loadProfile();
    final updatedProfile = currentProfile.copyWith(
      name: currentProfile.name.isNotEmpty ? currentProfile.name : 'Искандер',
      email: currentProfile.email.isNotEmpty ? currentProfile.email : 'barys@kalkan.sport',
      isAuthenticated: true,
    );
    await UserProfileRepository.saveProfile(updatedProfile);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainShell(bleBridge: widget.bleBridge),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: AppColors.stage,
          body: CircaFilmGrainBackground(
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),

                          // Богатое пульсирующее лого КАЛКАН
                          const Center(
                            child: CircaPulsingLogo(
                              size: 110,
                              primaryColor: AppColors.amber,
                              secondaryColor: AppColors.sage,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Заголовок экрана входа
                          Text(
                            _isSignUp
                                ? AppStrings.tr('auth_signup_title', language)
                                : AppStrings.tr('auth_login_title', language),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.fg,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Форма ввода
                          if (_isSignUp) ...[
                            CircaTextField(
                              label: AppStrings.tr('auth_name_label', language),
                              hint: AppStrings.tr('auth_name_hint', language),
                              controller: _nameController,
                              prefixIcon: const Icon(Icons.person_outline, color: AppColors.muted, size: 20),
                            ),
                            const SizedBox(height: 14),
                          ],

                          CircaTextField(
                            label: AppStrings.tr('auth_email_label', language),
                            hint: 'barys@circa.health',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.alternate_email, color: AppColors.muted, size: 20),
                          ),
                          const SizedBox(height: 14),

                          CircaTextField(
                            label: AppStrings.tr('auth_password_label', language),
                            hint: '••••••••',
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted, size: 20),
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
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.rose.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.rose, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: AppColors.rose, fontSize: 12),
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
                              backgroundColor: AppColors.amber,
                              foregroundColor: AppColors.stage,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.stage),
                                  )
                                : Text(
                                    _isSignUp
                                        ? AppStrings.tr('auth_button_signup', language)
                                        : AppStrings.tr('auth_button_login', language),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
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
                            child: Text(
                              _isSignUp
                                  ? AppStrings.tr('auth_to_login', language)
                                  : AppStrings.tr('auth_to_signup', language),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Кнопка быстрого автономного входа (для тестов и автономного режима)
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _quickGuestLogin,
                            icon: const Icon(Icons.flash_on, color: AppColors.sage, size: 16),
                            label: const Text(
                              'БЫСТРЫЙ ВХОД (АВТОНОМНЫЙ РЕЖИМ)',
                              style: TextStyle(
                                color: AppColors.sage,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.line),
                              backgroundColor: AppColors.surface,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Переключатель языка (AI Oval Capsule)
                  const Positioned(
                    top: 10,
                    right: 18,
                    child: CircaAiLanguagePill(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/user_profile_repository.dart';
import '../widgets/circa_breathing_retina.dart';
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
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

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
      setState(() => _errorMessage = 'Заполните все обязательные поля');
      return;
    }

    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Введите корректный email адрес');
      return;
    }

    if (pass.length < 6) {
      setState(() => _errorMessage = 'Пароль должен содержать минимум 6 символов');
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
        await Future.delayed(const Duration(milliseconds: 400));
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Ошибка авторизации Firebase';
      if (e.code == 'user-not-found') {
        msg = 'Пользователь с таким email не найден';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Неверный пароль или учетные данные';
      } else if (e.code == 'email-already-in-use') {
        msg = 'Данный email уже зарегистрирован в системе';
      } else if (e.code == 'weak-password') {
        msg = 'Слишком простой пароль (минимум 6 символов)';
      } else if (e.code == 'invalid-email') {
        msg = 'Некорректный формат email адреса';
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
      }
      return;
    } catch (e) {
      debugPrint('Firebase Auth notice (offline fallback): $e');
    }

    final currentProfile = await UserProfileRepository.loadProfile();
    final updatedProfile = currentProfile.copyWith(
      email: email,
      name: firebaseDisplayName ?? (_isSignUp ? name : currentProfile.name),
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

  Future<void> _loginDemo() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    await UserProfileRepository.setAuthenticated(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainShell(bleBridge: widget.bleBridge),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.stage,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Живая дышащая био-ретина CIRCA ONE (респираторный цикл 4.8 сек)
                const Center(
                  child: CircaBreathingRetina(
                    size: 145,
                    isScanning: true,
                    accentColor: AppColors.sage,
                  ),
                ),
                const SizedBox(height: 22),

                // Заголовок бренда
                const Text(
                  'CIRCA ONE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isSignUp ? 'Создание аккаунта' : 'Вход в биосистему',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Синхронизация биометрии браслета с Барыс-Батыром',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Форма ввода
                if (_isSignUp) ...[
                  CircaTextField(
                    label: 'Ваше имя',
                    hint: 'Батыр / Алихан',
                    controller: _nameController,
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.muted, size: 20),
                  ),
                  const SizedBox(height: 16),
                ],

                CircaTextField(
                  label: 'Email',
                  hint: 'user@domain.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.mail_outline, color: AppColors.muted, size: 20),
                ),
                const SizedBox(height: 16),

                CircaTextField(
                  label: 'Пароль',
                  hint: '••••••••',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.muted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

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
                          _isSignUp ? 'ЗАРЕГИСТРИРОВАТЬСЯ' : 'ВОЙТИ В СИСТЕМУ',
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
                        ? 'Уже есть аккаунт? Войти'
                        : 'Нет аккаунта? Создать новый профиль',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(color: AppColors.line, height: 1),
                const SizedBox(height: 20),

                // Быстрый гостевой вход в демо-режиме
                OutlinedButton.icon(
                  onPressed: _loginDemo,
                  icon: const Icon(Icons.bolt, color: AppColors.sage, size: 18),
                  label: const Text(
                    'БЫСТРЫЙ ДЕМО-ВХОД БЕЗ ПАРОЛЯ',
                    style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.line),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

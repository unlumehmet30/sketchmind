import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/dummy/avatars.dart';
import '../../data/services/local_user_service.dart';
import '../theme/playful_theme.dart';
import '../../router/app_router.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen>
    with SingleTickerProviderStateMixin {
  final LocalUserService _userService = LocalUserService();

  late TabController _tabController;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorMessage;
  String? _selectedAvatarUrl;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth(bool isLogin) async {
    if (_isSubmitting) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Kullanıcı adı ve şifre boş bırakılamaz.';
      });
      return;
    }

    if (!isLogin) {
      final usernameError = LocalUserService.validateUsername(username);
      if (usernameError != null) {
        setState(() => _errorMessage = usernameError);
        return;
      }

      final passwordError = LocalUserService.validatePassword(password);
      if (passwordError != null) {
        setState(() => _errorMessage = passwordError);
        return;
      }
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    if (isLogin) {
      final loginResult =
          await _userService.loginUserDetailed(username, password);
      if (!mounted) return;

      if (loginResult.success) {
        context.go(AppRoutes.home);
      } else {
        final lockMessage = loginResult.isLockedOut
            ? 'Çok fazla yanlış deneme. ${loginResult.remainingLockSeconds} sn bekleyin.'
            : 'Kullanıcı adı veya şifre yanlış.';
        setState(() => _errorMessage = lockMessage);
      }
      setState(() => _isSubmitting = false);
      return;
    }

    final registerSuccess = await _userService.registerUser(
      username,
      password,
      avatarUrl: _selectedAvatarUrl,
    );
    if (!mounted) return;

    if (registerSuccess) {
      context.go(AppRoutes.home);
    } else {
      setState(() {
        _errorMessage = 'Bu kullanıcı adı zaten kayıtlı olabilir.';
      });
    }
    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: PlayfulPalette.appBackground),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('SketchMind Hesap'),
          automaticallyImplyLeading: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: PlayfulPalette.grape,
            indicatorWeight: 3,
            labelColor: const Color(0xFF524D9A),
            unselectedLabelColor: const Color(0xFF8080A6),
            tabs: const [
              Tab(text: 'Giriş Yap'),
              Tab(text: 'Kayıt Ol'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAuthForm(isLogin: true),
            _buildAuthForm(isLogin: false),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthForm({required bool isLogin}) {
    final helperText = isLogin
        ? "Kayıtlı değilsen 'Kayıt Ol' sekmesini kullan."
        : 'Şifre en az 6 karakter olmalı, harf ve rakam içermeli.';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF9CB9FF),
                    Color(0xFFAF9FFF),
                    Color(0xFFFFB5E1)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                isLogin
                    ? 'Tekrar hoş geldin!'
                    : 'Yeni bir macera profili oluşturalım',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isLogin) ...[
                      Center(
                        child: GestureDetector(
                          onTap: _showAvatarSelectionDialog,
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: const Color(0xFFF1EBFF),
                            backgroundImage: _selectedAvatarUrl != null
                                ? CachedNetworkImageProvider(
                                    _selectedAvatarUrl!)
                                : null,
                            child: _selectedAvatarUrl == null
                                ? const Icon(Icons.add_a_photo,
                                    size: 30, color: Color(0xFF8D84C8))
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Avatar Seç',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF5D62B5)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      maxLength: 24,
                      autofillHints: const [AutofillHints.username],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9_çğıöşüÇĞİÖŞÜ]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı Adı (Çocuk Adı)',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.person, color: Color(0xFF6E74C8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _handleAuth(isLogin),
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        border: const OutlineInputBorder(),
                        prefixIcon:
                            const Icon(Icons.lock, color: Color(0xFF6E74C8)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFC05A87),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ElevatedButton(
                      onPressed:
                          _isSubmitting ? null : () => _handleAuth(isLogin),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: isLogin
                            ? const Color(0xFF8B95E8)
                            : const Color(0xFFB28FFF),
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                              style: const TextStyle(fontSize: 18),
                            ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      helperText,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarSelectionDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: true,
          builder: (context, scrollController) {
            return Material(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: DefaultTabController(
                length: predefinedAvatars.length,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Bir Avatar Seç',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    TabBar(
                      isScrollable: true,
                      labelColor: const Color(0xFF7267BF),
                      unselectedLabelColor: const Color(0xFF8F92A7),
                      tabs: predefinedAvatars
                          .map((category) => Tab(text: category.name))
                          .toList(),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: predefinedAvatars.map((category) {
                          return GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: category.imageUrls.length,
                            itemBuilder: (context, index) {
                              final url = category.imageUrls[index];
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedAvatarUrl = url);
                                  Navigator.of(sheetContext).pop();
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      placeholder: (context, _) => const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                                      errorWidget: (context, _, __) =>
                                          const Icon(Icons.error),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

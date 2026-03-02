import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/local_user_service.dart';
import '../../router/app_router.dart';

class ProfileVerificationScreen extends StatefulWidget {
  const ProfileVerificationScreen({super.key});

  @override
  State<ProfileVerificationScreen> createState() =>
      _ProfileVerificationScreenState();
}

class _ProfileVerificationScreenState extends State<ProfileVerificationScreen> {
  final LocalUserService _userService = LocalUserService();
  List<String> _availableUsernames = [];
  final Map<String, String> _displayNameByUser = <String, String>{};
  final Map<String, String> _avatarByUser = <String, String>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsernames();
  }

  Future<void> _loadUsernames() async {
    final usernames = await _userService.getAllRegisteredUsernames();
    final displayNameMap = <String, String>{};
    final avatarMap = <String, String>{};

    for (final username in usernames) {
      final profile = await _userService.getUserPersonalization(username);
      final avatar = await _userService.getSelectedUserAvatar(username);

      if (profile.displayName.trim().isNotEmpty) {
        displayNameMap[username] = profile.displayName.trim();
      }
      if ((avatar ?? '').trim().isNotEmpty) {
        avatarMap[username] = avatar!.trim();
      }
    }

    if (!mounted) return;
    setState(() {
      _availableUsernames = usernames;
      _displayNameByUser
        ..clear()
        ..addAll(displayNameMap);
      _avatarByUser
        ..clear()
        ..addAll(avatarMap);
      _isLoading = false;
    });
  }

  Future<String?> _askPasswordForUser(String username) async {
    String typedPassword = '';
    String? localError;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Giriş Yap: $username'),
              content: TextField(
                obscureText: true,
                autofocus: true,
                onChanged: (value) => typedPassword = value,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  errorText: localError,
                ),
                onSubmitted: (_) {
                  if (typedPassword.trim().isEmpty) {
                    setDialogState(() => localError = 'Şifre boş olamaz.');
                    return;
                  }
                  Navigator.of(dialogContext).pop(typedPassword.trim());
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (typedPassword.trim().isEmpty) {
                      setDialogState(() => localError = 'Şifre boş olamaz.');
                      return;
                    }
                    Navigator.of(dialogContext).pop(typedPassword.trim());
                  },
                  child: const Text('Doğrula'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _verifySelectedProfile(String username) async {
    while (mounted) {
      final password = await _askPasswordForUser(username);
      if (!mounted || password == null) return;

      final loginResult =
          await _userService.loginUserDetailed(username, password);
      if (!mounted) return;

      if (loginResult.success) {
        context.go(AppRoutes.home);
        return;
      }

      final message = loginResult.isLockedOut
          ? 'Çok fazla deneme. ${loginResult.remainingLockSeconds} sn sonra tekrar deneyin.'
          : 'Hata: Şifre yanlış.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      if (loginResult.isLockedOut) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Seçimi'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Lütfen giriş yapmak istediğiniz profili seçin:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _availableUsernames.isEmpty
                ? const Center(
                    child: Text('Henüz kayıtlı profil yok.'),
                  )
                : ListView.builder(
                    itemCount: _availableUsernames.length,
                    itemBuilder: (context, index) {
                      final username = _availableUsernames[index];
                      final displayName = _displayNameByUser[username]?.trim();
                      final avatarUrl = _avatarByUser[username];
                      final initialLetter = (displayName ?? username).isNotEmpty
                          ? (displayName ?? username)[0].toUpperCase()
                          : '?';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  initialLetter,
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(displayName?.isNotEmpty == true
                            ? displayName!
                            : username),
                        subtitle: displayName?.isNotEmpty == true
                            ? Text('@$username')
                            : null,
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => _verifySelectedProfile(username),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.auth),
              icon: const Icon(Icons.person_add),
              label: const Text('Yeni Profil Oluştur'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

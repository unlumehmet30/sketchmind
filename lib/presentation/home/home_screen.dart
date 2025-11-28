// lib/presentation/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../data/dummy/stories.dart'; 
import '../../router/app_router.dart';
import '../../data/services/openai_story_service.dart'; 
import '../../data/services/local_user_service.dart'; 
import '../../data/dummy/avatars.dart'; 
import '../games/game_hub_screen.dart'; // Import the GameHubScreen

final _storyService = OpenAIStoryService();
final _localUserService = LocalUserService(); 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Tab index

  // --- User Data State ---
  List<Story> _stories = []; 
  bool _isLoading = true;
  String _currentUsername = 'Misafir'; 
  String _lastLoadedUserId = ''; 
  String? _currentAvatarUrl; 
  bool _isVerified = false; 
  bool _isParentMode = false; 
  
  final GlobalKey _profileKey = GlobalKey(); 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitialDataAndVerify();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
        _checkAndReloadUser();
    }
  }

  // --- DATA LOADING & VERIFICATION ---

  Future<void> _loadInitialDataAndVerify() async {
    await _loadUserData(forceReloadStories: false); 
    if (!mounted) return;

    if (mounted) {
      setState(() { 
        _isVerified = true; 
        _isLoading = false; 
      });
    }
    
    if (!mounted) return;

    if (_isVerified && _stories.isEmpty) {
        await _fetchStories();
    }
  }

  Future<void> _checkAndReloadUser() async {
    if (!mounted) return;
    
    final userId = await _localUserService.getSelectedUserId();
    final avatarUrl = await _localUserService.getSelectedUserAvatar(userId);
    final parentMode = await _localUserService.getIsParentMode(); 
    
    if (!mounted) return;

    if (userId != _lastLoadedUserId || avatarUrl != _currentAvatarUrl || parentMode != _isParentMode) {
      await _loadUserData(forceReloadStories: userId != _lastLoadedUserId);
      
      if(mounted) {
        setState(() { 
          _isParentMode = parentMode; 
        });
      }
    }
  }

  Future<void> _loadUserData({required bool forceReloadStories}) async {
    if (mounted) setState(() => _isLoading = true);

    final userId = await _localUserService.getSelectedUserId();
    if (!mounted) return;

    final fetchedAvatarUrl = await _localUserService.getSelectedUserAvatar(userId); 
    if (!mounted) return;
    
    final parentMode = await _localUserService.getIsParentMode(); 
    if (!mounted) return;

    if (!mounted) return;

    setState(() {
      _currentUsername = userId == LocalUserService.defaultUserId ? 'Misafir' : userId;
      _lastLoadedUserId = userId;
      _currentAvatarUrl = fetchedAvatarUrl ?? defaultAvatarUrl; 
      _isParentMode = parentMode; 
    });
    
    if (forceReloadStories) {
        await _fetchStories();
    } else {
         if (mounted && (_currentUsername == LocalUserService.defaultUserId || _isVerified)) {
             setState(() { _isLoading = false; });
         }
    }
  }
  
  Future<void> _fetchStories() async {
    final userId = await _localUserService.getSelectedUserId();
    if (!mounted) return;
    
    try {
      final stories = await _storyService.getStoriesForUser(userId); 
      
      if (mounted) {
        setState(() {
          _stories = stories;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Hikayeler çekilemedi: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _logoutAndRedirect() async {
    await _localUserService.logoutUser();
    if (mounted) {
        _isVerified = false; 
        context.go(AppRoutes.auth);
    }
  }
  
  void _forceSwitchProfile(String username) async {
    await _localUserService.setSelectedUserId(username);
    if (mounted) {
      _checkAndReloadUser();
    }
  }

  // --- DIALOGS ---

  Future<bool> _showPasswordVerificationDialog(String targetUsername, {bool isStrict = false}) async {
    final TextEditingController passwordController = TextEditingController();
    
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isStrict, 
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String error = '';
            
            void verify() async {
               if (!dialogContext.mounted) return;
               
               final success = await _localUserService.loginUser(targetUsername, passwordController.text.trim());
               
               if (!dialogContext.mounted) return;

               if (success) {
                  Navigator.pop(dialogContext, true);
               } else {
                  setDialogState(() => error = 'Yanlış şifre');
               }
            }

            return PopScope(
              canPop: !isStrict,
              child: AlertDialog(
                title: Text(isStrict ? 'Giriş Yap: $targetUsername' : 'Şifre Doğrulama'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isStrict) const Text("Devam etmek için şifrenizi doğrulayın."),
                      TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(labelText: 'Şifre', errorText: error.isEmpty ? null : error),
                          onSubmitted: (_) => verify(),
                      ),
                    ],
                  ),
                ),
                actions: [
                    if (!isStrict) TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
                    ElevatedButton(
                        onPressed: verify, 
                        child: const Text('Doğrula')
                    ),
                ],
              ),
            );
          }
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showProfileOptions(BuildContext context) async {
    final allUsernames = await _localUserService.getAllRegisteredUsernames();
    if (!mounted) return;

    final switchableUsers = allUsernames.where((name) => name != _currentUsername).toList();
    final bool isGuest = _currentUsername == 'Misafir';

    final List<PopupMenuEntry<String>> menuItems = [
        ...switchableUsers.map((username) => PopupMenuItem<String>(
          value: username,
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.blueAccent.withOpacity(0.2),
                child: Text(username[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Geçiş Yap: $username', style: const TextStyle(fontWeight: FontWeight.w500))),
            ],
          ),
        )).toList(),
        
        if (switchableUsers.isNotEmpty) const PopupMenuDivider(),
        
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(isGuest ? Icons.login : Icons.logout, color: isGuest ? Colors.green : Colors.redAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isGuest ? 'Giriş Yap / Kayıt Ol' : 'Başka Biriyle Giriş Yap', 
                  style: TextStyle(color: isGuest ? Colors.green : Colors.redAccent, fontWeight: FontWeight.w600)
                ),
              ),
            ],
          ),
        ),
    ];
    
    final RenderBox? renderBox = _profileKey.currentContext?.findRenderObject() as RenderBox?;
    Offset offset = Offset.zero;
    Size size = Size.zero;
    
    if (renderBox != null) {
      offset = renderBox.localToGlobal(Offset.zero);
      size = renderBox.size;
    }
    
    await showMenu(
      context: context,
      elevation: 8,
      shadowColor: Colors.black26,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
      position: RelativeRect.fromLTRB(
        offset.dx, 
        offset.dy + size.height + 5, 
        offset.dx + size.width, 
        offset.dy + size.height + 100
      ), 
      items: menuItems,
    ).then((value) async { 
      if (!mounted) return; 

      if (value == 'logout') {
        _logoutAndRedirect();
      } else if (value is String) {
        final bool success = await _showPasswordVerificationDialog(value, isStrict: false); 
        if (!mounted) return;

        if (success) {
            _forceSwitchProfile(value);
        }
      }
    });
  }

  // --- WIDGETS ---

  Widget _buildStoriesTab() {
     if (_stories.isEmpty) {
       return Center(
         child: Text(
           _currentUsername == 'Misafir' 
           ? "Giriş yapın ve kendi hikayelerinizi oluşturun!"
           : (_isParentMode 
                ? "Henüz hikaye yok. (+) butonuna basarak oluşturun." 
                : "Henüz hikaye yok. Hikaye oluşturmak için Ebeveyn Modunu açın."),
           textAlign: TextAlign.center,
         )
       );
     }
     
     return ListView.builder(
       itemCount: _stories.length,
       itemBuilder: (context, index) {
         final story = _stories[index];
         return Card(
           margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           child: ListTile(
             leading: CachedNetworkImage(
               imageUrl: story.imageUrl,
               width: 50, height: 50, fit: BoxFit.cover,
               placeholder: (context, url) => Container(width: 50, height: 50, color: Colors.grey[200]),
               errorWidget: (context, url, error) => Container(width: 50, height: 50, color: Colors.grey[300], child: const Icon(Icons.image_not_supported, size: 30)),
             ),
             title: Text(story.title, style: const TextStyle(fontWeight: FontWeight.bold)),
             subtitle: Text(story.text.length > 50 ? '${story.text.substring(0, 50)}...' : story.text),
             trailing: const Icon(Icons.arrow_forward_ios, size: 16),
             onTap: () { context.push(AppRoutes.storyDetail.replaceFirst(':id', story.id)); },
           ),
         );
       },
     );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isVerified) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final String initialLetter = _currentUsername.isNotEmpty 
        ? _currentUsername[0].toUpperCase() 
        : 'M';
    
    final Widget profileAvatarWidget = CircleAvatar(
        radius: 18,
        backgroundColor: Colors.blueAccent.shade100, 
        backgroundImage: _currentAvatarUrl != null && _currentUsername != 'Misafir'
            ? CachedNetworkImageProvider(_currentAvatarUrl!) as ImageProvider
            : null,
        child: _currentAvatarUrl == null || _currentUsername == 'Misafir'
            ? Text(
                initialLetter,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              )
            : null,
    );

    // Main Scaffold with BottomNavigationBar
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          key: _profileKey,
          onTap: () async {
            await context.push(AppRoutes.profile); 
          },
          onLongPress: () => _showProfileOptions(context), 
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              profileAvatarWidget, 
              const SizedBox(width: 8),
              Text('($_currentUsername)', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)), 
            ],
          ),
        ), 
        automaticallyImplyLeading: false, 
        actions: [
          // Only show "Add Story" button if in Stories tab and Parent Mode is on
          if (_selectedIndex == 0 && _isParentMode)
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () => context.push(AppRoutes.create),
            ),
          
          // Only show refresh button in Stories tab
          if (_selectedIndex == 0)
            IconButton( 
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _stories = [];
                  _isLoading = true;
                });
                _fetchStories(); 
              },
            ),
          const SizedBox(width: 8), 
        ]
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildStoriesTab(),
          const GameHubScreen(), // The new Game Hub Tab
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Hikayeler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.games),
            label: 'Oyun',
          ),
        ],
      ),
    );
  }
}
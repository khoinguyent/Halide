import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/halide_dialog.dart';
import '../core/providers/notification_provider.dart';
import '../core/models/notification_model.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../services/local_avatar_storage.dart';

class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({Key? key}) : super(key: key);

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  bool _controllersInitialized = false;
  String? _localAvatarPath;
  bool _avatarLoading = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nicknameController = TextEditingController();
    _bioController = TextEditingController();
    _loadLocalAvatarPath();
  }

  Future<void> _loadLocalAvatarPath() async {
    final path = await LocalAvatarStorage.avatarPath;
    if (path != null && mounted && File(path).existsSync()) {
      setState(() => _localAvatarPath = path);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _initFromProfile(UserProfile? profile) {
    if (profile == null || _controllersInitialized) return;
    _controllersInitialized = true;
    _nameController.text = profile.displayName ?? '';
    _nicknameController.text = profile.professionalNickname ?? '';
    _bioController.text = profile.bio ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    _initFromProfile(profile);
    final avatarUrl = profile?.avatarUrl;

    return HalideScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          color: Colors.white,
        ),
        centerTitle: true,
        title: const Text(
          'EDIT PROFILE',
          style: TextStyle(
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _avatarLoading ? null : _pickAndSaveAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    backgroundImage: _buildAvatarImage(avatarUrl),
                    child: _buildAvatarPlaceholder(avatarUrl),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: _avatarLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to upload photo',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 28),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Full Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Your display name',
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('Professional Nickname'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nicknameController,
                    hint: 'e.g. Film Shooter',
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('Bio'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _bioController,
                    hint: 'A short bio for your profile',
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: profileAsync.isLoading
                    ? null
                    : () async {
                        final name = _nameController.text.trim();
                        final nickname = _nicknameController.text.trim();
                        final bio = _bioController.text.trim();
                        try {
                          await ref.read(profileServiceProvider).updateProfile(
                                name: name.isEmpty ? null : name,
                                professionalNickname: nickname.isEmpty ? null : nickname,
                                bio: bio.isEmpty ? null : bio,
                                avatarFilePath: _localAvatarPath,
                              );
                          ref.invalidate(userProfileProvider);
                          if (context.mounted) {
                            ref.read(notificationProvider.notifier).show(
                              'PROFILE UPDATED SUCCESSFULLY!',
                              type: NotificationType.success,
                            );
                            context.pop();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ref.read(notificationProvider.notifier).show(
                              'COULDN\'T UPDATE PROFILE. PLEASE TRY AGAIN.',
                              type: NotificationType.error,
                            );
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Save changes'),
              ),
            ),
            const SizedBox(height: 100), // Extra space for keyboard scrolling
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  static bool _isRemoteAvatarUrl(String? url) {
    if (url == null || url.isEmpty || url == 'local') return false;
    return true;
  }

  ImageProvider? _buildAvatarImage(String? avatarUrl) {
    if (_localAvatarPath != null) {
      final file = File(_localAvatarPath!);
      if (file.existsSync()) return FileImage(file);
    }
    if (_isRemoteAvatarUrl(avatarUrl)) return NetworkImage(avatarUrl!);
    return null;
  }

  Widget? _buildAvatarPlaceholder(String? avatarUrl) {
    final hasImage = _localAvatarPath != null && File(_localAvatarPath!).existsSync();
    if (hasImage || _isRemoteAvatarUrl(avatarUrl)) return null;
    return Icon(Icons.person, size: 60, color: Colors.white.withOpacity(0.5));
  }

  Future<void> _pickAndSaveAvatar() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _avatarLoading = true);
    try {
      final savedPath = await LocalAvatarStorage.saveFromPath(picked.path);
      if (mounted && savedPath != null) {
        setState(() {
          _localAvatarPath = savedPath;
          _avatarLoading = false;
        });
        if (mounted) {
          ref.read(notificationProvider.notifier).show(
            'PHOTO SAVED ON THIS DEVICE. TAP "SAVE CHANGES" TO UPDATE PROFILE.',
            type: NotificationType.info,
          );
        }
      } else {
        if (mounted) setState(() => _avatarLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _avatarLoading = false);
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
          'COULD NOT SAVE PHOTO. PLEASE TRY AGAIN.',
          type: NotificationType.error,
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

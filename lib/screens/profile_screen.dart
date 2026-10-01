import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/login_type.dart';
import '../models/user_model.dart';
import '../services/user_services.dart';
import '../widgets/custom_text.dart';
import 'sigin_screen.dart';

// Lab 4 - Enhancement 3: renders the signed-in user's profile, branching on
// UserService.getLoginType() — DummyJSON sessions render the original
// User-model-backed view; Firebase sessions render a view built from
// UserService.getFirebaseProfileData() plus the account-management actions
// (update username / change password / delete account) backed by the
// Firebase-only UserService methods added for Enhancement 1.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<LoginType> _loginTypeFuture;

  @override
  void initState() {
    super.initState();
    _loginTypeFuture = UserService().getLoginType();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoginType>(
      future: _loginTypeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data == LoginType.firebase) {
          return const _FirebaseProfileView();
        }
        return const _DummyJsonProfileView();
      },
    );
  }
}

Future<void> _logoutAndReturnToSignIn(BuildContext context) async {
  await UserService().logoutUser();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SiginScreen()),
    (route) => false,
  );
}

class _DummyJsonProfileView extends StatefulWidget {
  const _DummyJsonProfileView();

  @override
  State<_DummyJsonProfileView> createState() => _DummyJsonProfileViewState();
}

class _DummyJsonProfileViewState extends State<_DummyJsonProfileView> {
  late Future<User> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = UserService().getUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: CustomText(
              text: 'Failed to load profile: ${snapshot.error}',
              fontSize: 14.sp,
            ),
          );
        }

        final user = snapshot.data!;

        return SingleChildScrollView(
          padding: EdgeInsets.all(24.r),
          child: Column(
            children: [
              CircleAvatar(
                radius: 48.r,
                backgroundImage:
                    user.image.isNotEmpty ? NetworkImage(user.image) : null,
                child: user.image.isEmpty
                    ? Icon(Icons.person, size: 48.sp)
                    : null,
              ),
              SizedBox(height: 16.h),
              CustomText(
                text: '${user.firstName} ${user.lastName}'.trim(),
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 4.h),
              CustomText(text: '@${user.username}', fontSize: 13.sp),
              SizedBox(height: 24.h),
              _ProfileInfoTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: user.email,
              ),
              _ProfileInfoTile(
                icon: Icons.badge_outlined,
                label: 'User ID',
                value: '${user.id}',
              ),
              _ProfileInfoTile(
                icon: Icons.wc_outlined,
                label: 'Gender',
                value: user.gender,
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logoutAndReturnToSignIn(context),
                  icon: const Icon(Icons.logout),
                  label: const CustomText(
                    text: 'Logout',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FirebaseProfileView extends StatefulWidget {
  const _FirebaseProfileView();

  @override
  State<_FirebaseProfileView> createState() => _FirebaseProfileViewState();
}

class _FirebaseProfileViewState extends State<_FirebaseProfileView> {
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = UserService().getFirebaseProfileData();
  }

  void _refresh() {
    setState(() {
      _profileFuture = UserService().getFirebaseProfileData();
    });
  }

  void _showError(Object e) {
    if (!mounted) return;
    final message = e is FirebaseAuthException ? (e.message ?? e.code) : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _updateUsername(String currentUsername) async {
    final controller = TextEditingController(text: currentUsername);
    final newUsername = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newUsername == null || newUsername.isEmpty) return;
    try {
      await UserService().updateUsername(username: newUsername);
      _refresh();
      _showSuccess('Username updated');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Current password'),
            ),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final email = UserService().currentFirebaseUser?.email;
    if (email == null) return;

    try {
      await UserService().resetPasswordFromCurrentPassword(
        currentPassword: currentPasswordController.text,
        newPassword: newPasswordController.text,
        email: email,
      );
      _showSuccess('Password updated');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This is permanent. Enter your password to confirm.'),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final email = UserService().currentFirebaseUser?.email;
    if (email == null) return;

    try {
      await UserService().deleteAccount(
        email: email,
        password: passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SiginScreen()),
        (route) => false,
      );
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: CustomText(
              text: 'Failed to load profile: ${snapshot.error}',
              fontSize: 14.sp,
            ),
          );
        }

        final profile = snapshot.data!;
        final username = profile['username'] as String;

        return SingleChildScrollView(
          padding: EdgeInsets.all(24.r),
          child: Column(
            children: [
              CircleAvatar(
                radius: 48.r,
                child: Icon(Icons.person, size: 48.sp),
              ),
              SizedBox(height: 16.h),
              CustomText(
                text: '${profile['fName']} ${profile['lName']}'.trim(),
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 4.h),
              CustomText(text: '@$username', fontSize: 13.sp),
              SizedBox(height: 24.h),
              _ProfileInfoTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: profile['email'] as String,
              ),
              _ProfileInfoTile(
                icon: Icons.cake_outlined,
                label: 'Age',
                value: '${profile['age']}',
              ),
              _ProfileInfoTile(
                icon: Icons.phone_outlined,
                label: 'Contact No',
                value: profile['contactNo'] as String,
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _updateUsername(username),
                  icon: const Icon(Icons.edit_outlined),
                  label: const CustomText(
                    text: 'Update Username',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _changePassword,
                  icon: const Icon(Icons.lock_reset_outlined),
                  label: const CustomText(
                    text: 'Change Password',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _deleteAccount,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_outline),
                  label: const CustomText(
                    text: 'Delete Account',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logoutAndReturnToSignIn(context),
                  icon: const Icon(Icons.logout),
                  label: const CustomText(
                    text: 'Logout',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 20.sp, color: Colors.grey),
          SizedBox(width: 12.w),
          CustomText(
            text: label,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
          const Spacer(),
          Flexible(
            child: CustomText(
              text: value,
              fontSize: 13.sp,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

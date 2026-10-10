import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/media_service.dart';
import '../../services/api_client.dart';
import '../../services/location_service.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  AppLocation? _location;
  bool _loading = true;
  // Local demo portfolio slots (URLs or placeholders)
  List<String> _portfolio = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AuthService.instance.currentUser();
    final me = await AuthService.instance.me();
    final location = await LocationService.instance.loadLocal();
    if (!mounted) return;
    final u = me ?? user;
    List<String> portfolio = [];
    final ap = u?['artisanProfile'];
    if (ap is Map) {
      final raw = ap['portfolioJson'] ?? ap['portfolio'];
      if (raw is List) {
        portfolio = raw.map((e) => e.toString()).toList();
      } else if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            portfolio = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
    }
    setState(() {
      _user = u;
      _location = location;
      _portfolio = portfolio;
      _loading = false;
    });
  }

  Future<void> _editLocation() async {
    await Navigator.pushNamed(context, '/location',
        arguments: {'mode': 'edit'});
    if (!mounted) return;
    final location = await LocationService.instance.loadLocal();
    if (!mounted) return;
    setState(() => _location = location);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }


  Future<void> _handleDpSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile photo',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.primary700),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary700),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),

              const SizedBox(height: 28),
              const FieldLabel('Help & legal'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/support'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Terms of use'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/terms'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Privacy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/privacy'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'remove') {
      setState(() => _uploading = true);
      try {
        await MediaService.instance.removeAvatar();
        await _load();
        if (mounted) _snack('Photo removed');
      } on ApiException catch (e) {
        if (mounted) _snack(e.message);
      } catch (_) {
        if (mounted) _snack('Could not remove photo');
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
      return;
    }

    final source =
        action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final file = await MediaService.instance.pickImage(source: source);
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final data = await MediaService.instance.uploadAvatar(file);
      final user = data['user'];
      if (user is Map && mounted) {
        setState(() {
          _user = {...?_user, ...Map<String, dynamic>.from(user)};
        });
      }
      await _load();
      if (mounted) _snack('Photo updated');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Upload failed. Is the API running?');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _addPortfolio() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add work sample',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              const SoftText('Show clients examples of your past jobs.', size: 13),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.primary700),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary700),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    final source =
        action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final file = await MediaService.instance.pickImage(source: source);
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final list = await MediaService.instance.uploadPortfolio(file);
      if (mounted) {
        setState(() => _portfolio = list);
        _snack('Added to portfolio');
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Upload failed');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }



  void _openImage(String url, {List<String>? gallery, int index = 0}) {
    if (url.isEmpty) return;
    final urls = gallery ?? [url];
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: PageController(initialPage: index),
                    itemCount: urls.length,
                    itemBuilder: (_, i) {
                      return InteractiveViewer(
                        child: Center(
                          child: Image.network(
                            urls[i],
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                              size: 48,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _handleCoverSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cover image',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.primary700),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary700),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Remove cover'),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'remove') {
      setState(() => _uploading = true);
      try {
        await MediaService.instance.removeCover();
        await _load();
        if (mounted) _snack('Cover removed');
      } on ApiException catch (e) {
        if (mounted) _snack(e.message);
      } catch (_) {
        if (mounted) _snack('Could not remove cover');
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
      return;
    }

    final source =
        action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final file = await MediaService.instance.pickImage(source: source);
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final data = await MediaService.instance.uploadCover(file);
      final user = data['user'];
      if (user is Map && mounted) {
        setState(() {
          _user = {...?_user, ...Map<String, dynamic>.from(user)};
        });
      }
      await _load();
      if (mounted) _snack('Cover updated');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Could not update cover');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = _user?['fullName']?.toString() ?? 'User';
    final letter = _user?['avatarLetter']?.toString() ??
        (name.isNotEmpty ? name[0].toUpperCase() : 'U');
    final phone = _user?['phone']?.toString();
    final email = _user?['email']?.toString();
    final contact = phone ?? email ?? '—';
    final area = _user?['area']?.toString();
    final city = _user?['city']?.toString();
    final localLocation = _location;
    final location = localLocation != null &&
        localLocation.label.isNotEmpty &&
        !localLocation.labelLooksLikeCoordinates
      ? localLocation.label
      : [localLocation?.area ?? area, localLocation?.city ?? city]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');
    final role = _user?['role']?.toString() ?? 'CLIENT';
    final roleLabel = role == 'ARTISAN'
        ? 'Artisan'
        : role == 'BOTH'
            ? 'Client & artisan'
            : 'Client';
    final isArtisan = role == 'ARTISAN' || role == 'BOTH';
    final rawCover = _user?['coverUrl']?.toString();
    final coverSrc = (rawCover == null ||
            rawCover.isEmpty ||
            rawCover == 'null' ||
            rawCover == 'undefined')
        ? ''
        : MediaService.resolveUrl(rawCover);
    final hasCover = coverSrc.isNotEmpty;


    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (Navigator.canPop(context))
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AppBackButton(),
                ),
              const SizedBox(height: 8),
              // Profile cover art — changeable; watermark always overlaid
              GestureDetector(
                onTap: _handleCoverSheet,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasCover)
                          Image.network(
                            coverSrc,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF1A5C42),
                                    Color(0xFF2A9468),
                                    Color(0xFF7BC4A0),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF1A5C42),
                                  Color(0xFF2A9468),
                                  Color(0xFF7BC4A0),
                                ],
                              ),
                            ),
                          ),
                        // Dark gradient so watermark stays readable
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.05),
                                Colors.black.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                        // Watermark (always overlaid)
                        Positioned(
                          right: 16,
                          bottom: 12,
                          child: Text(
                            'whoseNearby',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              shadows: const [
                                Shadow(blurRadius: 6, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          bottom: 12,
                          child: Text(
                            isArtisan ? 'Artisan profile' : 'Your profile',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13,
                              shadows: const [
                                Shadow(blurRadius: 6, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_camera_outlined, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Change',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // DP
              Center(
                child: GestureDetector(
                  onTap: _handleDpSheet,
                  child: Stack(
                    children: [
                      AppAvatar(
                        letter: letter,
                        size: 96,
                        imageUrl: MediaService.resolveUrl(
                          _user?['avatarUrl']?.toString(),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary700,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              SoftText(
                location.isEmpty ? roleLabel : '$roleLabel · $location',
                size: 13,
                align: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _handleDpSheet,
                  child: Text(
                    'Change photo',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Artisan dashboard CTA
              GestureDetector(
                onTap: () {
                  if (isArtisan) {
                    Navigator.pushNamed(context, '/artisan-home');
                  } else {
                    Navigator.pushNamed(context, '/artisan-onboarding');
                  }
                },
                child: AppCard(
                  color: AppColors.primary050,
                  borderColor: AppColors.primary100,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArtisan
                                  ? 'Artisan dashboard'
                                  : 'Offer your skills?',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            SoftText(
                              isArtisan
                                  ? 'Manage requests and earnings'
                                  : 'Get discovered by people nearby',
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.primary700),
                    ],
                  ),
                ),
              ),

              // ── Portfolio gallery (artisans) ──
              if (isArtisan) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text(
                      'Portfolio',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    const SoftText('Work samples', size: 12),
                  ],
                ),
                const SizedBox(height: 12),
                if (_uploading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _portfolio.length + 1,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, i) {
                    if (i == _portfolio.length) {
                      return GestureDetector(
                        onTap: _uploading ? null : _addPortfolio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: AppColors.inkFaint, size: 28),
                        ),
                      );
                    }
                    final url = MediaService.resolveUrl(_portfolio[i]);
                    return GestureDetector(
                      onLongPress: _uploading
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove image?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                setState(() => _uploading = true);
                                try {
                                  final list = await MediaService.instance
                                      .removePortfolioAt(i);
                                  if (mounted) {
                                    setState(() => _portfolio = list);
                                  }
                                } catch (_) {
                                  if (mounted) _snack('Could not remove');
                                } finally {
                                  if (mounted) {
                                    setState(() => _uploading = false);
                                  }
                                }
                              }
                            },
                      child: GestureDetector(
                        onTap: () {
                          final gallery = _portfolio
                              .map((e) => MediaService.resolveUrl(e))
                              .where((u) => u.isNotEmpty)
                              .toList();
                          _openImage(url, gallery: gallery, index: i);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primary100,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 28),
              const Align(
                alignment: Alignment.centerLeft,
                child: FieldLabel('Personal info'),
              ),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    _InfoRow(Icons.person_outline, 'Full name', name),
                    const Divider(height: 1, color: AppColors.lineSoft),
                    _InfoRow(Icons.phone_outlined, 'Contact', contact),
                    const Divider(height: 1, color: AppColors.lineSoft),
                    _InfoRow(
                      Icons.location_on_outlined,
                      'Location',
                      location.isEmpty ? 'Not set' : location,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: FieldLabel('Account'),
              ),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Wallet & PIN',
                      onTap: () => Navigator.pushNamed(context, '/wallet'),
                    ),
                    _MenuTile(
                      icon: Icons.lock_outline,
                      label: 'Set / change PIN',
                      onTap: () => Navigator.pushNamed(context, '/pin-setup'),
                    ),
                    _MenuTile(
                      icon: Icons.location_on_outlined,
                      label: 'Update location',
                      onTap: _editLocation,
                    ),
                    _MenuTile(
                      icon: Icons.work_outline,
                      label: 'My jobs',
                      onTap: () => Navigator.pushNamed(context, '/job-inbox'),
                    ),
                    _MenuTile(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () =>
                          Navigator.pushNamed(context, '/messages'),
                    ),
                    _MenuTile(
                      icon: Icons.chat_bubble_outline,
                      label: 'Messages',
                      onTap: () => Navigator.pushNamed(context, '/messages'),
                    ),
                    if (isArtisan)
                      _MenuTile(
                        icon: Icons.handyman_outlined,
                        label: 'Artisan profile',
                        onTap: () =>
                            Navigator.pushNamed(context, '/artisan-home'),
                      )
                    else
                      _MenuTile(
                        icon: Icons.handyman_outlined,
                        label: 'Become an artisan',
                        onTap: () => Navigator.pushNamed(
                            context, '/artisan-onboarding'),
                      ),
                    _MenuTile(
                      icon: Icons.post_add_outlined,
                      label: 'Post a job',
                      onTap: () => Navigator.pushNamed(context, '/post-job'),
                    ),
                    _MenuTile(
                      icon: Icons.help_outline,
                      label: 'Help & support',
                      onTap: () => _snack(
                          'Email support@whosenearby.app or chat in-app'),
                    ),
                    _MenuTile(
                      icon: Icons.info_outline,
                      label: 'About WhoseNearby',
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'WhoseNearby',
                        applicationVersion: '1.0.0',
                        applicationLegalese: 'Artisan marketplace for Nigeria',
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.logout,
                      label: 'Log out',
                      danger: true,
                      onTap: () async {
                        await AuthService.instance.logout();
                        if (!mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (_) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoftText(label, size: 11),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: danger ? AppColors.danger : AppColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}

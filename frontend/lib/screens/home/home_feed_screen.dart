import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/artisan_service.dart';
import '../../services/api_client.dart';
import '../../services/location_service.dart';
import '../../services/media_service.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  List<Map<String, dynamic>> _artisans = [];
  String? _userName;
  String? _myId;
  String? _userArea;
  String? _userLetter;
  String? _userAvatarUrl;
  bool _loading = true;
  Timer? _autoRefresh;
  String? _error;
  String? _skillFilter;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _loading) return;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final user = await AuthService.instance.currentUser();
      final loc = await LocationService.instance.resolve();
      final artisans = await ArtisanService.instance.list(
        skill: _skillFilter,
        lat: loc.latitude,
        lng: loc.longitude,
        // No region cutoff — API returns all, sorted by distance
      );
      if (!mounted) return;
      setState(() {
        _myId = user?['id']?.toString();
        _userName = user?['fullName'] as String? ?? 'there';
        final area = loc.area ?? user?['area']?.toString();
        final city = loc.city ?? user?['city']?.toString();
        final parts = [area, city]
            .where((e) => e != null && e.isNotEmpty && e != 'null')
            .cast<String>()
            .toList();
        // Prefer human label (never show raw coords if we have a name)
        if (loc.label.isNotEmpty && !loc.labelLooksLikeCoordinates) {
          _userArea = loc.label;
        } else if (parts.isNotEmpty) {
          _userArea = parts.join(', ');
        } else if (loc.label.isNotEmpty) {
          _userArea = loc.label;
        } else {
          _userArea = null;
        }
        _userLetter = user?['avatarLetter'] as String? ??
            (_userName!.isNotEmpty ? _userName![0] : 'U');
        _userAvatarUrl = user?['avatarUrl']?.toString();
        final myId = user?['id']?.toString();
        _artisans = artisans.where((a) {
          final uid = a['userId']?.toString() ??
              (a['user'] is Map ? (a['user'] as Map)['id']?.toString() : null);
          if (myId != null && uid != null && uid == myId) return false;
          return true;
        }).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load. Is the API running?';
        _loading = false;
      });
    }
  }

  void _filter(String? skill) {
    setState(() => _skillFilter = skill);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (_userName ?? 'there').split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  AppAvatar(
                    letter: _userLetter ?? 'U',
                    size: 44,
                    imageUrl: MediaService.resolveUrl(_userAvatarUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.pushNamed(context, '/location', arguments: {'mode': 'edit'});
                        if (mounted) _load();
                      },
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $firstName 👋',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 14, color: AppColors.primary600),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                (_userArea != null &&
                                        _userArea!.isNotEmpty &&
                                        _userArea != 'null')
                                    ? '$_userArea · sorted by distance'
                                    : 'Tap to set location',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.inkSoft,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16, color: AppColors.inkFaint),
                          ],
                        ),
                      ],
                    ),
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 22),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/search'),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search,
                                  size: 20, color: AppColors.inkFaint),
                              const SizedBox(width: 12),
                              Text(
                                'Search artisan or job…',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  color: AppColors.inkFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _FilterChip(
                              label: 'All',
                              active: _skillFilter == null,
                              onTap: () => _filter(null),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Electrician',
                              active: _skillFilter == 'Electrician',
                              onTap: () => _filter('Electrician'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Plumber',
                              active: _skillFilter == 'Plumber',
                              onTap: () => _filter('Plumber'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Barber',
                              active: _skillFilter == 'Barber',
                              onTap: () => _filter('Barber'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SectionHeader(
                        'All artisans · nearest first',
                        trailing: AppChip(
                          label: '${_artisans.length} found',
                          variant: ChipVariant.green,
                        ),
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Column(
                            children: [
                              SoftText(_error!, align: TextAlign.center),
                              const SizedBox(height: 12),
                              SecondaryButton(label: 'Retry', onPressed: _load),
                            ],
                          ),
                        )
                      else if (_artisans.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: Center(
                            child: SoftText('No artisans yet. When artisans register, they appear here sorted by distance.'),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: _artisans.length,
                          itemBuilder: (context, i) {
                            final a = _artisans[i];
                            final dist = a['distanceKm'];
                            final userMap = a['user'] is Map
                                ? Map<String, dynamic>.from(a['user'] as Map)
                                : <String, dynamic>{};
                            final letter = userMap['avatarLetter']?.toString() ??
                                ((a['businessName']?.toString() ?? 'A').isNotEmpty
                                    ? (a['businessName']?.toString() ?? 'A')[0]
                                    : 'A');
                            final avatarUrl = a['avatarUrl']?.toString() ??
                                userMap['avatarUrl']?.toString();
                            return ArtisanGridCard(
                              name: a['businessName']?.toString() ?? 'Artisan',
                              letter: letter,
                              imageUrl: MediaService.resolveUrl(avatarUrl),
                              // Cover is branded gradient (not portfolio / not DP)
                              coverUrl: null,
                              category:
                                  '${a['primarySkill'] ?? ''} · ${a['area'] ?? ''}',
                              distance: dist != null ? '$dist km' : 'Distance unknown',
                              rating:
                                  '${(a['ratingAvg'] as num?)?.toStringAsFixed(1) ?? '—'} ★',
                              jobs: '${a['jobsDone'] ?? 0} jobs',
                              available: a['isAvailable'] == true,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/artisan',
                                arguments: a['id'] as String,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppChip(
        label: label,
        variant: active ? ChipVariant.dark : ChipVariant.line,
      ),
    );
  }
}

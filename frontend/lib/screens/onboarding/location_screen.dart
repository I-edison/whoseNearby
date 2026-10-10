import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/location_service.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // Default so Continue is never blocked if user forgets to tap
  AppLocation? _selected = kPopularLocations.first;
  bool _loadingGps = false;
  bool _saving = false;
  String? _error;
  String? _hint;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _hint =
          'On web, live GPS is limited. Pick a city/area below — that works for the pilot.';
    }
    _restoreLocation();
  }

  Future<void> _restoreLocation() async {
    final saved = await LocationService.instance.loadLocal();
    if (!mounted || saved == null) return;
    setState(() => _selected = saved);
  }

  Future<void> _useLive() async {
    setState(() {
      _loadingGps = true;
      _error = null;
      _hint = null;
    });
    try {
      final loc = await LocationService.instance
          .getCurrentLocation()
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (loc == null) {
        setState(() {
          _error =
              'Could not get GPS. Grant location permission or pick an area below.';
          _loadingGps = false;
        });
        return;
      }
      setState(() {
        _selected = loc;
        _loadingGps = false;
        _hint = 'Using: ${loc.label}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Live location timed out or is unavailable. Pick an area in Benin / Edo below.';
        _loadingGps = false;
      });
    }
  }

  Future<void> _continue() async {
    final loc = _selected ?? kPopularLocations.first;
    setState(() {
      _saving = true;
      _error = null;
    });

    // Never hang the UI on network/geocode
    try {
      await LocationService.instance
          .apply(loc)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Local save may still have run; proceed anyway
      try {
        await LocationService.instance.saveLocal(loc);
      } catch (_) {}
    }

    if (!mounted) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    final isEdit = args == 'edit' ||
        (args is Map && args['mode']?.toString() == 'edit');

    if (isEdit && Navigator.canPop(context)) {
      Navigator.pop(context, loc);
    } else {
      // Onboarding / registration: always go home, clear stack
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: AppBackButton(
                  fallbackRoute: '/role',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Where are you?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              const SoftText(
                'We use this to show artisans near you. You can change it later.',
                size: 14,
              ),
              const SizedBox(height: 16),
              SecondaryButton(
                label: _loadingGps ? 'Getting GPS…' : 'Use live location',
                onPressed: _loadingGps ? null : _useLive,
              ),
              if (_hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  _hint!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.primary700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_selected != null) ...[
                const SizedBox(height: 10),
                AppCard(
                  color: AppColors.primary050,
                  borderColor: AppColors.primary100,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.primary700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Selected: ${_selected!.label}',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const FieldLabel('Pick a popular area'),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: kPopularLocations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final loc = kPopularLocations[i];
                    final active = _selected?.label == loc.label;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selected = loc;
                        _error = null;
                        _hint = null;
                      }),
                      child: AppCard(
                        color:
                            active ? AppColors.primary050 : AppColors.surface,
                        borderColor:
                            active ? AppColors.primary600 : AppColors.line,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              color: active
                                  ? AppColors.primary700
                                  : AppColors.inkSoft,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                loc.label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (active)
                              const Icon(Icons.check,
                                  color: AppColors.primary700),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Continue',
                loading: _saving,
                onPressed: _saving ? null : _continue,
              ),
              const SizedBox(height: 6),
              Text(
                'Tip: tap any area (e.g. Ugbowo or GRA), then Continue. You can change it later in Settings.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

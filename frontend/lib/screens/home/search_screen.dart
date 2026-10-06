import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/artisan_service.dart';
import '../../services/api_client.dart';
import '../../services/location_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  String? _sort;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search([String? preset]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loc = await LocationService.instance.resolve();
      final text = (preset ?? _ctrl.text).trim();
      final list = await ArtisanService.instance.list(
        q: text.isEmpty ? null : text,
        lat: loc.latitude,
        lng: loc.longitude,
      );
      if (!mounted) return;
      setState(() {
        _results = list;
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
        _error = 'Search failed';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onSubmitted: (_) => _search(),
                      onChanged: (v) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 400), () {
                          _search();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search name or skill…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: () => _search(),
                      child: AppChip(
                        label: 'Nearest',
                        variant: _sort == null
                            ? ChipVariant.dark
                            : ChipVariant.line,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _search('Electrician'),
                      child: const AppChip(label: 'Electrician'),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _search('Plumber'),
                      child: const AppChip(label: 'Plumber'),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _search('Barber'),
                      child: const AppChip(label: 'Barber'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SoftText(
                  _loading
                      ? 'Searching…'
                      : '${_results.length} artisans found',
                  size: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: SoftText(_error!))
                      : _results.isEmpty
                          ? const Center(
                              child: SoftText('No artisans match your search.'),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final a = _results[i];
                                final dist = a['distanceKm'];
                                final rate = a['hourlyRate'];
                                return GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    '/artisan',
                                    arguments: a['id'] as String,
                                  ),
                                  child: AppCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        AppAvatar(
                                          letter: a['avatarLetter']
                                                  ?.toString() ??
                                              'A',
                                          size: 48,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      a['businessName']
                                                              ?.toString() ??
                                                          'Artisan',
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                      ),
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.verified,
                                                    size: 14,
                                                    color:
                                                        AppColors.primary700,
                                                  ),
                                                ],
                                              ),
                                              SoftText(
                                                [
                                                  a['primarySkill'],
                                                  if (dist != null)
                                                    '$dist km',
                                                  if (rate != null)
                                                    '₦${(rate as num).toStringAsFixed(0)}/hr',
                                                ].whereType<Object>().join(' · '),
                                                size: 12,
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  AppChip(
                                                    label: a['isAvailable'] ==
                                                            true
                                                        ? 'Available'
                                                        : 'Busy',
                                                    variant:
                                                        a['isAvailable'] ==
                                                                true
                                                            ? ChipVariant.green
                                                            : ChipVariant
                                                                .amber,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${(a['ratingAvg'] as num?)?.toStringAsFixed(1) ?? '—'} ★ · ${a['jobsDone'] ?? 0} jobs',
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

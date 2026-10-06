import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/artisan_service.dart';
import '../../services/job_service.dart';
import '../../services/api_client.dart';
import '../../services/media_service.dart';

class ArtisanDetailScreen extends StatefulWidget {
  const ArtisanDetailScreen({super.key});

  @override
  State<ArtisanDetailScreen> createState() => _ArtisanDetailScreenState();
}

class _ArtisanDetailScreenState extends State<ArtisanDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _starting = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null && _loading) {
      final id = ModalRoute.of(context)?.settings.arguments as String?;
      if (id != null) {
        _fetch(id);
      } else {
        setState(() {
          _loading = false;
          _error = 'No artisan selected';
        });
      }
    }
  }

  Future<void> _fetch(String id) async {
    try {
      final data = await ArtisanService.instance.getById(id);
      if (!mounted) return;
      setState(() {
        _data = data;
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
        _error = 'Failed to load artisan';
        _loading = false;
      });
    }
  }

  Future<void> _startChat() async {
    if (_data == null) return;
    setState(() => _starting = true);
    final artisanId = _data!['id'] as String;
    try {
      // Reuse open conversation with this artisan if one exists
      final existing = await JobService.instance.mine(as: 'client');
      final open = existing.where((j) {
        final status = j['status']?.toString() ?? '';
        final aid = j['artisanId']?.toString() ??
            (j['artisan'] as Map?)?['id']?.toString();
        return aid == artisanId &&
            (status == 'OPEN' ||
                status == 'NEGOTIATING' ||
                status == 'IN_PROGRESS');
      }).toList();

      String jobId;
      if (open.isNotEmpty) {
        jobId = open.first['id'] as String;
      } else {
        final job = await JobService.instance.create(
          title: 'Job with ${_data!['businessName']}',
          category: _data!['primarySkill']?.toString() ?? 'General',
          description: 'Started from profile',
          artisanId: artisanId,
          city: _data!['user']?['city'] as String?,
          area: _data!['user']?['area'] as String?,
        );
        jobId = job['id'] as String;
      }

      if (!mounted) return;
      Navigator.pushNamed(context, '/chat', arguments: jobId);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start chat')),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _data == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: SoftText(_error ?? 'Not found')),
      );
    }

    final p = _data!;
    final user = p['user'] as Map<String, dynamic>? ?? {};
    final name = p['businessName']?.toString() ?? 'Artisan';
    final letter = user['avatarLetter']?.toString() ?? name[0];
    final avatarUrl = MediaService.resolveUrl(user['avatarUrl']?.toString());
    List<String> portfolio = [];
    final rawPf = p['portfolioJson'] ?? p['portfolio'];
    if (rawPf is List) {
      portfolio = rawPf.map((e) => e.toString()).toList();
    } else if (rawPf is String && rawPf.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPf);
        if (decoded is List) {
          portfolio = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    final skill = p['primarySkill']?.toString() ?? '';
    final rate = p['hourlyRate'];
    final rating = (p['ratingAvg'] as num?)?.toStringAsFixed(1) ?? '—';
    final jobs = p['jobsDone'] ?? 0;
    final bio = p['bio']?.toString() ?? 'No bio yet.';
    final available = p['isAvailable'] == true;
    final ratings = (p['ratings'] as List?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary500, AppColors.primary900],
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 12,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: -36,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.bg, width: 4),
                          ),
                          child: AppAvatar(letter: letter, size: 72, imageUrl: avatarUrl),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const VerifiedChip(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SoftText(
                          '$skill · ${user['area'] ?? ''} ${user['city'] ?? ''}',
                          size: 14,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AppChip(
                              label: available ? 'Available' : 'Busy',
                              variant: available
                                  ? ChipVariant.green
                                  : ChipVariant.amber,
                            ),
                            if (rate != null)
                              AppChip(label: '₦${(rate as num).toStringAsFixed(0)}/hr'),
                            AppChip(
                              label: '$rating ★',
                              variant: ChipVariant.amber,
                            ),
                            AppChip(label: '$jobs jobs'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SoftText(bio, size: 14),
                        if (portfolio.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Portfolio',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: portfolio.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final url =
                                    MediaService.resolveUrl(portfolio[i]);
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    url,
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 110,
                                      height: 110,
                                      color: AppColors.primary100,
                                      child: const Icon(
                                          Icons.broken_image_outlined),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        if (ratings.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const SectionHeader('Recent reviews'),
                          ...ratings.take(3).map((r) {
                            final m = r as Map<String, dynamic>;
                            final client = m['client'] as Map<String, dynamic>?;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          client?['fullName']?.toString() ??
                                              'Client',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '★' * ((m['stars'] as int?) ?? 0),
                                          style: GoogleFonts.plusJakartaSans(
                                            color: AppColors.accent,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (m['comment'] != null)
                                      SoftText(m['comment'].toString(), size: 13),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: PrimaryButton(
                label: 'Chat with ${name.split("'").first}',
                icon: Icons.chat_bubble_outline_rounded,
                loading: _starting,
                onPressed: _starting ? null : _startChat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/job_service.dart';
import '../../services/api_client.dart';
import '../../services/location_service.dart';

/// Shared skill list — keep in sync with artisan onboarding chips.
const kOfferedSkills = [
  'Electrician',
  'Plumber',
  'Barber',
  'Carpenter',
  'Painter',
  'AC Repair',
  'Cleaner',
  'Welder',
  'Tailor',
  'Mechanic',
  'Mason',
  'Other',
];

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _otherSkillCtrl = TextEditingController();

  /// Skill the client needs (maps to job.category)
  String? _selectedSkill;

  final whenOptions = const [
    ('ASAP', 'As soon as possible'),
    ('Today', 'Sometime today'),
    ('This week', 'Within this week'),
    ('Flexible', 'Flexible timing'),
  ];
  int whenIndex = 0;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    _otherSkillCtrl.dispose();
    super.dispose();
  }

  String get _category {
    if (_selectedSkill == 'Other') {
      return _otherSkillCtrl.text.trim();
    }
    return _selectedSkill?.trim() ?? '';
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final category = _category;
    if (_selectedSkill == null) {
      setState(() => _error = 'Choose the skill you need');
      return;
    }
    if (category.isEmpty) {
      setState(() => _error = 'Type the skill you need');
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = 'Add a short title for the job');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loc = await LocationService.instance.loadLocal();
      final budgetRaw = _budgetCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '');
      final budget = double.tryParse(budgetRaw);
      await JobService.instance.create(
        title: title,
        category: category,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        budgetMin: budget,
        budgetMax: budget,
        city: loc?.city,
        area: loc?.area,
        whenNeeded: whenOptions[whenIndex].$1,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Job posted for $category · ${whenOptions[whenIndex].$1}. Matching artisans can respond.',
          ),
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not post job. Is the API running?');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBackButton(fallbackRoute: '/home'),
              const SizedBox(height: 16),
              Text(
                'Post a job',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const SoftText(
                'Say what skill you need and when. Artisans who offer that skill can respond.',
                size: 15,
              ),
              const SizedBox(height: 28),
              const FieldLabel('Skill needed'),
              const SoftText('Pick the trade you are looking for', size: 12),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kOfferedSkills.map((s) {
                  final active = _selectedSkill == s;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedSkill = s;
                      _error = null;
                    }),
                    child: AppChip(
                      label: s,
                      variant: active ? ChipVariant.dark : ChipVariant.line,
                    ),
                  );
                }).toList(),
              ),
              if (_selectedSkill == 'Other') ...[
                const SizedBox(height: 12),
                AppTextField(
                  hint: 'Type the skill (e.g. Generator repair)',
                  controller: _otherSkillCtrl,
                ),
              ],
              const SizedBox(height: 20),
              const FieldLabel('When do you need this?'),
              const SoftText('Helps artisans know how urgent the job is', size: 12),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(whenOptions.length, (i) {
                  final active = i == whenIndex;
                  final (label, _) = whenOptions[i];
                  return GestureDetector(
                    onTap: () => setState(() => whenIndex = i),
                    child: AppChip(
                      label: label,
                      variant: active ? ChipVariant.dark : ChipVariant.line,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              SoftText(whenOptions[whenIndex].$2, size: 12),
              const SizedBox(height: 20),
              const FieldLabel('Job title'),
              AppTextField(
                hint: 'e.g. Socket repair in kitchen',
                controller: _titleCtrl,
              ),
              const SizedBox(height: 16),
              const FieldLabel('Details (optional)'),
              AppTextField(
                hint: 'What happened, location notes, anything the artisan should know…',
                maxLines: 4,
                controller: _descCtrl,
              ),
              const SizedBox(height: 16),
              const FieldLabel('Budget ₦ (optional)'),
              AppTextField(
                hint: 'e.g. 5000',
                controller: _budgetCtrl,
                keyboardType: TextInputType.number,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.danger,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Post job',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

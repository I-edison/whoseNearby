import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';


// ─── Navigation ─────────────────────────────────────────────────────────────

/// Consistent back control. Pops when possible; otherwise goes to [fallbackRoute].
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String fallbackRoute;
  final Color? color;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.fallbackRoute = '/home',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ??
          () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                fallbackRoute,
                (_) => false,
              );
            }
          },
      icon: Icon(Icons.arrow_back_ios_new, size: 20, color: color ?? AppColors.ink),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      tooltip: 'Back',
    );
  }
}

// ─── Buttons ────────────────────────────────────────────────────────────────

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary700,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const SecondaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary700,
          backgroundColor: AppColors.primary050,
          side: const BorderSide(color: AppColors.primary100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const GhostButton({super.key, required this.label, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.inkSoft;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(
            color: color != null ? AppColors.dangerSoft : AppColors.line,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Chips ──────────────────────────────────────────────────────────────────

enum ChipVariant { green, amber, line, dark }

class AppChip extends StatelessWidget {
  final String label;
  final ChipVariant variant;
  final bool mono;

  const AppChip({
    super.key,
    required this.label,
    this.variant = ChipVariant.line,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      ChipVariant.green => (AppColors.primary050, AppColors.primary700, null),
      ChipVariant.amber => (AppColors.accentSoft, AppColors.accent, null),
      ChipVariant.dark => (AppColors.primary700, AppColors.white, null),
      ChipVariant.line => (AppColors.surface, AppColors.inkSoft, AppColors.line),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class VerifiedChip extends StatelessWidget {
  const VerifiedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.primary700,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 12, color: AppColors.white),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar ─────────────────────────────────────────────────────────────────

class AppAvatar extends StatelessWidget {
  final String letter;
  final double size;
  final bool online;
  final bool verified;
  final String? imageUrl;

  const AppAvatar({
    super.key,
    required this.letter,
    this.size = 48,
    this.online = false,
    this.verified = false,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasImage
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary400, AppColors.primary700],
                  ),
            color: hasImage ? AppColors.surfaceMuted : null,
            image: hasImage
                ? DecorationImage(
                    image: NetworkImage(imageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: hasImage
              ? null
              : Text(
                  letter,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.primary500,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Labels & Fields ────────────────────────────────────────────────────────

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;

  const AppTextField({
    super.key,
    this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(fontSize: 15, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary600, width: 1.5),
        ),
      ),
    );
  }
}

// ─── Cards ──────────────────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor ?? AppColors.line),
      ),
      child: child,
    );
  }
}

// ─── Artisan Card ───────────────────────────────────────────────────────────

class ArtisanGridCard extends StatelessWidget {
  final String name;
  final String category;
  final String distance;
  final String rating;
  final String jobs;
  final bool available;
  final String? letter;
  /// Profile photo (circle badge) — not used as the cover.
  final String? imageUrl;
  /// Work sample / portfolio image for the card cover.
  final String? coverUrl;
  final VoidCallback? onTap;

  const ArtisanGridCard({
    super.key,
    required this.name,
    required this.category,
    required this.distance,
    required this.rating,
    required this.jobs,
    this.available = true,
    this.letter,
    this.imageUrl,
    this.coverUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (letter ?? (name.isNotEmpty ? name[0] : 'A')).toUpperCase();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover + avatar
            SizedBox(
              height: 100,
              width: double.infinity,
              child: Stack(
                children: [
                  // Cover = portfolio sample only (never the DP)
                  if (coverUrl != null && coverUrl!.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _CardCoverGradient(),
                      ),
                    )
                  else
                    const _CardCoverGradient(),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: AppChip(
                      label: available ? 'Available' : 'Busy',
                      variant: available ? ChipVariant.green : ChipVariant.amber,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.08),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: AppAvatar(
                        letter: initial,
                        size: 40,
                        imageUrl: imageUrl,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                        const SizedBox(width: 2),
                        Text(
                          rating,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· $jobs jobs',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.near_me_outlined, size: 12, color: AppColors.primary600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            distance,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class PinDots extends StatelessWidget {
  final int filled;
  final int total;

  const PinDots({super.key, required this.filled, this.total = 4});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? AppColors.primary700 : Colors.transparent,
            border: Border.all(
              color: isFilled ? AppColors.primary700 : AppColors.primary300,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}

class OtpBoxes extends StatelessWidget {
  final String value;
  final int length;

  const OtpBoxes({super.key, required this.value, this.length = 6});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final char = i < value.length ? value[i] : '';
        final filled = i < value.length;
        return Container(
          width: 44,
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? AppColors.primary050 : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: filled ? AppColors.primary700 : AppColors.line,
              width: filled ? 1.5 : 1,
            ),
          ),
          child: Text(
            char.isEmpty ? '·' : char,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: filled ? AppColors.primary700 : AppColors.inkFaint,
            ),
          ),
        );
      }),
    );
  }
}

class NumPad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  const NumPad({super.key, required this.onKey, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox();
        return GestureDetector(
          onTap: () => k == '⌫' ? onBackspace() : onKey(k),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              k,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Segmented control ──────────────────────────────────────────────────────

class SegmentedControl extends StatelessWidget {
  final List<String> segments;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: List.generate(segments.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary700 : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                alignment: Alignment.center,
                child: Text(
                  segments[i],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.white : AppColors.inkSoft,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Bottom nav ─────────────────────────────────────────────────────────────

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            active ? (item.activeIcon ?? item.icon) : item.icon,
                            size: 24,
                            color: active
                                ? AppColors.primary700
                                : AppColors.inkFaint,
                          ),
                          if (item.showDot)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surface,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w500,
                          color: active
                              ? AppColors.primary700
                              : AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class BottomNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool showDot;

  const BottomNavItem(
    this.icon,
    this.label, {
    this.activeIcon,
    this.showDot = false,
  });
}

// ─── Balance card ───────────────────────────────────────────────────────────

class BalanceCard extends StatelessWidget {
  final String name;
  final String masked;
  final String balance;
  final Widget? extra;

  const BalanceCard({
    super.key,
    required this.name,
    required this.masked,
    required this.balance,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary700, AppColors.primary900],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name.isNotEmpty)
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary200,
              ),
            ),
          if (masked.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              masked,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.primary300,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Available balance',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.primary200,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            balance,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              letterSpacing: -0.5,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 16),
            extra!,
          ],
        ],
      ),
    );
  }
}

// ─── Section header ─────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─── Soft text ──────────────────────────────────────────────────────────────

class SoftText extends StatelessWidget {
  final String text;
  final double size;
  final TextAlign? align;

  const SoftText(this.text, {super.key, this.size = 14, this.align});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: GoogleFonts.plusJakartaSans(
        fontSize: size,
        color: AppColors.inkSoft,
        height: 1.45,
      ),
    );
  }
}


class _CardCoverGradient extends StatelessWidget {
  const _CardCoverGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary100, AppColors.primary300],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.handyman_outlined,
          color: AppColors.primary500,
          size: 28,
        ),
      ),
    );
  }
}


/// Full wordmark (hexagon + whoseNearby). Use on splash, login, about.
class BrandLogo extends StatelessWidget {
  final double height;
  final bool onDark;

  const BrandLogo({
    super.key,
    this.height = 40,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_full.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(
        'whoseNearby',
        style: GoogleFonts.plusJakartaSans(
          fontSize: height * 0.55,
          fontWeight: FontWeight.w700,
          color: onDark ? Colors.white : AppColors.primary700,
        ),
      ),
    );
  }
}

/// Icon-only mark (hexagon). Use in small UI slots.
class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.hexagon_outlined,
        size: size * 0.8,
        color: AppColors.primary700,
      ),
    );
  }
}

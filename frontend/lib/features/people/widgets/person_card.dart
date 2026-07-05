import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/api_config.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../models/person_item.dart';

class PersonCard extends StatefulWidget {
  final PersonItem person;
  final VoidCallback onTap;

  const PersonCard({super.key, required this.person, required this.onTap});

  @override
  State<PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<PersonCard> {
  bool _isHovering = false;

  Widget _buildAvatar() {
    final String initials =
        '${widget.person.firstName[0]}${widget.person.lastName[0]}'
            .toUpperCase();

    final Widget fallbackWidget = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
        ),
      ),
    );

    String? imageUrl = widget.person.profileImageUrl?.trim();

    //Add backend base URL for relative paths
    if (imageUrl != null && imageUrl.startsWith('/')) {
      imageUrl = ApiConfig.buildUrl(imageUrl);
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF003C82), width: 2.5),
      ),
      //Clip content exactly inside the border bounds
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  //Log failure and return fallback UI
                  debugPrint(
                    'Errore caricamento immagine per ${widget.person.firstName}: $error',
                  );
                  return fallbackWidget;
                },
              )
            : fallbackWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> processedRoles = RoleLabelMapper.processRoles(
      widget.person.roles,
    );
    final String fullName =
        '${widget.person.firstName} ${widget.person.lastName}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 420,
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isHovering ? const Color(0xFF003C82) : Colors.transparent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardOverflowTooltipText(
                      text: fullName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF003C82),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _RoleChipsRow(roles: processedRoles),
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

class _RoleChipsRow extends StatelessWidget {
  final List<String> roles;

  const _RoleChipsRow({required this.roles});

  static const double _chipHorizontalPadding = 20; // 10 sinistra + 10 destra
  static const double _chipBorderAllowance = 2;    // 1px di bordo per lato
  static const double _chipSpacing = 6;

  double _measureChipWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width + _chipHorizontalPadding + _chipBorderAllowance;
  }

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final chipStyle = GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        );
        final extraStyle = GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
        );

        // Trova il numero massimo di chip che entrano nella riga, lasciando
        // spazio al chip "+N" per i ruoli rimanenti quando serve.
        int visibleCount = roles.length;
        while (visibleCount > 1) {
          double totalWidth = 0;
          for (int i = 0; i < visibleCount; i++) {
            totalWidth += _measureChipWidth(roles[i], chipStyle);
            if (i > 0) totalWidth += _chipSpacing;
          }

          final int remaining = roles.length - visibleCount;
          if (remaining > 0) {
            totalWidth += _chipSpacing + _measureChipWidth('+$remaining', extraStyle);
          }

          if (totalWidth <= constraints.maxWidth) break;
          visibleCount--;
        }

        final int extraCount = roles.length - visibleCount;
        final List<String> hiddenRoles = roles.sublist(visibleCount);

        final List<Widget> chips = [];
        for (int i = 0; i < visibleCount; i++) {
          if (i > 0) chips.add(const SizedBox(width: _chipSpacing));
          chips.add(_RoleChip(label: roles[i], style: chipStyle));
        }
        if (extraCount > 0) {
          chips.add(const SizedBox(width: _chipSpacing));
          chips.add(_RoleChip(
            label: '+$extraCount',
            style: extraStyle,
            hiddenRoles: hiddenRoles,
          ));
        }

        return Row(mainAxisSize: MainAxisSize.min, children: chips);
      },
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final TextStyle style;
  final List<String>? hiddenRoles;

  const _RoleChip({required this.label, required this.style, this.hiddenRoles});

  @override
  Widget build(BuildContext context) {
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E5EC)),
      ),
      child: Text(label, style: style),
    );

    if (hiddenRoles == null || hiddenRoles!.isEmpty) return chip;

    return Tooltip(
      waitDuration: const Duration(milliseconds: 600),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: .98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x4A000000), offset: Offset(0, 6), blurRadius: 16),
        ],
      ),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: 'Altri ruoli:\n',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          TextSpan(
            text: hiddenRoles!.join('\n'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
      child: chip,
    );
  }
}

class _CardOverflowTooltipText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int maxLines;

  const _CardOverflowTooltipText({
    required this.text,
    required this.style,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
        )..layout(maxWidth: constraints.maxWidth);

        final Widget textWidget = Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        );

        if (!painter.didExceedMaxLines) return textWidget;

        return Tooltip(
          message: text,
          waitDuration: const Duration(milliseconds: 600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: .98),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x4A000000), offset: Offset(0, 6), blurRadius: 16),
            ],
          ),
          child: textWidget,
        );
      },
    );
  }
}
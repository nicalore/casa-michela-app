import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InfoTab extends StatelessWidget
{
  const InfoTab({super.key});

  @override
  Widget build(BuildContext context)
  {
    final int currentYear = DateTime.now().year;
    const String appVersion = '0.0.7';

    //DocumentList
    final List<String> documents = [
      'Condizioni d\'uso',
      'Privacy policy',
      'Statuto dell\'Associazione',
      'Regolamento dell\'Associazione',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top: 16,
        left: 32,
        right: 32,
        bottom: 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...documents.map((title)
              {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _InfoDocumentCard(
                    title: title,
                    onTap: ()
                    {
                      //ActionPlaceholder
                    },
                  ),
                );
              }),
              
              const SizedBox(height: 48),
              
              //FooterSection
              Text(
                '© $currentYear Nicolò Calore\nVersione $appVersion\nATTENZIONE: Applicazione attualmente in sviluppo. Potrebbero verificarsi comportamenti inaspettati.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoDocumentCard extends StatefulWidget
{
  final String title;
  final VoidCallback onTap;

  const _InfoDocumentCard({
    required this.title,
    required this.onTap,
  });

  @override
  State<_InfoDocumentCard> createState() => _InfoDocumentCardState();
}

class _InfoDocumentCardState extends State<_InfoDocumentCard>
{
  bool _isHovering = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(()
      {
        _isHovering = true;
      }),
      onExit: (_) => setState(()
      {
        _isHovering = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 22,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovering ? const Color(0xFF003C82) : Colors.transparent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF003C82),
                ),
              ),
              
              Icon(
                Icons.chevron_right_rounded,
                color: _isHovering ? const Color(0xFF003C82) : const Color(0xFFB3B3B3),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
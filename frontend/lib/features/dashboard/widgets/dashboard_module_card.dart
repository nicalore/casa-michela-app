import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardModuleCard extends StatefulWidget
{
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? imageAsset;
  final VoidCallback onTap;

  const DashboardModuleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.imageAsset,
  }) : assert(
          icon != null || imageAsset != null,
          'Specificare icon oppure imageAsset',
        );

  @override
  State<DashboardModuleCard> createState() => _DashboardModuleCardState();
}

class _DashboardModuleCardState extends State<DashboardModuleCard>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _hover = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _hover = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 287,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: _hover ? const Color(0xFF003C82) : Colors.transparent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 23,
              top: 23,
              right: 23,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //HeaderSection
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF12A0D7),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: widget.imageAsset != null
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: Image.asset(
                                widget.imageAsset!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Icon(
                              widget.icon!,
                              color: Colors.white,
                              size: 26,
                            ),
                    ),
                    
                    const SizedBox(width: 23),
                    
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF003C82),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 42),
                
                //SubtitleSection
                Text(
                  widget.subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF464646),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/person_item.dart';

class PersonCard extends StatefulWidget 
{
  final PersonItem   person;
  final VoidCallback onTap;

  const PersonCard({
    super.key,
    required this.person,
    required this.onTap,
  });

  @override
  State<PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<PersonCard> 
{
  bool _isHovering = false;

  Widget _buildAvatar() 
  {
    final String initials = '${widget.person.firstName[0]}${widget.person.lastName[0]}'.toUpperCase();
    
    final Widget fallbackWidget = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize:   22,
          fontWeight: FontWeight.w700,
          color:      const Color(0xFF64748B),
        ),
      ),
    );

    return Container(
      width:  68,
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.hardEdge,
      child: widget.person.profileImageUrl != null
          ? Image.network(
              widget.person.profileImageUrl!,
              fit: BoxFit.cover,
              // Se il caricamento fallisce (CORS, 404, connessione persa) mostra le iniziali
              errorBuilder: (context, error, stackTrace) => fallbackWidget,
            )
          : fallbackWidget,
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit:  (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration:   const Duration(milliseconds: 180),
          curve:      Curves.easeOut,
          width:      380,
          constraints: const BoxConstraints(minHeight: 140),
          padding:    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isHovering ? const Color(0xFF003C82) : Colors.transparent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color:      Color(0x0A000000),
                offset:     Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar gestito dal metodo helper
              _buildAvatar(),
              const SizedBox(width: 16),
              // Dettagli
              Expanded(
                child: Column(
                  mainAxisSize:      MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.person.firstName} ${widget.person.lastName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   18,
                        fontWeight: FontWeight.w700,
                        color:      const Color(0xFF003C82),
                        height:     1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing:    6,
                      runSpacing: 6,
                      children: widget.person.roles.map((role) 
                      {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical:   4,
                          ),
                          decoration: BoxDecoration(
                            color:        const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                            border:       Border.all(color: const Color(0xFFE0E5EC)),
                          ),
                          child: Text(
                            role,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize:   12,
                              fontWeight: FontWeight.w600,
                              color:      const Color(0xFF64748B),
                            ),
                          ),
                        );
                      }).toList(),
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
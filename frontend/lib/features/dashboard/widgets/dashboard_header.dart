import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'live_clock.dart';

class DashboardHeader extends StatelessWidget
{
  final bool isMenuOpen;
  final VoidCallback onProfileTap;

  final String fullName;
  final String? profileImageUrl;

  const DashboardHeader({
    super.key,
    required this.isMenuOpen,
    required this.onProfileTap,
    required this.fullName,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context)
  {
    final viewportWidth = MediaQuery.of(context).size.width;

    //Hide clock below 1024px
    final bool showClock = viewportWidth > 1024;

    return Positioned(
      left: 40,
      right: 40,
      top: 20,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(100),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              spreadRadius: 19,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            //MainLayer
            Row(
              children: [
                //Logo
                SizedBox(
                  width: 54,
                  height: 54,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),

                const Spacer(),

                //Profile
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 250,
                      ),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onProfileTap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                    color: const Color(0xFF003C82),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              AnimatedRotation(
                                turns: isMenuOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: Color(0xFF003C82),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    //Avatar
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF003C82),
                          width: 1,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl!)
                            : null,
                        child: profileImageUrl == null
                            ? const Icon(
                                Icons.person,
                                color: Color(0xFF003C82),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            //IndependentLayer
            if (showClock)
              const IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: LiveClock(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
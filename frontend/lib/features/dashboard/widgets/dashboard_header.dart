import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import 'live_clock.dart';

const Color _headerShadow = Color(0x14000000);

class DashboardHeader extends StatefulWidget
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
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader>
{
  static const double _horizontalMargin = 40;
  static const double _topMargin = 20;
  static const double _barHeight = 80;
  static const double _logoSize = 54;
  static const double _avatarSize = 54;
  static const double _maxNameWidth = 250;

  // Below this width the bar is too narrow to host the clock without colliding
  // with the name on the right.
  static const double _clockMinViewportWidth = 1024;

  late final String _sessionCacheBuster;

  @override
  void initState()
  {
    super.initState();

    // Computed once per mount: the value must stay stable across rebuilds, or
    // every rebuild would produce a new URL and refetch the image.
    _sessionCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
  }

  String? get _absoluteImageUrl
  {
    final url = widget.profileImageUrl;

    if (url == null || url.isEmpty)
    {
      return null;
    }

    final absoluteUrl = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : '${ApiConfig.baseUrl}$url';

    // The query parameter defeats the browser cache, so a freshly uploaded
    // picture replaces the old one instead of showing the stale copy.
    return '$absoluteUrl?v=$_sessionCacheBuster';
  }

  // Works on the already concatenated full name, splitting on whitespace,
  // because first and last name are not available separately here.
  String _initials(String fullName)
  {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty)
    {
      return '';
    }

    if (parts.length == 1)
    {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildProfileButton()
  {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxNameWidth),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onProfileTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: widget.isMenuOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? imageUrl)
  {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary, width: 1),
      ),
      // Keying on the URL forces a rebuild when the picture changes, which a
      // plain backgroundImage swap would not do.
      child: CircleAvatar(
        key: ValueKey(imageUrl),
        backgroundColor: Colors.white,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        child: imageUrl == null
            ? Text(
                _initials(widget.fullName),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final showClock = MediaQuery.of(context).size.width > _clockMinViewportWidth;
    final imageUrl = _absoluteImageUrl;

    return Positioned(
      left: _horizontalMargin,
      right: _horizontalMargin,
      top: _topMargin,
      child: Container(
        height: _barHeight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          boxShadow: const [
            BoxShadow(color: _headerShadow, blurRadius: 24, spreadRadius: 19),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                SizedBox(
                  width: _logoSize,
                  height: _logoSize,
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildProfileButton(),
                    const SizedBox(width: 12),
                    _buildAvatar(imageUrl),
                  ],
                ),
              ],
            ),
            // Centred on the bar independently of the row above, so it stays
            // centred on the page rather than in the space left over.
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
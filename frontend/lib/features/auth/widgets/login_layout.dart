import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import 'login_text_field.dart';

const Color _bodyText = Color(0xFF6B7280);
const Color _labelText = Color(0xFF1A1A1A);
const Color _linkHover = Color(0xFF002244);

const String _fontFamily = 'Plus Jakarta Sans';

const double _narrowBreakpoint = 600;
const double _tabletBreakpoint = 600.0;
const double _wideViewportThreshold = 1300;
const double _maxCardWidth = 1160.0;
const double _fieldHeight = 56;

// Width kept from the previous dedicated login button; in the narrow layouts
// the surrounding SizedBox overrides it and the button fills the row.
const double _loginButtonWidth = 190;

class LoginLayout extends StatefulWidget
{
  final double width;
  final double height;

  const LoginLayout({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  State<LoginLayout> createState() => _LoginLayoutState();
}

class _LoginLayoutState extends State<LoginLayout>
{
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  @override
  void dispose()
  {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async
  {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Inserisci nome utente e password per accedere.',
        isError: true,
      );

      return;
    }

    try
    {
      // login() sets authState to passwordChangeRequired or authenticated
      // internally, and the global router redirect listens to it: navigating to
      // the dashboard here is enough, the redirect takes over when a password
      // change is pending.
      await _apiService.login(username: username, password: password);

      if (!mounted)
      {
        return;
      }

      context.replace('/dashboard');
    }
    on DioException catch (e)
    {
      if (!mounted)
      {
        return;
      }

      // 401 and 423 share the same message on purpose: telling the user that
      // the account is locked would confirm that the username exists.
      final message = switch (e.response?.statusCode)
      {
        401 || 423 => "Nome utente o password non validi. Dopo 5 tentativi errati, l'account verrà bloccato per 20 minuti.",
        403 => "Account disabilitato. Se ritieni ci sia un errore, contatta l'Associazione.",
        _ => 'Errore imprevisto. Riprova più tardi.',
      };

      CustomSnackBar.show(context: context, message: message, isError: true);
    }
  }

  void _showForgotPasswordDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'ForgotPassword',
      builder: (context) => const _ForgotPasswordDialogContent(),
    );
  }

  // kIsWeb is true in every browser, phones included, so this is not a
  // desktop-versus-mobile switch: on the web build the layout below always
  // wins, and index.html scales it down for touch devices through its virtual
  // viewport. _buildMobileLayout is reached only by the native Android and iOS
  // builds.
  @override
  Widget build(BuildContext context)
  {
    return kIsWeb ? _buildWebLayout(context) : _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context)
  {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > _tabletBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: isTablet ? 500.0 : double.infinity,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Casa Michela',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                _LoginRow(
                  label: 'Nome utente',
                  controller: _usernameController,
                  isNarrow: true,
                ),
                const SizedBox(height: 16),
                _LoginRow(
                  label: 'Password',
                  obscure: true,
                  controller: _passwordController,
                  isNarrow: true,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    label: 'ACCEDI',
                    width: _loginButtonWidth,
                    onPressed: _login,
                  ),
                ),
                const SizedBox(height: 16),
                _AnimatedTextLink(
                  text: 'Password dimenticata?',
                  onTap: _showForgotPasswordDialog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegalNotice()
  {
    // RichText has no const constructor, so const sits on the span tree.
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: _bodyText,
          height: 1.5,
        ),
        children: [
          TextSpan(text: 'Accedendo, accetti le '),
          TextSpan(
            text: "Condizioni d'Uso",
            style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: " e l'"),
          TextSpan(
            text: 'Informativa sulla Privacy',
            style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: '.'),
        ],
      ),
    );
  }

  Widget _buildCredentialsCard({required bool isNarrow})
  {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 25 : 50, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LoginRow(
            label: 'Nome utente',
            controller: _usernameController,
            isNarrow: isNarrow,
          ),
          SizedBox(height: isNarrow ? 20 : 32),
          _LoginRow(
            label: 'Password',
            obscure: true,
            controller: _passwordController,
            isNarrow: isNarrow,
          ),
          SizedBox(height: isNarrow ? 32 : 40),
          if (isNarrow) ...[
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                label: 'ACCEDI',
                width: _loginButtonWidth,
                onPressed: _login,
              ),
            ),
            const SizedBox(height: 20),
            _AnimatedTextLink(
              text: 'Password dimenticata?',
              onTap: _showForgotPasswordDialog,
            ),
          ]
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AnimatedTextLink(
                  text: 'Password dimenticata?',
                  onTap: _showForgotPasswordDialog,
                ),
                AppPrimaryButton(
                  label: 'ACCEDI',
                  width: _loginButtonWidth,
                  onPressed: _login,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context)
  {
    final viewportWidth = MediaQuery.of(context).size.width;
    final currentYear = DateTime.now().year;

    final isNarrow = viewportWidth < _narrowBreakpoint;

    // Clamped at zero because the viewport can momentarily be narrower than the
    // horizontal margins while the window is being resized.
    final cardWidth = math.max(
      0.0,
      viewportWidth > _wideViewportThreshold ? _maxCardWidth : viewportWidth - 80,
    );

    return Container(
      width: widget.width,
      height: widget.height,
      color: AppTheme.pageBackground,
      child: Stack(
        children: [
          const CornerGlow(corner: GlowCorner.topRight),
          const CornerGlow(corner: GlowCorner.bottomLeft),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints)
              {
                // The three pieces below work together and none can be removed
                // on its own: the ConstrainedBox forces the content to be at
                // least as tall as the viewport, IntrinsicHeight resolves that
                // height for the Column, and only then can the Spacer push the
                // footer down. Without IntrinsicHeight the Spacer has no
                // bounded height to expand into inside a scroll view.
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 20 : 40,
                        vertical: 40,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: cardWidth),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/images/logo.png',
                                      width: 185,
                                      height: 185,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(width: 40),
                                    const Text(
                                      'Associazione Casa Michela',
                                      style: TextStyle(
                                        fontFamily: _fontFamily,
                                        fontSize: 76,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: cardWidth),
                              child: _buildCredentialsCard(isNarrow: isNarrow),
                            ),
                            const SizedBox(height: 40),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: cardWidth),
                              child: _buildLegalNotice(),
                            ),
                            const Spacer(),
                            const SizedBox(height: 40),
                            Text(
                              '© $currentYear Nicolò Calore\nATTENZIONE: Applicazione attualmente in sviluppo. Potrebbero verificarsi comportamenti inaspettati.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: _fontFamily,
                                color: _bodyText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginRow extends StatelessWidget
{
  final String label;
  final bool obscure;
  final TextEditingController controller;
  final bool isNarrow;

  const _LoginRow({
    required this.label,
    required this.controller,
    required this.isNarrow,
    this.obscure = false,
  });

  TextStyle _labelStyle(double fontSize)
  {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: _labelText,
    );
  }

  Widget _buildField()
  {
    return SizedBox(
      height: _fieldHeight,
      child: LoginTextField(controller: controller, obscureText: obscure),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (isNarrow)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle(18)),
          const SizedBox(height: 8),
          _buildField(),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Text(label, style: _labelStyle(22)),
        ),
        const SizedBox(width: 20),
        Expanded(child: _buildField()),
      ],
    );
  }
}

class _AnimatedTextLink extends StatefulWidget
{
  final String text;
  final VoidCallback onTap;

  const _AnimatedTextLink({required this.text, required this.onTap});

  @override
  State<_AnimatedTextLink> createState() => _AnimatedTextLinkState();
}

class _AnimatedTextLinkState extends State<_AnimatedTextLink>
{
  // Width of the underline when hovered, sized for the current label. It does
  // not follow the text, so a longer label would overflow it.
  static const double _underlineWidth = 175;

  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isHovered ? _linkHover : AppTheme.primary,
              ),
              child: Text(widget.text),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuint,
              height: 2,
              width: _isHovered ? _underlineWidth : 0,
              decoration: BoxDecoration(
                color: _linkHover,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordDialogContent extends StatefulWidget
{
  const _ForgotPasswordDialogContent();

  @override
  State<_ForgotPasswordDialogContent> createState() => _ForgotPasswordDialogContentState();
}

class _ForgotPasswordDialogContentState extends State<_ForgotPasswordDialogContent>
{
  final TextEditingController _usernameController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isSending = false;

  @override
  void dispose()
  {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async
  {
    final username = _usernameController.text.trim();

    if (username.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Inserisci il tuo nome utente', isError: true);
      return;
    }

    setState(() => _isSending = true);

    try
    {
      await _apiService.requestPasswordReset(username: username);

      if (mounted)
      {
        // Deliberately non committal: confirming that the username exists would
        // turn this form into an account enumeration oracle.
        CustomSnackBar.show(
          context: context,
          message: 'Se il nome utente è corretto, riceverai un link via email.',
          isError: false,
        );

        Navigator.of(context).pop();
      }
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: "Errore durante l'invio. Riprova più tardi.",
          isError: true,
        );
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recupero Password',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  StaticHoverIconButton(
                    icon: Icons.close,
                    color: AppTheme.primary,
                    hoverColor: AppTheme.iconHover,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inserisci il nome utente associato al tuo account. '
                    "Se esiste, ti invieremo un link di recupero all'indirizzo email registrato.\n"
                    "Se non ricordi il tuo nome utente, contatta l'Associazione.",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: _bodyText,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Nome utente',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Es. mario.rossi',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        color: AppTheme.hint,
                        fontWeight: FontWeight.w500,
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 32),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedActionButton(
                      text: 'ANNULLA',
                      icon: Icons.cancel_outlined,
                      baseColor: AppTheme.danger,
                      hoverColor: AppTheme.dangerHover,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text: _isSending ? 'INVIO IN CORSO...' : 'INVIA LINK',
                      icon: Icons.send_rounded,
                      baseColor: AppTheme.primary,
                      hoverColor: AppTheme.primaryHover,
                      onPressed: _isSending ? () {} : _handleSend,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
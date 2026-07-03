import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/api_service.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/shared_components.dart';
import 'login_button.dart';
import 'login_text_field.dart';

class LoginLayout extends StatefulWidget
{
  final double width;
  final double height;

  const LoginLayout
  ({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  State<LoginLayout> createState() => _LoginLayoutState();
}

class _LoginLayoutState extends State<LoginLayout>
{
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService         = ApiService();

  @override
  void dispose()
  {
    //ReleaseResources
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
      CustomSnackBar.show
      (
        context: context,
        message: 'Inserisci nome utente e password per accedere.',
        isError: true,
      );
      
      return;
    }

    try
    {
      //PerformLoginApiCall
      // apiService.login imposta internamente authState a
      // AuthState.passwordChangeRequired o AuthState.authenticated a
      // seconda della risposta del backend. Non serve più decidere qui
      // dove navigare: il redirect globale del router (che ascolta
      // authState) porta l'utente sulla schermata corretta anche se qui
      // proviamo comunque ad andare in dashboard.
      await _apiService.login
      (
        username: username,
        password: password,
      );

      if (!mounted) return;

      context.replace('/dashboard');
    }
    on DioException catch (e)
    {
      if (!mounted) return;

      String message = 'Errore imprevisto. Riprova più tardi.';

      switch (e.response?.statusCode)
      {
        case 401:
          message = 'Nome utente o password non validi. Dopo 5 tentativi errati, l\'account verrà bloccato per 20 minuti.';
          break;

        case 403:
          message = 'Account disabilitato. Se ritieni ci sia un errore, contatta l\'Associazione.';
          break;

        case 423:
          message = 'Nome utente o password non validi. Dopo 5 tentativi errati, l\'account verrà bloccato per 20 minuti.';
          break;
      }

      CustomSnackBar.show
      (
        context: context,
        message: message,
        isError: true,
      );
    }
  }

  void _showForgotPasswordDialog(BuildContext context)
  {
    showGeneralDialog
    (
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ForgotPassword',
      barrierColor: Colors.black.withValues(alpha: .15),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;
        
        return BackdropFilter
        (
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition
          (
            opacity: animation,
            child: ScaleTransition
            (
              scale: CurvedAnimation
              (
                parent: animation,
                curve: Curves.easeOutBack,
                reverseCurve: Curves.easeIn,
              ),
              child: const _ForgotPasswordDialogContent(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (kIsWeb)
    {
      return _buildWebLayout(context);
    }
    else
    {
      return _buildMobileLayout(context);
    }
  }

  //BuildMobileLayout
  Widget _buildMobileLayout(BuildContext context)
  {
    final double width    = MediaQuery.of(context).size.width;
    final bool   isTablet = width > 600.0;

    return Scaffold
    (
      backgroundColor: const Color(0xFFF4F7F9),
      body: Center
      (
        child: SingleChildScrollView
        (
          child: Container
          (
            width: isTablet ? 500.0 : double.infinity,
            padding: const EdgeInsets.all(24.0),
            child: Column
            (
              mainAxisSize: MainAxisSize.min,
              children: 
              [
                Image.asset
                (
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text
                (
                  'Casa Michela',
                  textAlign: TextAlign.center,
                  style: TextStyle
                  (
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003C82),
                  ),
                ),
                const SizedBox(height: 32),
                _LoginRow
                (
                  label: 'Nome utente',
                  controller: _usernameController,
                  isNarrow: true,
                ),
                const SizedBox(height: 16),
                _LoginRow
                (
                  label: 'Password',
                  obscure: true,
                  controller: _passwordController,
                  isNarrow: true,
                ),
                const SizedBox(height: 24),
                SizedBox
                (
                  width: double.infinity,
                  child: LoginButton(onPressed: _login),
                ),
                const SizedBox(height: 16),
                _AnimatedTextLink
                (
                  text: 'Password dimenticata?',
                  onTap: () => _showForgotPasswordDialog(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //BuildWebLayout
  Widget _buildWebLayout(BuildContext context)
  {
    final viewportWidth = MediaQuery.of(context).size.width;
    final currentYear   = DateTime.now().year;

    final isNarrow  = viewportWidth < 600;
    final cardWidth = math.max(0.0, viewportWidth > 1300 ? 1160.0 : viewportWidth - 80);

    return Container
    (
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFF4F7F9),
      child: Stack
      (
        children: 
        [
          Positioned
          (
            right: -800,
            top: -800,
            child: IgnorePointer
            (
              child: Container
              (
                width: 1600,
                height: 1600,
                decoration: const BoxDecoration
                (
                  shape: BoxShape.circle,
                  gradient: RadialGradient
                  (
                    colors: 
                    [
                      Color(0x4D003C82),
                      Color(0x22003C82),
                      Color(0x00003C82),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned
          (
            left: -800,
            bottom: -800,
            child: IgnorePointer
            (
              child: Container
              (
                width: 1600,
                height: 1600,
                decoration: const BoxDecoration
                (
                  shape: BoxShape.circle,
                  gradient: RadialGradient
                  (
                    colors: 
                    [
                      Color(0x4D003C82),
                      Color(0x22003C82),
                      Color(0x00003C82),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill
          (
            child: LayoutBuilder
            (
              builder: (context, constraints)
              {
                return SingleChildScrollView
                (
                  child: ConstrainedBox
                  (
                    constraints: BoxConstraints
                    (
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding
                    (
                      padding: EdgeInsets.symmetric
                      (
                        horizontal: isNarrow ? 20 : 40,
                        vertical: 40,
                      ),
                      child: IntrinsicHeight
                      (
                        child: Column
                        (
                          children: 
                          [
                            const SizedBox(height: 20),
                            ConstrainedBox
                            (
                              constraints: BoxConstraints(maxWidth: cardWidth),
                              child: FittedBox
                              (
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row
                                (
                                  mainAxisSize: MainAxisSize.min,
                                  children: 
                                  [
                                    Image.asset
                                    (
                                      'assets/images/logo.png',
                                      width: 185,
                                      height: 185,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(width: 40),
                                    const Text
                                    (
                                      'Associazione Casa Michela',
                                      style: TextStyle
                                      (
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 76,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF003C82),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                            ConstrainedBox
                            (
                              constraints: BoxConstraints(maxWidth: cardWidth),
                              child: Container
                              (
                                decoration: BoxDecoration
                                (
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: 
                                  [
                                    BoxShadow
                                    (
                                      color: const Color(0xFF000000).withValues(alpha: 0.04),
                                      offset: const Offset(0, 4),
                                      blurRadius: 16,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                padding: EdgeInsets.symmetric
                                (
                                  horizontal: isNarrow ? 25 : 50,
                                  vertical: 40,
                                ),
                                child: Column
                                (
                                  mainAxisSize: MainAxisSize.min,
                                  children: 
                                  [
                                    _LoginRow
                                    (
                                      label: 'Nome utente',
                                      controller: _usernameController,
                                      isNarrow: isNarrow,
                                    ),
                                    SizedBox(height: isNarrow ? 20 : 32),
                                    _LoginRow
                                    (
                                      label: 'Password',
                                      obscure: true,
                                      controller: _passwordController,
                                      isNarrow: isNarrow,
                                    ),
                                    physicsSpacer(isNarrow ? 32 : 40),
                                    if (isNarrow) ...
                                    [
                                      SizedBox
                                      (
                                        width: double.infinity,
                                        child: LoginButton(onPressed: _login),
                                      ),
                                      const SizedBox(height: 20),
                                      _AnimatedTextLink
                                      (
                                        text: 'Password dimenticata?',
                                        onTap: () => _showForgotPasswordDialog(context),
                                      ),
                                    ] 
                                    else ...
                                    [
                                      Row
                                      (
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: 
                                        [
                                          _AnimatedTextLink
                                          (
                                            text: 'Password dimenticata?',
                                            onTap: () => _showForgotPasswordDialog(context),
                                          ),
                                          LoginButton(onPressed: _login),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            ConstrainedBox
                            (
                              constraints: BoxConstraints(maxWidth: cardWidth),
                              child: RichText
                              (
                                textAlign: TextAlign.center,
                                text: const TextSpan
                                (
                                  style: TextStyle
                                  (
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                    height: 1.5,
                                  ),
                                  children: 
                                  [
                                    TextSpan(text: 'Accedendo, accetti le '),
                                    TextSpan
                                    (
                                      text: 'Condizioni d\'Uso',
                                      style: TextStyle
                                      (
                                        color: Color(0xFF003C82),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: ' e l\''),
                                    TextSpan
                                    (
                                      text: 'Informativa sulla Privacy',
                                      style: TextStyle
                                      (
                                        color: Color(0xFF003C82),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 40),
                            Text
                            (
                              '© $currentYear Nicolò Calore\nATTENZIONE: Applicazione attualmente in sviluppo. Potrebbero verificarsi comportamenti inaspettati.',
                              textAlign: TextAlign.center,
                              style: const TextStyle
                              (
                                fontFamily: 'Plus Jakarta Sans',
                                color: Color(0xFF6B7280),
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

  Widget physicsSpacer(double height) => SizedBox(height: height);
}

class _LoginRow extends StatelessWidget
{
  final String label;
  final bool obscure;
  final TextEditingController controller;
  final bool isNarrow;

  const _LoginRow
  ({
    required this.label,
    required this.controller,
    required this.isNarrow,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context)
  {
    if (isNarrow)
    {
      return Column
      (
        crossAxisAlignment: CrossAxisAlignment.start,
        children: 
        [
          Text
          (
            label,
            style: const TextStyle
            (
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox
          (
            height: 56,
            child: LoginTextField
            (
              controller: controller,
              obscureText: obscure,
            ),
          ),
        ],
      );
    }

    return Row
    (
      children: 
      [
        SizedBox
        (
          width: 260,
          child: Text
          (
            label,
            style: const TextStyle
            (
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded
        (
          child: SizedBox
          (
            height: 56,
            child: LoginTextField
            (
              controller: controller,
              obscureText: obscure,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedTextLink extends StatefulWidget
{
  final String text;
  final VoidCallback onTap;

  const _AnimatedTextLink
  ({
    required this.text,
    required this.onTap,
  });

  @override
  State<_AnimatedTextLink> createState() => _AnimatedTextLinkState();
}

class _AnimatedTextLinkState extends State<_AnimatedTextLink>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion
    (
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector
      (
        onTap: widget.onTap,
        child: Column
        (
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            AnimatedDefaultTextStyle
            (
              duration: const Duration(milliseconds: 200),
              style: TextStyle
              (
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isHovered ? const Color(0xFF002244) : const Color(0xFF003C82),
              ),
              child: Text(widget.text),
            ),
            const SizedBox(height: 2),
            AnimatedContainer
            (
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuint,
              height: 2,
              width: _isHovered ? 175 : 0, 
              decoration: BoxDecoration
              (
                color: const Color(0xFF002244),
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
  final ApiService            _apiService         = ApiService();
  bool                        _isSending          = false;

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
      CustomSnackBar.show
      (
        context: context,
        message: 'Inserisci il tuo nome utente',
        isError: true,
      );

      return;
    }

    setState(() => _isSending = true);

    try
    {
      await _apiService.requestPasswordReset(username: username);

      if (mounted)
      {
        CustomSnackBar.show
        (
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
        CustomSnackBar.show
        (
          context: context,
          message: 'Errore durante l\'invio. Riprova più tardi.',
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
    return Dialog
    (
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container
      (
        width: 500,
        decoration: BoxDecoration
        (
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const
          [
            BoxShadow
            (
              color: Color(0x1A000000),
              offset: Offset(0, 8),
              blurRadius: 24,
            )
          ],
        ),
        child: Column
        (
          mainAxisSize: MainAxisSize.min,
          children:
          [
            Padding
            (
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row
              (
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children:
                [
                  Text
                  (
                    'Recupero Password',
                    style: GoogleFonts.plusJakartaSans
                    (
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF003C82),
                    ),
                  ),
                  StaticHoverIconButton
                  (
                    icon: Icons.close,
                    color: const Color(0xFF003C82),
                    hoverColor: const Color(0xFFE3F2FD),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            Padding
            (
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
              child: Column
              (
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                [
                  Text
                  (
                    'Inserisci il nome utente associato al tuo account. '
                    'Se esiste, ti invieremo un link di recupero all\'indirizzo email registrato.\n'
                    'Se non ricordi il tuo nome utente, contatta l\'Associazione.',
                    style: GoogleFonts.plusJakartaSans
                    (
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding
                  (
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text
                    (
                      'Nome utente',
                      style: GoogleFonts.plusJakartaSans
                      (
                        color: const Color(0xFF003C82),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextField
                  (
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    style: GoogleFonts.plusJakartaSans
                    (
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration
                    (
                      hintText: 'Es. mario.rossi',
                      hintStyle: GoogleFonts.plusJakartaSans
                      (
                        fontSize: 18,
                        color: const Color(0xFFB3B3B3),
                        fontWeight: FontWeight.w500,
                      ),
                      focusedBorder: const UnderlineInputBorder
                      (
                        borderSide: BorderSide(color: Color(0xFF003C82), width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding
            (
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 32),
              child: Row
              (
                children:
                [
                  Expanded
                  (
                    child: AnimatedActionButton
                    (
                      text: 'ANNULLA',
                      icon: Icons.cancel_outlined,
                      baseColor: const Color(0xFFE53935),
                      hoverColor: const Color(0xFFEF5350),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded
                  (
                    child: AnimatedActionButton
                    (
                      text: _isSending ? 'INVIO IN CORSO...' : 'INVIA LINK',
                      icon: Icons.send_rounded,
                      baseColor: const Color(0xFF003C82),
                      hoverColor: const Color(0xFF004D99),
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
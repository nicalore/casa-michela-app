
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import 'auth_pill_page.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/dialog_density.dart';
import '../../../shared/widgets/snackbar.dart';

const double _loginButtonWidth = 190;
const double _maxCardWidth = 1160;
const double _narrowBreakpoint = 600;

const double _labelColumnWidth = 200;

// Below this width the label goes above the field.
const double _labelBesideFieldFrom = 480;

const double _authButtonHeight = 52;
const double _authButtonFontSize = 14;

// Below the wide window: a title of its own size, a card as wide as the password pages'.
const double _denseCardWidth = 560;
const double _denseLogo = 76;
const double _denseTitle = 30;
const double _minimalLogo = 64;
const double _minimalTitle = 24;
const double _denseLogoGap = 18;
const double _minimalLogoGap = 12;
const double _denseGap = 24;
const double _denseFieldGap = 14;
const double _denseLabelGap = 6;
const double _denseLabelSize = 14;
const double _denseButtonHeight = 40;
const double _denseButtonFontSize = 13;
const double _denseLoginButtonWidth = 150;
const double _denseButtonGap = 12;
const EdgeInsets _denseCardPadding = EdgeInsets.fromLTRB(24, 22, 24, 24);

// Stops at the line's ends so both colours show even on short lines.
const LinearGradient _titleGradient = LinearGradient(
  colors: [AppTheme.trialOcean, AppTheme.trialViolet],
  stops: [0.15, 0.95],
);

// The label is long: with the usual 30 it wraps on a phone-sized screen.
const double _secondaryButtonPadding = 20;

class LoginLayout extends StatefulWidget
{
  const LoginLayout({super.key});

  @override
  State<LoginLayout> createState() => _LoginLayoutState();
}

class _LoginLayoutState extends State<LoginLayout>
{
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  @override
  void initState()
  {
    super.initState();

    final String? notice = _apiService.takeSignInNotice();

    if (notice != null)
    {
      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted)
        {
          CustomSnackBar.show(context: context, message: notice, tone: SnackBarTone.warning);
        }
      });
    }
  }

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
      // login() updates authState; the router redirect handles a pending password change.
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

      // 401 and 423 share a message: revealing a lock would confirm the username exists.
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

  Widget _buildTitle(bool isNarrow)
  {
    return FittedBox(
      fit: BoxFit.fitWidth,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: isNarrow ? 96 : 130,
            height: isNarrow ? 96 : 130,
            fit: BoxFit.contain,
          ),
          SizedBox(width: isNarrow ? 20 : 28),
          // The text only masks the gradient; keep the font's line height or descenders clip.
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => _titleGradient.createShader(bounds),
            child: Text(
              'Associazione Casa Michela',
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isNarrow ? 34 : 58,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [above]: the label over the field at any width (below the wide window).
  Widget _labelledField(String label, Widget field, {bool above = false})
  {
    final Widget text = Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: above ? _denseLabelSize : 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialOcean,
      ),
    );

    if (above)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [text, const SizedBox(height: _denseLabelGap), field],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _labelBesideFieldFrom)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 8), field],
          );
        }

        return Row(
          children: [
            SizedBox(width: _labelColumnWidth, child: text),
            Expanded(child: field),
          ],
        );
      },
    );
  }

  Widget _buildCredentials(bool isNarrow)
  {
    final Widget forgotten = AppGradientButton(
      label: 'PASSWORD DIMENTICATA?',
      icon: Icons.lock_reset_rounded,
      gradient: AppTheme.dismissGradient,
      accent: AppTheme.trialViolet,
      height: _authButtonHeight,
      fontSize: _authButtonFontSize,
      horizontalPadding: _secondaryButtonPadding,
      onPressed: _showForgotPasswordDialog,
    );

    final Widget enter = AppGradientButton(
      label: 'ACCEDI',
      icon: Icons.login_rounded,
      height: _authButtonHeight,
      fontSize: _authButtonFontSize,
      onPressed: _login,
    );

    return AppDialogPill(
      expand: true,
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 24 : 44, vertical: isNarrow ? 24 : 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labelledField(
            'Nome utente',
            AppTextField(
              controller: _usernameController,
              label: 'Nome utente',
              showLabel: false,
              hintText: '',
              onSubmitted: (_) => _login(),
            ),
          ),
          SizedBox(height: isNarrow ? 16 : 22),
          _labelledField(
            'Password',
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              showLabel: false,
              hintText: '',
            ),
          ),
          const SizedBox(height: 28),
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.center,
            spacing: 16,
            overflowSpacing: 16,
            children: [
              forgotten,
              SizedBox(width: _loginButtonWidth, child: enter),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNote({required bool dense})
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'ATTENZIONE: ',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.modifiedAccent,
                ),
              ),
              const TextSpan(
                text: 'applicazione attualmente in sviluppo. '
                    'Potrebbero verificarsi comportamenti inaspettati.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: dense ? 13 : 14.5,
            fontWeight: FontWeight.w600,
            height: 1.5,
            color: AppTheme.trialInk.withValues(alpha: 0.82),
          ),
        ),
        SizedBox(height: dense ? 4 : 6),
        Text(
          '© ${DateTime.now().year} Nicolò Calore',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: dense ? 12.5 : 13.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
      ],
    );
  }

  // Below the wide window: logo and name at their own size, the logo over the name on minimal windows.
  Widget _buildDenseTitle(bool minimal)
  {
    final Widget logo = Image.asset(
      'assets/images/logo.png',
      width: minimal ? _minimalLogo : _denseLogo,
      height: minimal ? _minimalLogo : _denseLogo,
      fit: BoxFit.contain,
    );

    final Widget name = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => _titleGradient.createShader(bounds),
      child: Text(
        'Associazione Casa Michela',
        maxLines: 1,
        style: GoogleFonts.plusJakartaSans(
          fontSize: minimal ? _minimalTitle : _denseTitle,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );

    // Narrower than the name on the smallest windows: it shrinks, never clips.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: minimal
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [logo, const SizedBox(height: _minimalLogoGap), name],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [logo, const SizedBox(width: _denseLogoGap), name],
            ),
    );
  }

  Widget _buildDenseCredentials(bool minimal)
  {
    final Widget forgotten = AppGradientButton(
      label: 'PASSWORD DIMENTICATA?',
      icon: Icons.lock_reset_rounded,
      gradient: AppTheme.dismissGradient,
      accent: AppTheme.trialViolet,
      height: _denseButtonHeight,
      fontSize: _denseButtonFontSize,
      horizontalPadding: _secondaryButtonPadding,
      onPressed: _showForgotPasswordDialog,
    );

    final Widget enter = AppGradientButton(
      label: 'ACCEDI',
      icon: Icons.login_rounded,
      height: _denseButtonHeight,
      fontSize: _denseButtonFontSize,
      onPressed: _login,
    );

    return AppDialogPill(
      expand: true,
      padding: _denseCardPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labelledField(
            'Nome utente',
            AppTextField(
              controller: _usernameController,
              label: 'Nome utente',
              showLabel: false,
              hintText: '',
              onSubmitted: (_) => _login(),
            ),
            above: true,
          ),
          const SizedBox(height: _denseFieldGap),
          _labelledField(
            'Password',
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              showLabel: false,
              hintText: '',
            ),
            above: true,
          ),
          const SizedBox(height: _denseGap),
          // Minimal: the way in first, as wide as the card.
          if (minimal) ...[
            enter,
            const SizedBox(height: _denseButtonGap),
            forgotten,
          ]
          else
            Row(
              children: [
                Expanded(child: Align(alignment: Alignment.centerLeft, child: forgotten)),
                const SizedBox(width: _denseButtonGap),
                SizedBox(width: _denseLoginButtonWidth, child: enter),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDense(bool minimal)
  {
    return AuthPageBackground(
      watermark: false,
      child: Center(
        child: ScrollEdgeFade(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: minimal ? 12 : 20, vertical: _denseGap),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _denseCardWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDenseTitle(minimal),
                    const SizedBox(height: _denseGap),
                    // Fields as low as a dense dialog's.
                    AppDialogDensity(dense: true, child: _buildDenseCredentials(minimal)),
                    const SizedBox(height: _denseGap),
                    _buildNote(dense: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final AppWindowSize size = AppBreakpoints.of(context);

    if (size.isDense)
    {
      return _buildDense(size.isMinimal);
    }

    final double width = MediaQuery.sizeOf(context).width;
    final bool isNarrow = width < _narrowBreakpoint;

    return AuthPageBackground(
      watermark: false,
      child: Center(
        child: ScrollEdgeFade(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 20 : 40, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxCardWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTitle(isNarrow),
                  SizedBox(height: isNarrow ? 32 : 48),
                  _buildCredentials(isNarrow),
                  const SizedBox(height: 34),
                  _buildNote(dense: false),
                ],
              ),
            ),
          ),
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
        // Non-committal on purpose: confirming the username exists would leak accounts.
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
    return AppDialogStack(
      eyebrow: 'Accesso',
      title: 'Recupero password',
      maxWidth: 560,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'INVIA LINK',
          icon: Icons.send_rounded,
          busy: _isSending,
          height: _authButtonHeight,
          fontSize: _authButtonFontSize,
          onPressed: _handleSend,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Text(
            'Inserisci il nome utente associato al tuo account. Se esiste, ti '
            "invieremo un link di recupero all'indirizzo email registrato.\n\n"
            "Se non ricordi il tuo nome utente, contatta l'Associazione.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
        AppDialogPill(
          expand: true,
          child: AppTextField(
            controller: _usernameController,
            label: 'Nome utente',
            hintText: '',
            onSubmitted: (_) => _handleSend(),
            nothingAbove: true,
          ),
        ),
      ],
    );
  }
}

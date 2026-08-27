
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/password_field.dart';
import 'auth_pill_page.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';

const double _loginButtonWidth = 190;
const double _maxCardWidth = 1160;
const double _narrowBreakpoint = 600;

const double _labelColumnWidth = 200;

// Below this width the label goes above the field.
const double _labelBesideFieldFrom = 480;

const double _authButtonHeight = 52;
const double _authButtonFontSize = 14;

// Stops at the line's ends so both colours show even on short lines.
const LinearGradient _titleGradient = LinearGradient(
  colors: [AppTheme.trialOcean, AppTheme.trialViolet],
  stops: [0.15, 0.95],
);

const double _secondaryButtonHeight = 46;
const double _secondaryButtonFontSize = 13;
const double _secondaryButtonRadius = 23;

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
      // login() updates authState; the global router redirect takes over when
      // a password change is pending.
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

      // 401 and 423 share a message: revealing a lock would confirm the
      // username exists.
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
          // The white text is only a mask for the gradient; keep the font's own
          // line height or descenders get clipped.
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

  Widget _labelledField(String label, Widget field)
  {
    final Widget text = Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialOcean,
      ),
    );

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
      height: _secondaryButtonHeight,
      fontSize: _secondaryButtonFontSize,
      radius: _secondaryButtonRadius,
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

  @override
  Widget build(BuildContext context)
  {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isNarrow = width < _narrowBreakpoint;

    return AuthPageBackground(
      watermark: false,
      child: Center(
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
                const SizedBox(height: 26),
                AppDialogPill(
                  expand: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Accedendo, accetti le '),
                        TextSpan(
                          text: "Condizioni d'Uso",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.trialTealDeep,
                          ),
                        ),
                        const TextSpan(text: " e l'"),
                        TextSpan(
                          text: 'Informativa sulla Privacy',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.trialTealDeep,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: AppTheme.trialMutedText,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '© ${DateTime.now().year} Nicolò Calore\n'
                  'ATTENZIONE: applicazione attualmente in sviluppo. '
                  'Potrebbero verificarsi comportamenti inaspettati.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: AppTheme.trialMutedText,
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
            hintText: 'Es. mario.rossi',
            onSubmitted: (_) => _handleSend(),
            nothingAbove: true,
          ),
        ),
      ],
    );
  }
}

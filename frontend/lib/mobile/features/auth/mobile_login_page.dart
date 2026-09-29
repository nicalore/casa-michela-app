import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_state.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_brand.dart';
import '../../shared/widgets/mobile_entrance_motion.dart';
import '../../shared/widgets/mobile_glass_panel.dart';
import '../../shared/widgets/mobile_gold_button.dart';
import '../../shared/widgets/mobile_handover.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_text_field.dart';
import 'mobile_password_recovery_sheet.dart';

const double _phoneMargin = 20;
const double _phoneBrandTop = 30;
const double _phoneBrandGap = 30;
const double _phoneFooterBottom = 22;

const double _tabletCardWidth = 520;
const double _tabletBrandTop = 146;
const double _tabletBrandGap = 64;
const double _tabletFooterBottom = 44;

const double _landscapeCardWidth = 460;
const double _landscapeEdgeGap = 120;

class MobileLoginPage extends StatefulWidget
{
  const MobileLoginPage({super.key});

  @override
  State<MobileLoginPage> createState() => _MobileLoginPageState();
}

class _MobileLoginPageState extends State<MobileLoginPage>
{
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _busy = false;

  // Sign-in and sign-out: the card turns into the menu bar and back.
  MobileHandover? _handover;

  // Any other entrance change.
  MobileEntranceMotion? _entrance;

  late Listenable _motion;

  Animation<double> get _signIn => _handover?.progress ?? kAlwaysDismissedAnimation;

  double _shift(MobileEntrancePart part) => _entrance?.shift(part) ?? 0;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _handover = MobileHandover.maybeOf(context);
    _entrance = MobileEntranceMotion.maybeOf(context);
    _motion = Listenable.merge([_signIn, _entrance?.progress ?? kAlwaysCompleteAnimation]);
  }

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
          MobileNotice.show(context, notice, tone: SnackBarTone.warning);
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
    if (_busy)
    {
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty)
    {
      MobileNotice.show(context, 'Inserisci nome utente e password per accedere.', error: true);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);

    try
    {
      // On success login() updates authState and MobileApp swaps this page out.
      await _apiService.login(username: username, password: password);

      if (mounted && _apiService.authState.value == AuthState.unauthenticated)
      {
        MobileNotice.show(context, 'Errore imprevisto. Riprova più tardi.', error: true);
      }
    }
    on DioException catch (e)
    {
      if (!mounted)
      {
        return;
      }

      // 401 and 423 share a message: revealing a lock confirms the username exists.
      final message = isConnectionFailure(e)
          ? connectionFailureMessage
          : switch (e.response?.statusCode)
            {
              401 || 423 => "Nome utente o password non validi. Dopo 5 tentativi errati, l'account verrà bloccato per 20 minuti.",
              403 => "Account disabilitato. Se ritieni ci sia un errore, contatta l'Associazione.",
              _ => 'Errore imprevisto. Riprova più tardi.',
            };

      MobileNotice.show(context, message, error: true);
    }
    finally
    {
      if (mounted)
      {
        setState(() => _busy = false);
      }
    }
  }

  Widget _buildTerms()
  {
    final TextStyle link = GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w700,
      color: AppTheme.trialTealDeep,
    );

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Accedendo, accetti le '),
          TextSpan(text: "Condizioni d'Uso", style: link),
          const TextSpan(text: " e l'"),
          TextSpan(text: 'Informativa sulla Privacy', style: link),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppTheme.trialInk.withValues(alpha: 0.8),
      ),
    );
  }

  Widget _buildCard()
  {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, form) => Transform.translate(
        offset: Offset(0, _shift(MobileEntrancePart.card) * MediaQuery.sizeOf(context).height),
        child: Visibility(
          visible: MobileHandover.cardShown(_signIn.value),
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: MobileGlassPanel(
            key: _handover?.cardKey,
            child: FractionalTranslation(
              translation: Offset(
                0,
                MobileHandover.formOut(_signIn.value) + _shift(MobileEntrancePart.content),
              ),
              child: form,
            ),
          ),
        ),
      ),
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileTextField(
              controller: _usernameController,
              label: 'Nome utente',
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
            ),
            const SizedBox(height: 18),
            MobileTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: true,
              textInputAction: TextInputAction.go,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _login(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showMobilePasswordRecoverySheet(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Text(
                    'Password dimenticata?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.trialTealDeep,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            MobileGoldButton(
              label: 'Accedi',
              icon: Icons.arrow_forward_rounded,
              busy: _busy,
              onPressed: _login,
            ),
            const SizedBox(height: 18),
            _buildTerms(),
          ],
        ),
      ),
    );
  }

  Widget _buildBrand(MobileBrand brand)
  {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          (_shift(MobileEntrancePart.head) - MobileHandover.brandOut(_signIn.value)) *
              MediaQuery.sizeOf(context).height,
        ),
        child: child,
      ),
      child: brand,
    );
  }

  Widget _buildFooter()
  {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          (_shift(MobileEntrancePart.foot) + MobileHandover.footerOut(_signIn.value)) *
              MediaQuery.sizeOf(context).height,
        ),
        child: child,
      ),
      child: _buildFooterText(),
    );
  }

  Widget _buildFooterText()
  {
    return Text(
      '© ${DateTime.now().year} Nicolò Calore\n'
      'ATTENZIONE: applicazione attualmente in sviluppo. '
      'Potrebbero verificarsi comportamenti inaspettati.',
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildStacked(MobileFormFactor factor)
  {
    final bool tablet = factor.isTablet;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _phoneMargin,
        tablet ? _tabletBrandTop : _phoneBrandTop,
        _phoneMargin,
        tablet ? _tabletFooterBottom : _phoneFooterBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBrand(tablet ? const MobileBrand(logoSize: 140, titleSize: 30) : const MobileBrand()),
          SizedBox(height: tablet ? _tabletBrandGap : _phoneBrandGap),
          if (tablet)
            Center(child: SizedBox(width: _tabletCardWidth, child: _buildCard()))
          else
            _buildCard(),
          const Spacer(),
          SizedBox(height: tablet ? _tabletBrandGap : _phoneBrandGap),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildSideBySide()
  {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_phoneMargin, 0, _phoneMargin, _tabletFooterBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Center(child: _buildBrand(const MobileBrand(logoSize: 180, titleSize: 34))),
                ),
                SizedBox(
                  width: _landscapeCardWidth,
                  child: Center(child: _buildCard()),
                ),
                const SizedBox(width: _landscapeEdgeGap - _phoneMargin),
              ],
            ),
          ),
          const SizedBox(height: _tabletBrandGap),
          _buildFooter(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final MobileFormFactor factor = MobileBreakpoints.of(context);
    final bool landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final bool sideBySide = factor.isTablet && landscape;

    // The keyboard covers the page instead of resizing it; scrolling is for short screens.
    final Size size = MediaQuery.sizeOf(context);
    final EdgeInsets viewPadding = MediaQuery.viewPaddingOf(context);
    final double fullHeight = size.height - viewPadding.top - viewPadding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            // Unclipped while moving, so things leave by the screen's edges.
            clipBehavior: (_handover?.moving ?? false) || (_entrance?.moving ?? false)
                ? Clip.none
                : Clip.hardEdge,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: fullHeight),
              child: IntrinsicHeight(
                child: sideBySide ? _buildSideBySide() : _buildStacked(factor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

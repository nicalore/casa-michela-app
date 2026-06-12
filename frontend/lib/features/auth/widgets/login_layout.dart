import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../../services/api_service.dart';
import '../../../shared/widgets/snackbar.dart';
import 'login_button.dart';
import 'login_text_field.dart';

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
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();

  @override
  void dispose()
  {
    //Release resources
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
      //Perform login API call
      final result = await _apiService.login(
        username: username,
        password: password,
      );

      if (!mounted) return;

      if (result.passwordResetRequired)
      {
        context.replace(
          '/force-password-change',
          extra: {
            'currentPassword': _passwordController.text,
            'refreshToken': result.refreshToken,
          },
        );

        return;
      }

      context.replace('/dashboard');
    }
    on DioException catch (e)
    {
      if (!mounted) return;

      String message = 'Errore imprevisto';

      switch (e.response?.statusCode)
      {
        case 401:
          message = 'Nome utente o password non validi. Dopo 5 tentativi errati, l\'account verrà bloccato per 20 minuti.';
          break;

        case 403:
          message = 'Account disabilitato. Se ritieni ci sia un errore, contatta l\'Associazione';
          break;

        case 423:
          message = 'Nome utente o password non validi. Dopo 5 tentativi errati, l\'account verrà bloccato per 20 minuti.';
          break;
      }

      CustomSnackBar.show(
        context: context,
        message: message,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final viewportWidth = MediaQuery.of(context).size.width;
    final currentYear = DateTime.now().year;

    final isNarrow = viewportWidth < 600;
    
    final cardWidth = viewportWidth > 1300 ? 1160.0 : viewportWidth - 80;

    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFF4F7F9),
      child: Stack(
        children: [
          Positioned(
            right: -800,
            top: -800,
            child: IgnorePointer(
              child: Container(
                width: 1600,
                height: 1600,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
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
          Positioned(
            left: -800,
            bottom: -800,
            child: IgnorePointer(
              child: Container(
                width: 1600,
                height: 1600,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
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

          //MainContent
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints)
              {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 20 : 40,
                        vertical: 40,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            
                            //HeaderLogo
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

                            //LoginCard
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: cardWidth),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF000000).withValues(alpha: 0.04),
                                      offset: const Offset(0, 4),
                                      blurRadius: 16,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isNarrow ? 25 : 50,
                                  vertical: 40,
                                ),
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
                                    physicsSpacer(isNarrow ? 32 : 40),
                                    
                                    //ActionSection
                                    if (isNarrow) ...[
                                      SizedBox(
                                        width: double.infinity,
                                        child: LoginButton(onPressed: _login),
                                      ),
                                      const SizedBox(height: 20),
                                      _AnimatedTextLink(
                                        text: 'Password dimenticata?',
                                        onTap: ()
                                        {
                                          //TODO: Navigazione verso recupero password
                                        },
                                      ),
                                    ] 
                                    else ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _AnimatedTextLink(
                                            text: 'Password dimenticata?',
                                            onTap: ()
                                            {
                                              //TODO: Navigazione verso recupero password
                                            },
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

                            //DisclaimerSection
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: cardWidth),
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                    height: 1.5,
                                  ),
                                  children: [
                                    TextSpan(text: 'Accedendo, accetti i '),
                                    TextSpan(
                                      text: 'Termini di Servizio',
                                      style: TextStyle(
                                        color: Color(0xFF003C82),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: ' e l\''),
                                    TextSpan(
                                      text: 'Informativa sulla Privacy',
                                      style: TextStyle(
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

                            //Footer
                            Text(
                              '© $currentYear Nicolò Calore\nATTENZIONE: applicazione attualmente in sviluppo. Potrebbero verificarsi comportamenti inaspettati.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
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

//InternalWidgets

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

  @override
  Widget build(BuildContext context)
  {
    if (isNarrow)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: LoginTextField(
              controller: controller,
              obscureText: obscure,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: SizedBox(
            height: 56,
            child: LoginTextField(
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

  const _AnimatedTextLink({
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
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isHovered ? const Color(0xFF002244) : const Color(0xFF003C82),
              ),
              child: Text(widget.text),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuint,
              height: 2,
              width: _isHovered ? 175 : 0, 
              decoration: BoxDecoration(
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
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../shared/widgets/snackbar.dart';
import 'widgets/login_button.dart';
import 'widgets/login_text_field.dart';

class ForcePasswordChangePage extends StatefulWidget
{
  final String refreshToken;
  final String currentPassword;

  const ForcePasswordChangePage({
    super.key,
    required this.refreshToken,
    required this.currentPassword,
  });

  @override
  State<ForcePasswordChangePage> createState() => _ForcePasswordChangePageState();
}

class _ForcePasswordChangePageState extends State<ForcePasswordChangePage>
{
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _apiService = ApiService();
  
  bool _isLoading = false;

  @override
  void dispose()
  {
    //Release resources
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    
    super.dispose();
  }

  Future<void> _submit() async
  {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    //Validate new password length
    if (newPassword.length < 8)
    {
      CustomSnackBar.show(
        context: context,
        message: 'La nuova password deve contenere almeno 8 caratteri.',
        isError: true,
      );
      
      return;
    }

    //Validate passwords match
    if (newPassword != confirmPassword)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Le password non coincidono. Riprova.',
        isError: true,
      );
      
      return;
    }

    setState(() => _isLoading = true);

    try
    {
      //Perform password change
      await _apiService.changePassword(
        currentPassword: widget.currentPassword,
        newPassword: newPassword,
        refreshToken: widget.refreshToken,
      );
      
      ApiService.forcePasswordChangeCompleted = true;

      if (!mounted) return;
      
      CustomSnackBar.show(
        context: context,
        message: 'Password aggiornata con successo! Benvenuto.',
      );

      context.replace('/dashboard');
    }
    catch (e)
    {
      if (!mounted) return;
      
      CustomSnackBar.show(
        context: context,
        message: e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    }
    finally
    {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    //Prevent hardware/browser back button
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result)
      {
        if (!didPop)
        {
          CustomSnackBar.show(
            context: context,
            message: 'Devi cambiare la password per procedere.',
            isError: true,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F9),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
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
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_reset_rounded,
                      size: 64,
                      color: Color(0xFF003C82),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Aggiorna Password',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF003C82),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Al primo accesso o dopo un reset amministrativo è obbligatorio impostare una nuova password personale.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nuova password',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        LoginTextField(
                          controller: _newPasswordController,
                          obscureText: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Conferma password',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        LoginTextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading 
                        ? const Center(
                            child: CircularProgressIndicator(color: Color(0xFF003C82)),
                          )
                        : LoginButton(onPressed: _submit),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
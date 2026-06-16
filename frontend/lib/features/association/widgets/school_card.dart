import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/school_item.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/shared_components.dart';

class SchoolCard extends StatefulWidget {
  final SchoolItem school;
  final Function(String oldCode, String newCode, String name, String city, String prov, bool isPrivate, Function(String) onError) onEdit;
  final VoidCallback onDelete;

  const SchoolCard({
    super.key,
    required this.school,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<SchoolCard> createState() => _SchoolCardState();
}

class _SchoolCardState extends State<SchoolCard> {
  bool _isHovering = false;

  void _showDetailsDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SchoolDetails',
      barrierColor: Colors.black.withValues(alpha: .15),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final blurValue = animation.value * 8.0;
        
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
                reverseCurve: Curves.easeIn,
              ),
              child: _SchoolDetailsDialogContent(
                school: widget.school,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: () => _showDetailsDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 320,
          height: 114, // Fissato l'overflow
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), // Fissato l'overflow
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isHovering ? const Color(0xFF003C82) : Colors.transparent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AutoResizeText(
                text: widget.school.name,
                maxFontSize: 24,
                minFontSize: 16,
                maxLines: 2,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF003C82),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.school.city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8A8A8A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoResizeText extends StatelessWidget {
  final String text;
  final double maxFontSize;
  final double minFontSize;
  final int maxLines;
  final TextStyle style;

  const _AutoResizeText({
    required this.text,
    required this.maxFontSize,
    required this.minFontSize,
    required this.maxLines,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double currentFontSize = maxFontSize;
        final textPainter = TextPainter(textDirection: TextDirection.ltr, maxLines: maxLines);

        while (currentFontSize > minFontSize) {
          textPainter.text = TextSpan(text: text, style: style.copyWith(fontSize: currentFontSize));
          textPainter.layout(maxWidth: constraints.maxWidth);
          if (!textPainter.didExceedMaxLines) break; 
          currentFontSize -= 1;
        }

        return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style.copyWith(fontSize: currentFontSize));
      }
    );
  }
}

class _SchoolDetailsDialogContent extends StatefulWidget {
  final SchoolItem school;
  final Function(String, String, String, String, String, bool, Function(String)) onEdit;
  final VoidCallback onDelete;

  const _SchoolDetailsDialogContent({
    required this.school,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SchoolDetailsDialogContent> createState() => _SchoolDetailsDialogContentState();
}

class _SchoolDetailsDialogContentState extends State<_SchoolDetailsDialogContent> {
  bool _isEditingMode = false;
  
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _provController;
  late bool _isPrivate;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _codeController = TextEditingController(text: widget.school.isPrivate ? '' : widget.school.mechanographicCode);
    _nameController = TextEditingController(text: widget.school.name);
    _cityController = TextEditingController(text: widget.school.city);
    _provController = TextEditingController(text: widget.school.province);
    _isPrivate = widget.school.isPrivate;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _provController.dispose();
    super.dispose();
  }

  void _cancelEdit() {
    setState(() {
      _isEditingMode = false;
      _initControllers();
    });
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext confirmContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Conferma Eliminazione', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
          content: Text('Sei sicuro di voler eliminare la scuola "${widget.school.name}"?', style: GoogleFonts.plusJakartaSans(fontSize: 16)),
          actions: [
            TextButton(
              style: ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: () => Navigator.pop(confirmContext),
              child: Text('ANNULLA', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8A8A8A), fontWeight: FontWeight.w600)),
            ),
            TextButton(
              style: ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: () {
                Navigator.pop(confirmContext);
                Navigator.pop(context);
                widget.onDelete();
              },
              child: Text('ELIMINA', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE53935), fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 16),
      child: Text(text, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24)],
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
                    _isEditingMode ? 'Modifica Scuola' : 'Dettagli Scuola',
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82)),
                  ),
                  StaticHoverIconButton(
                    icon: Icons.close,
                    color: const Color(0xFF003C82),
                    hoverColor: const Color(0xFFE3F2FD),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
              child: _isEditingMode 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPrivate = !_isPrivate;
                              if (_isPrivate) _codeController.clear();
                            });
                          },
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _isPrivate ? const Color(0xFF003C82) : Colors.transparent,
                                  border: Border.all(color: const Color(0xFF003C82), width: 2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: _isPrivate ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Scuola privata', 
                                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF003C82))
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildFieldLabel('Codice Meccanografico'),
                      TextField(
                        controller: _codeController,
                        enabled: !_isPrivate,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, 
                          color: _isPrivate ? const Color(0xFFB3B3B3) : Colors.black, 
                          fontWeight: FontWeight.w600
                        ),
                        decoration: InputDecoration(
                          hintText: _isPrivate ? 'Non presente' : 'Es. VIPC010004', 
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), 
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))
                        ),
                      ),
                      _buildFieldLabel('Nome'),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(hintText: 'Es. Liceo F. Corradini', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))),
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Città'),
                                TextField(
                                  controller: _cityController,
                                  textCapitalization: TextCapitalization.words,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(hintText: 'Es. Thiene', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Provincia'),
                                TextField(
                                  controller: _provController,
                                  textCapitalization: TextCapitalization.characters,
                                  maxLength: 2,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(counterText: "", hintText: 'Es. VI', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Codice Meccanografico'),
                      Text(
                        widget.school.isPrivate ? 'Scuola Privata (${widget.school.mechanographicCode})' : widget.school.mechanographicCode, 
                        style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black)
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel('Nome'),
                      Text(widget.school.name, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black)),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Città'),
                                Text(widget.school.city, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Provincia'),
                                Text(widget.school.province, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black)),
                              ],
                            ),
                          ),
                        ],
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
                      text: _isEditingMode ? 'SALVA' : 'MODIFICA',
                      icon: _isEditingMode ? Icons.save_outlined : Icons.edit_outlined,
                      baseColor: const Color(0xFF003C82),
                      hoverColor: const Color(0xFF004D99),
                      onPressed: () {
                        if (_isEditingMode) {
                          final code = _codeController.text.trim().toUpperCase();
                          final name = _nameController.text.trim();
                          final city = _cityController.text.trim();
                          final prov = _provController.text.trim().toUpperCase();

                          if (!_isPrivate && code.isEmpty) { CustomSnackBar.show(context: context, message: 'Inserisci il codice meccanografico.', isError: true); return; }
                          if (name.isEmpty || city.isEmpty) { CustomSnackBar.show(context: context, message: 'Compila tutti i campi.', isError: true); return; }
                          if (prov.length != 2) { CustomSnackBar.show(context: context, message: 'La provincia deve essere di 2 lettere.', isError: true); return; }

                          widget.onEdit(widget.school.mechanographicCode, code, name, city, prov, _isPrivate, (errorMsg) {
                            CustomSnackBar.show(context: context, message: errorMsg, isError: true);
                          });
                          
                          Navigator.of(context).pop();
                        } else {
                          setState(() => _isEditingMode = true);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text: _isEditingMode ? 'ANNULLA' : 'ELIMINA',
                      icon: _isEditingMode ? Icons.cancel_outlined : Icons.delete_outline_rounded,
                      baseColor: const Color(0xFFE53935),
                      hoverColor: const Color(0xFFEF5350),
                      onPressed: () {
                        if (_isEditingMode) {
                          _cancelEdit();
                        } else {
                          _showDeleteConfirmation(context);
                        }
                      },
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
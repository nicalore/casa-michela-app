import 'package:flutter/widgets.dart';

// Permette a una pagina di destinazione di segnalare al loader di
// transizione (vedi app_router.dart) che ha finito di caricare i propri
// dati ed è pronta per essere rivelata. L'adesione è opzionale: una
// pagina che non chiama mai markReady() viene comunque rivelata dopo un
// timeout di sicurezza gestito dal loader stesso, quindi nessuna
// navigazione resta bloccata a tempo indeterminato per il solo fatto di
// non usare questo sistema.
//
// Uso tipico in una pagina con caricamento dati asincrono:
//
//   Future<void> _fetchData() async {
//     try {
//       final result = await ApiService().getSomething();
//       if (mounted) setState(() => _data = result);
//       // Aspetta che il frame con i dati appena arrivati sia stato
//       // costruito e disegnato PRIMA di segnalare "pronto": così la
//       // dissolvenza di rivelazione parte quando il lavoro pesante è
//       // già finito, non mentre è ancora in corso.
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (mounted) PageReadySignal.markReady(context);
//       });
//     } catch (e) {
//       if (mounted) setState(() => _errorMessage = e.toString());
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (mounted) PageReadySignal.markReady(context);
//       });
//     }
//   }
class PageReadySignal extends InheritedWidget
{
  final VoidCallback _onReady;

  const PageReadySignal
  ({
    super.key,
    required VoidCallback onReady,
    required super.child,
  }) : _onReady = onReady;

  // Deliberatamente NON usa dependOnInheritedWidgetOfExactType: questo
  // metodo viene tipicamente chiamato da un callback asincrono (dopo un
  // await, o in un addPostFrameCallback), non durante il build, quindi
  // non deve registrare il chiamante come dipendente. getInheritedWidgetOfExactType
  // fa esattamente questo: cerca l'antenato senza creare una dipendenza.
  static void markReady(BuildContext context)
  {
    context.getInheritedWidgetOfExactType<PageReadySignal>()?._onReady();
  }

  @override
  bool updateShouldNotify(PageReadySignal oldWidget) => false;
}
import 'package:flutter/material.dart';

import '../../shared/widgets/snackbar.dart';
import '../utils/error_message.dart';

/// The two shapes every write on a catalogue page takes.
///
/// A page holds its rows in a field and edits them in place rather than
/// refetching the list after each write: the server answers with the row it
/// wrote, and folding that one row in is both faster and free of the flicker a
/// reload gives. What that costs is the same twenty lines around every call —
/// the try, the mounted check, the setState, the sentence — which is what lives
/// here instead.
///
/// The mounted check answers success and not failure: the write did go through,
/// and the page having been walked away from in the meantime is not a failure of
/// it. It is only the local copy that can no longer be updated, and there is no
/// local copy left to be wrong.
mixin EntityWrites<W extends StatefulWidget> on State<W>
{
  /// A create or an edit. [apply] folds the row the server answered with into
  /// whatever list holds it, and the answer says whether the form may close.
  ///
  /// [done] is the sentence to show, or null where the caller says it itself: a
  /// window writing six stretches of a day announces once what it did, not six
  /// times. [cascade] refetches a level that holds a denormalized copy of what
  /// has just changed.
  Future<bool> write<T>({
    required Future<T> Function() call,
    required void Function(T row) apply,
    required Function(String) onError,
    String? done,
    Future<void> Function()? cascade,
  }) async
  {
    try
    {
      final row = await call();

      if (!mounted)
      {
        return true;
      }

      setState(() => apply(row));

      if (done != null)
      {
        CustomSnackBar.show(context: context, message: done, isError: false);
      }

      await cascade?.call();

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));

      return false;
    }
  }

  /// A delete. Where no [onError] is given there is no form left open to be told
  /// about a refusal, so it is said here instead of handed back.
  Future<bool> erase({
    required Future<void> Function() call,
    required VoidCallback apply,
    String? done,
    Function(String)? onError,
    Future<void> Function()? cascade,
  }) async
  {
    try
    {
      await call();

      if (!mounted)
      {
        return true;
      }

      setState(apply);

      if (done != null)
      {
        CustomSnackBar.show(context: context, message: done, isError: false);
      }

      await cascade?.call();

      return true;
    }
    catch (e)
    {
      final message = readableApiError(e);

      if (onError != null)
      {
        onError(message);
      }
      else if (mounted)
      {
        CustomSnackBar.show(context: context, message: message, isError: true);
      }

      return false;
    }
  }
}

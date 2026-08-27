import 'package:flutter/material.dart';

import '../../shared/widgets/snackbar.dart';
import '../utils/error_message.dart';

// The mounted check answers success anyway: the write went through, only the
// local copy is gone.
mixin EntityWrites<W extends StatefulWidget> on State<W>
{
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

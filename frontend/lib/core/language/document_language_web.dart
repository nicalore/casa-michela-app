import 'package:web/web.dart' as web;

void setDocumentLanguageImpl(String key)
{
  web.document.documentElement?.setAttribute('lang', key);
}

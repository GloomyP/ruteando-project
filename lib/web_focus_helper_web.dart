import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

void liberarFocoPlataforma() {
  FocusManager.instance.primaryFocus?.unfocus();
  web.document.activeElement?.callMethod('blur'.toJS);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FocusManager.instance.primaryFocus?.unfocus();
    web.document.activeElement?.callMethod('blur'.toJS);
  });
}

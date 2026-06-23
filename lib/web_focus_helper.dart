import 'package:flutter/widgets.dart';

void liberarFocoPlataforma() {
  FocusManager.instance.primaryFocus?.unfocus();
}

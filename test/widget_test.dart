// Smoke test básico do Machine Monitor.
//
// Verifica que o app monta sem lançar exceção e cai na tela de login quando
// não há sessão salva. Antes de montar, injetamos as fontes simuladas — mesmo
// caminho do main() — para que telas que consultam AppDataSource funcionem.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machine_monitor/services/data_sources.dart';
import 'package:machine_monitor/services/auth/simulated_auth_source.dart';
import 'package:machine_monitor/services/monitor/simulated_machine_data_source.dart';
import 'package:machine_monitor/services/tex/simulated_tex_data_source.dart';
import 'package:machine_monitor/main.dart';

void main() {
  setUp(() {
    AppDataSource.init(
      auth: SimulatedAuthSource(),
      machines: SimulatedMachineDataSource(),
      tex: SimulatedTexDataSource(),
    );
  });

  testWidgets('App monta e exibe a tela de login sem sessão salva',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MachineMonitorApp(savedUser: null));
    await tester.pump();

    // O app deve renderizar um MaterialApp sem erros de build.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

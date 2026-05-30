import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'app/app_config.dart';
import 'core/theme/app_theme.dart';
import 'models/models.dart';
import 'services/data_sources.dart';
import 'services/auth/simulated_auth_source.dart';
import 'services/monitor/modbus_machine_data_source.dart';
import 'services/monitor/simulated_machine_data_source.dart';
import 'services/tex/modbus_tex_data_source.dart';
import 'services/tex/simulated_tex_data_source.dart';
import 'services/storage/storage_service.dart';
import 'screens/login_screen.dart';
import 'screens/machine_list_screen.dart';

/// Configuração resolvida em tempo de inicialização. Trocar [useRealModbus]
/// aqui (ou no [AppConfig]) é o único ponto necessário para alternar entre
/// CLP real e simulação — nenhuma tela precisa mudar.
const AppConfig _config = AppConfig(useRealModbus: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _setupLogging();
  _wireDataSources();

  // Liberamos todas as orientações: o monitor funciona melhor em retrato e o
  // console TEX em paisagem, então deixamos o dispositivo decidir.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final savedUser = await StorageService.loadSession();
  runApp(MachineMonitorApp(savedUser: savedUser));
}

/// Encaminha os logs dos serviços (Modbus, IHM) para o console em debug.
void _setupLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    debugPrint('[${record.level.name}] ${record.loggerName}: ${record.message}');
  });
}

/// Injeta as implementações ativas conforme [_config]. As telas só conhecem as
/// abstrações em [AppDataSource].
void _wireDataSources() {
  AppDataSource.init(
    auth: SimulatedAuthSource(),
    machines: _config.useRealModbus
        ? ModbusMachineDataSource(
            port: _config.modbusPort, unitId: _config.unitId)
        : SimulatedMachineDataSource(),
    tex: _config.useRealModbus
        ? ModbusTexDataSource(
            port: _config.modbusPort,
            unitId: _config.unitId,
            refresh: _config.texRefreshInterval,
          )
        : SimulatedTexDataSource(tick: _config.texRefreshInterval),
  );
}

class MachineMonitorApp extends StatelessWidget {
  const MachineMonitorApp({super.key, this.savedUser});

  final AppUser? savedUser;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Machine Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: savedUser != null
          ? MachineListScreen(user: savedUser!)
          : const LoginScreen(),
    );
  }
}

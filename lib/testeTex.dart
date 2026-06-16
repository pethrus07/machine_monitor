// import 'package:learn_dart/services/ftp_inovance.dart';


// void main() {
//   FtpInovance inovance = FtpInovance();
//   inovance.newPoint();
// }

//import 'package:learn_dart/models/app_inovance_ihm.dart';
import 'package:learn_dart/models/texG4_modbus.dart';

void main() async {

  //IHM.connect(host: '192.168.0.10', port: 502);

  await TEX.connect(host: '192.168.0.205', port: 502);

  await TEX.setBCD(1);

  await TEX.start(false);

  //await TEX.stop(false);

}
import 'dart:typed_data';

/// Estrutura de dados crua da bancada TEX G4, decodificada dos holding
/// registers do CLP.
///
/// O layout (offset → grandeza) e a conversão em [registersToTexData] foram
/// **verificados contra o equipamento físico** (TEX "Anel Hídrico"). Mantemos a
/// decodificação exatamente como foi validada em campo; a tradução para o
/// modelo de UI ([TexSnapshot]) é feita à parte, na fonte de dados.
class TexData {
  int control = 0;
  int digitalOutputs = 0;
  int bcd = 0;
  int outputPlus = 0;

  int timeElapsed = 0;

  double pressure = 0;
  double leak = 0;

  int pressureUnit = 0;
  int leakUnit = 0;

  int valveDiagnostic = 0;
  int ioDiagnostic = 0;

  int controlMirror = 0;

  int testStatus = 0;

  int currentChamber = 0;

  int currentParameterList = 0;

  String lot = '';

  double differentialPressure = 0;

  double returnPressure = 0;

  int returnPressureUnit = 0;
}

/// Quantidade mínima de holding registers que a leitura contínua deve trazer
/// para que [registersToTexData] consiga montar um [TexData] completo.
const int kTexRegisterCount = 35;

/// Converte o bloco de holding registers (lidos a partir do endereço 0) em
/// [TexData]. Espera registradores **brutos** (sem byte-swap), pois reconstrói
/// os floats em little-endian aqui dentro.
TexData registersToTexData(List<int> regs) {
  if (regs.length < kTexRegisterCount) {
    throw Exception('Esperado no mínimo $kTexRegisterCount registradores');
  }

  final d = TexData();

  // 0-3
  d.control = regs[0];
  d.digitalOutputs = regs[1];
  d.bcd = regs[2];
  d.outputPlus = regs[3];

  // 4-5: Tempo de Teste (INT32)
  d.timeElapsed = (regs[5] << 16) | regs[4];

  // 9-10: Pressão de Teste (FLOAT32 little-endian)
  d.pressure = _float32(regs[9], regs[10]);

  // 11-12: Vazamento / Vazão (FLOAT32)
  d.leak = _float32(regs[11], regs[12]);

  // 13-20
  d.pressureUnit = regs[13];
  d.leakUnit = regs[14];
  d.valveDiagnostic = regs[15];
  d.ioDiagnostic = regs[16];
  d.controlMirror = regs[17];
  d.testStatus = regs[18];
  d.currentChamber = regs[19];
  d.currentParameterList = regs[20];

  // 23-28: Lote (6 caracteres)
  d.lot = String.fromCharCodes([
    regs[23] & 0xFF,
    regs[24] & 0xFF,
    regs[25] & 0xFF,
    regs[26] & 0xFF,
    regs[27] & 0xFF,
    regs[28] & 0xFF,
  ]);

  // 29-30: Pressão Diferencial (FLOAT32)
  d.differentialPressure = _float32(regs[29], regs[30]);

  // 31-32: Pressão de Retorno (FLOAT32)
  d.returnPressure = _float32(regs[31], regs[32]);

  // 33: Unidade da pressão de retorno
  d.returnPressureUnit = regs[33];

  return d;
}

/// Reconstrói um float de 32 bits a partir de dois registradores de 16 bits,
/// na ordem little-endian (low word primeiro) usada pelo CLP da TEX.
double _float32(int lowWord, int highWord) {
  final bytes = ByteData(4);
  bytes.setUint16(0, lowWord, Endian.little);
  bytes.setUint16(2, highWord, Endian.little);
  return bytes.getFloat32(0, Endian.little);
}

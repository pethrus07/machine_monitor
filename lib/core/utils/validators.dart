/// Validação de endereços IPv4.
///
/// Antes essa regex vivia inline no formulário de cadastro. Centralizada aqui,
/// fica testável e reutilizável por qualquer tela que aceite IP.
class IpValidator {
  IpValidator._();

  static final RegExp _ipv4 = RegExp(
    r'^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$',
  );

  static bool isValid(String value) => _ipv4.hasMatch(value.trim());

  /// Validador pronto para `TextFormField.validator`.
  static String? validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe o IP';
    if (!isValid(text)) return 'IP inválido';
    return null;
  }
}

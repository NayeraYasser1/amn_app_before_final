/// Egypt emergency service numbers, defined once so a change (or a locale
/// variant) is made in a single place instead of being duplicated as magic
/// strings across screens.
///
/// Police 122 · Ambulance 123 · Fire 180 · Traffic Police 128.
class EmergencyNumbers {
  const EmergencyNumbers._();

  static const String police = '122';
  static const String ambulance = '123';
  static const String fire = '180';
  static const String traffic = '128';
}

import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Verifica permissões e retorna a posição GPS atual.
  Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Ative o serviço de localização do dispositivo.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Permita o acesso à localização para centralizar o mapa.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'A localização está bloqueada. Habilite a permissão nas configurações.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  /// Fornece atualizações de posição enquanto o dispositivo se desloca.
  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }
}

class LocationException implements Exception {
  /// Cria um erro de localização com uma mensagem para a tela.
  const LocationException(this.message);

  final String message;

  /// Retorna a mensagem legível do erro.
  @override
  String toString() => message;
}

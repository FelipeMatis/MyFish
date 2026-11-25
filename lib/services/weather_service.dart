import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/weather_model.dart';

class WeatherService {
  /// Cria o serviço usando o cliente HTTP fornecido ou um padrão.
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Busca as condições atuais do tempo para as coordenadas informadas.
  Future<WeatherModel> currentAt(double latitude, double longitude) async {
    final apiKey = dotenv.env['OPENWEATHERMAP_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw const WeatherException(
        'Configure OPENWEATHERMAP_API_KEY no arquivo .env.',
      );
    }

    final uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
      'lat': '$latitude',
      'lon': '$longitude',
      'appid': apiKey,
      'units': 'metric',
      'lang': 'pt_br',
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw WeatherException(
        response.statusCode == 401
            ? 'A chave do OpenWeatherMap é inválida ou ainda não foi ativada.'
            : 'Não foi possível consultar o clima (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const WeatherException('Resposta inválida do serviço de clima.');
    }

    final main = decoded['main'];
    final wind = decoded['wind'];
    final conditions = decoded['weather'];
    if (main is! Map ||
        wind is! Map ||
        conditions is! List ||
        conditions.isEmpty ||
        conditions.first is! Map) {
      throw const WeatherException('Resposta incompleta do serviço de clima.');
    }

    final condition = conditions.first as Map;
    final observedAt = decoded['dt'];
    return WeatherModel(
      temperatureC: _number(main['temp'], 'temperatura'),
      pressureHpa: _number(main['pressure'], 'pressão'),
      windSpeedMps: _number(wind['speed'], 'velocidade do vento'),
      windDirectionDegrees: _number(wind['deg'] ?? 0, 'direção do vento'),
      description: condition['description'] as String? ?? 'Sem descrição',
      observedAt: observedAt is num
          ? DateTime.fromMillisecondsSinceEpoch(
              observedAt.toInt() * 1000,
              isUtc: true,
            )
          : DateTime.now().toUtc(),
      conditionCode: condition['icon'] as String?,
    );
  }

  /// Valida e converte um valor numérico da resposta da API.
  double _number(Object? value, String field) {
    if (value is num) return value.toDouble();
    throw WeatherException('Campo $field inválido na resposta do clima.');
  }
}

class WeatherException implements Exception {
  /// Cria um erro de consulta ao serviço meteorológico.
  const WeatherException(this.message);

  final String message;

  /// Retorna a mensagem legível do erro.
  @override
  String toString() => message;
}

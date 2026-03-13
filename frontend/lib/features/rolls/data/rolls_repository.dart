import 'package:frontend/models/film_stock.dart';
import 'package:frontend/models/roll.dart';
import 'package:frontend/models/camera.dart';
import 'package:frontend/services/api_service.dart';

class RollsRepository {
  final ApiService _apiService;

  RollsRepository(this._apiService);

  Future<List<Roll>> getRolls() async {
    final response = await _apiService.get('/rolls');
    final List data = response.data;
    return data.map((json) => Roll.fromJson(json)).toList();
  }

  Future<List<FilmStock>> getFilmStocks() async {
    final response = await _apiService.get('/film_stocks');
    final List data = response.data;
    return data.map((json) => FilmStock.fromJson(json)).toList();
  }

  Future<List<Camera>> getCameras() async {
    final response = await _apiService.get('/cameras');
    final List data = response.data;
    return data.map((json) => Camera.fromJson(json)).toList();
  }

  Future<Roll> createRoll({
    required String filmStockId,
    required String userCameraId,
    int? shotAtIso,
    int? expiredYear,
  }) async {
    final response = await _apiService.post('/rolls', data: {
      'film_stock_id': filmStockId,
      'user_camera_id': userCameraId,
      'shot_at_iso': shotAtIso,
      'expired_year': expiredYear,
    });
    return Roll.fromJson(response.data);
  }
}

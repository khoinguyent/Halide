import 'package:frontend/models/film_stock.dart';
import 'package:frontend/models/roll.dart';
import 'package:frontend/models/camera.dart';
import 'package:frontend/services/api_service.dart';

class RollsRepository {
  final ApiService _apiService;

  RollsRepository(this._apiService);

  Future<List<Roll>> getRolls() async {
    final response = await _apiService.get('/api/v1/rolls');
    final List data = response.data;
    return data.map((json) => Roll.fromJson(json)).toList();
  }

  Future<List<FilmStock>> getFilmStocks() async {
    final response = await _apiService.get('/api/v1/master/films');
    final List data = response.data;
    return data.map((json) => FilmStock.fromJson(json)).toList();
  }

  Future<List<Camera>> getCameras() async {
    final response = await _apiService.get('/api/v1/user_cameras');
    final List data = response.data;
    return data.map((json) => Camera.fromJson(json)).toList();
  }

  Future<Roll> createRoll({
    required String filmStockId,
    String? userCameraId,
    String? title,
    String? description,
    int? shotAtIso,
    int? expiredYear,
    int? maxFrames,
  }) async {
    final response = await _apiService.post('/api/v1/rolls', data: {
      'film_stock_id': filmStockId,
      'user_camera_id': userCameraId,
      'title': title,
      'description': description,
      'shot_at_iso': shotAtIso,
      'expired_year': expiredYear,
      'max_frames': maxFrames ?? 36,
    });
    return Roll.fromJson(response.data);
  }

  Future<Roll> updateRollStatus(String rollId, String status) async {
    final response = await _apiService.patch('/api/v1/rolls/$rollId/status', data: {
      'status': status,
    });
    return Roll.fromJson(response.data);
  }

  Future<void> updateRollDriveUrl(String rollId, String driveUrl) async {
    await _apiService.patch('/api/v1/rolls/$rollId/drive-url', data: {
      'drive_url': driveUrl,
    });
  }
}

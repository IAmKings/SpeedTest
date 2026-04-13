import 'package:flutter/foundation.dart';
import '../../data/models/speed_result.dart';
import '../../data/repositories/history_repository.dart';

/// History view model for managing speed test history
class HistoryViewModel extends ChangeNotifier {
  HistoryRepository? _historyRepository;

  List<SpeedResult> _history = [];
  Map<String, double> _averages = {'download': 0.0, 'upload': 0.0, 'ping': 0.0};
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<SpeedResult> get history => _history;
  Map<String, double> get averages => _averages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  HistoryViewModel({HistoryRepository? historyRepository}) {
    _historyRepository = historyRepository;
  }

  void setHistoryRepository(HistoryRepository repository) {
    _historyRepository = repository;
  }

  /// Load all history from database
  Future<void> loadHistory() async {
    if (_historyRepository == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _history = await _historyRepository!.getAllResults();
      _averages = await _historyRepository!.getAverages();
    } catch (e) {
      _errorMessage = 'Failed to load history: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a specific result
  Future<void> deleteResult(int id) async {
    if (_historyRepository == null) return;

    try {
      await _historyRepository!.deleteResult(id);
      _history.removeWhere((r) => r.id == id);
      _averages = await _historyRepository!.getAverages();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete result: $e';
      notifyListeners();
    }
  }

  /// Clear all history
  Future<void> clearAllHistory() async {
    if (_historyRepository == null) return;

    try {
      await _historyRepository!.clearAll();
      _history = [];
      _averages = {'download': 0.0, 'upload': 0.0, 'ping': 0.0};
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to clear history: $e';
      notifyListeners();
    }
  }

  /// Refresh history data
  Future<void> refresh() async {
    await loadHistory();
  }
}

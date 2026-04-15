import 'package:flutter/foundation.dart';

const List<String> regionNames = [
  'Worldwide',
  'Caribbean',
  'Indo-Pacific',
  'South Florida',
  'Hawaii',
  'Eastern Pacific',
  'French Polynesia',
];

class AppState extends ChangeNotifier {
  int selectedRegion = 0; // 0 = Worldwide
  String selectedSuperCat = 'Fish';
  String? selectedCategory;
  String? currentSpeciesId;

  List<String> _currentSpeciesList = [];
  int _currentSpeciesIndex = 0;

  // -------------------------------------------------------------------------
  // Getters
  // -------------------------------------------------------------------------

  bool get hasPrevious => _currentSpeciesIndex > 0;

  bool get hasNext =>
      _currentSpeciesList.isNotEmpty &&
      _currentSpeciesIndex < _currentSpeciesList.length - 1;

  // -------------------------------------------------------------------------
  // Setters / actions
  // -------------------------------------------------------------------------

  void setRegion(int r) {
    if (selectedRegion == r) return;
    selectedRegion = r;
    // Changing region resets category selection
    selectedCategory = null;
    notifyListeners();
  }

  void setSuperCat(String s) {
    if (selectedSuperCat == s) return;
    selectedSuperCat = s;
    // Changing superCat resets category selection
    selectedCategory = null;
    notifyListeners();
  }

  void setCategory(String c) {
    selectedCategory = c;
    notifyListeners();
  }

  void openSpecies(String id, List<String> orderedList) {
    currentSpeciesId = id;
    _currentSpeciesList = List.unmodifiable(orderedList);
    _currentSpeciesIndex = orderedList.indexOf(id);
    if (_currentSpeciesIndex < 0) _currentSpeciesIndex = 0;
    notifyListeners();
  }

  void goToPreviousSpecies() {
    if (!hasPrevious) return;
    _currentSpeciesIndex--;
    currentSpeciesId = _currentSpeciesList[_currentSpeciesIndex];
    notifyListeners();
  }

  void goToNextSpecies() {
    if (!hasNext) return;
    _currentSpeciesIndex++;
    currentSpeciesId = _currentSpeciesList[_currentSpeciesIndex];
    notifyListeners();
  }

  void closeSpecies() {
    currentSpeciesId = null;
    _currentSpeciesList = [];
    _currentSpeciesIndex = 0;
    notifyListeners();
  }
}

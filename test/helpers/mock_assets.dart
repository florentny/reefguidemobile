import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

const _speciesJson = '''[
  {
    "id": "sp1", "name": "Blue Tang", "sciName": "Acanthurus coeruleus",
    "subGenus": "", "category": "Surgeonfish", "size": "25cm", "depth": "1-40m",
    "note": "", "synonyms": "", "aka": "", "endemic": false, "distribution": [],
    "photos": [{"id": 1, "location": "Caribbean", "type": "Adult", "comment": ""}],
    "thumbs": [1], "dispNames": []
  },
  {
    "id": "sp2", "name": "Queen Angelfish", "sciName": "Holacanthus ciliaris",
    "subGenus": "", "category": "Angelfish", "size": "45cm", "depth": "2-70m",
    "note": "", "synonyms": "", "aka": "", "endemic": false, "distribution": [],
    "photos": [], "thumbs": [], "dispNames": []
  }
]''';

const _taxonomyJson = '''{
  "name": "Biota", "rank": "", "category": "",
  "children": [
    {
      "name": "Perciformes", "rank": "Order", "category": "",
      "children": [
        {
          "name": "Acanthuridae", "rank": "Family", "category": "",
          "children": [], "species": [
            {"id": "sp1", "name": "Blue Tang", "sname": "Acanthurus coeruleus", "superCat": "Fish", "thumb": 1}
          ]
        },
        {
          "name": "Pomacanthidae", "rank": "Family", "category": "",
          "children": [], "species": [
            {"id": "sp2", "name": "Queen Angelfish", "sname": "Holacanthus ciliaris", "superCat": "Fish", "thumb": 1}
          ]
        }
      ],
      "species": []
    }
  ],
  "species": []
}''';

/// Registers mock handlers on the flutter/assets binary-messenger channel so
/// that DataService can load JSON without real device assets.  Call once per
/// test file in [setUpAll].
void setupMockAssets() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    if (message == null) return null;
    final key = utf8.decode(message.buffer.asUint8List());
    if (key == 'asset/json/species_all.json') {
      return ByteData.view(utf8.encode(_speciesJson).buffer);
    }
    if (key.startsWith('asset/json/taxonomy_region_')) {
      return ByteData.view(utf8.encode(_taxonomyJson).buffer);
    }
    // All other assets (images etc.) return null → errorBuilder handles it.
    return null;
  });
}

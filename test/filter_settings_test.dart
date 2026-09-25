import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/models/filter_settings.dart';

void main() {
  group('FilterSettings Tests', () {
    test('Default values are empty lists and zero rating', () {
      final settings = FilterSettings();
      expect(settings.genres, isEmpty);
      expect(settings.years, isEmpty);
      expect(settings.actors, isEmpty);
      expect(settings.directors, isEmpty);
      expect(settings.excludedGenres, isEmpty);
      expect(settings.excludedYears, isEmpty);
      expect(settings.excludedActors, isEmpty);
      expect(settings.excludedDirectors, isEmpty);
      expect(settings.ratingMin, 0.0);
      expect(settings.limit, 10);
    });

    test('toJson and fromJson round-trip', () {
      final settings = FilterSettings(
        genres: ['Action', 'Comedy'],
        years: ['2023', '2024'],
        ratingMin: 7.5,
        actors: ['Tom Cruise'],
        directors: ['Nolan'],
        excludedGenres: ['Horror'],
        excludedYears: ['2000'],
        excludedActors: ['Bad Actor'],
        excludedDirectors: ['Bad Director'],
        limit: 20,
      );

      final json = settings.toJson();
      final restored = FilterSettings.fromJson(json);

      expect(restored.genres, settings.genres);
      expect(restored.years, settings.years);
      expect(restored.ratingMin, settings.ratingMin);
      expect(restored.actors, settings.actors);
      expect(restored.directors, settings.directors);
      expect(restored.excludedGenres, settings.excludedGenres);
      expect(restored.excludedYears, settings.excludedYears);
      expect(restored.excludedActors, settings.excludedActors);
      expect(restored.excludedDirectors, settings.excludedDirectors);
      expect(restored.limit, settings.limit);
    });

    test('fromJson handles null values with defaults', () {
      final json = <String, dynamic>{};
      final settings = FilterSettings.fromJson(json);
      expect(settings.genres, isEmpty);
      expect(settings.ratingMin, 0.0);
      expect(settings.limit, 10);
    });

    test('fromJson coerces ratingMin to double', () {
      final json = {'ratingMin': 8};
      final settings = FilterSettings.fromJson(json);
      expect(settings.ratingMin, 8.0);
      expect(settings.ratingMin, isA<double>());
    });
  });
}
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'auth_storage.dart';

class AppLocation {
  final double latitude;
  final double longitude;
  final String? city;
  final String? area;
  final String label;

  const AppLocation({
    required this.latitude,
    required this.longitude,
    this.city,
    this.area,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'area': area,
        'label': label,
      };

  factory AppLocation.fromJson(Map<String, dynamic> j) => AppLocation(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        city: j['city']?.toString(),
        area: j['area']?.toString(),
        label: j['label']?.toString() ?? 'Selected location',
      );

  bool get labelLooksLikeCoordinates {
    final l = label.trim();
    // e.g. "6.5244, 3.3792"
    return RegExp(r'^-?\d+\.\d+\s*,\s*-?\d+\.\d+$').hasMatch(l);
  }
}

const kPopularLocations = <AppLocation>[
  AppLocation(
      latitude: 6.6018,
      longitude: 3.3515,
      city: 'Lagos',
      area: 'Ikeja',
      label: 'Ikeja, Lagos'),
  AppLocation(
      latitude: 6.4541,
      longitude: 3.3947,
      city: 'Lagos',
      area: 'Lagos Island',
      label: 'Lagos Island'),
  AppLocation(
      latitude: 6.4281,
      longitude: 3.4219,
      city: 'Lagos',
      area: 'Victoria Island',
      label: 'Victoria Island, Lagos'),
  AppLocation(
      latitude: 6.4474,
      longitude: 3.4722,
      city: 'Lagos',
      area: 'Lekki',
      label: 'Lekki, Lagos'),
  AppLocation(
      latitude: 6.5244,
      longitude: 3.3792,
      city: 'Lagos',
      area: 'Yaba',
      label: 'Yaba, Lagos'),
  AppLocation(
      latitude: 9.0765,
      longitude: 7.3986,
      city: 'Abuja',
      area: 'Central',
      label: 'Abuja Central'),
  AppLocation(
      latitude: 7.3775,
      longitude: 3.9470,
      city: 'Ibadan',
      area: 'Ibadan',
      label: 'Ibadan'),
  AppLocation(
      latitude: 4.8156,
      longitude: 7.0498,
      city: 'Port Harcourt',
      area: 'Port Harcourt',
      label: 'Port Harcourt'),
];

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const _key = 'wn_location';

  Future<bool> ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<AppLocation?> getCurrentLocation() async {
    final ok = await ensurePermission();
    if (!ok) return null;

    // medium is more reliable on web / weak GPS; retry once with high if needed
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 25),
        ),
      );
    }

    return resolvePlaceName(pos.latitude, pos.longitude);
  }

  /// Build a human-readable place from coordinates.
  Future<AppLocation> resolvePlaceName(double lat, double lng) async {
    String? city;
    String? area;
    String? label;

    // 1) Platform geocoding (works on mobile; often limited on web)
    try {
      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isNotEmpty) {
        final parsed = _fromPlacemark(places.first);
        city = parsed.$1;
        area = parsed.$2;
        label = parsed.$3;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('placemarkFromCoordinates failed: $e');
    }

    // 2) OpenStreetMap Nominatim (works on web + when device geocoder fails)
    if (label == null || label.isEmpty) {
      try {
        final nom = await _nominatimReverse(lat, lng);
        if (nom != null) {
          city ??= nom.$1;
          area ??= nom.$2;
          label = nom.$3;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('nominatim failed: $e');
      }
    }

    // 3) Snap to nearest popular area if within ~8km
    final nearest = _nearestPopular(lat, lng, maxKm: 8);
    if (nearest != null && (label == null || label.isEmpty)) {
      return AppLocation(
        latitude: lat,
        longitude: lng,
        city: nearest.city,
        area: nearest.area,
        label: nearest.label,
      );
    }

    // Prefer popular name if geocode only gave a vague region
    if (nearest != null &&
        (label == null ||
            label.length < 3 ||
            label.toLowerCase() == (city ?? '').toLowerCase())) {
      label = nearest.label;
      area ??= nearest.area;
      city ??= nearest.city;
    }

    label ??= (area != null || city != null)
        ? [area, city].whereType<String>().where((s) => s.isNotEmpty).join(', ')
        : 'Near ${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}';

    return AppLocation(
      latitude: lat,
      longitude: lng,
      city: city,
      area: area,
      label: label,
    );
  }

  /// (city, area, label)
  (String?, String?, String?) _fromPlacemark(Placemark p) {
    final areaCandidates = [
      p.subLocality,
      p.thoroughfare,
      p.street,
      p.locality,
      p.subAdministrativeArea,
      p.name,
    ];
    final cityCandidates = [
      p.locality,
      p.subAdministrativeArea,
      p.administrativeArea,
      p.country,
    ];

    String? pick(List<String?> list) {
      for (final s in list) {
        if (s != null && s.trim().isNotEmpty && s.trim() != 'Unnamed Road') {
          return s.trim();
        }
      }
      return null;
    }

    final area = pick(areaCandidates);
    var city = pick(cityCandidates);
    // Avoid "Ikeja, Ikeja"
    if (city != null && area != null && city.toLowerCase() == area.toLowerCase()) {
      city = pick(cityCandidates.skip(1).toList()) ?? p.administrativeArea;
    }

    final parts = <String>[
      if (area != null) area,
      if (city != null && city.toLowerCase() != (area ?? '').toLowerCase()) city,
    ];
    final label = parts.isNotEmpty ? parts.join(', ') : null;
    return (city, area, label);
  }

  /// (city, area, label) via Nominatim
  Future<(String?, String?, String?)?> _nominatimReverse(
      double lat, double lng) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=jsonv2&lat=$lat&lon=$lng&zoom=16&addressdetails=1',
    );
    final res = await http.get(
      uri,
      headers: {
        // Nominatim requires a valid User-Agent
        'User-Agent': 'WhoseNearby/1.0 (local-dev)',
        'Accept-Language': 'en',
      },
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    if (data is! Map) return null;
    final addr = data['address'];
    if (addr is! Map) {
      final dn = data['display_name']?.toString();
      if (dn != null && dn.isNotEmpty) {
        final short = dn.split(',').take(2).map((s) => s.trim()).join(', ');
        return (null, null, short);
      }
      return null;
    }

    final area = _firstString(addr, [
      'suburb',
      'neighbourhood',
      'neighborhood',
      'quarter',
      'city_district',
      'municipality',
      'town',
      'village',
      'hamlet',
      'county',
    ]);
    final city = _firstString(addr, [
      'city',
      'town',
      'state_district',
      'state',
      'region',
    ]);
    final parts = <String>[
      if (area != null) area,
      if (city != null && city.toLowerCase() != area?.toLowerCase()) city,
    ];
    final label = parts.isNotEmpty
        ? parts.join(', ')
        : data['name']?.toString() ??
            data['display_name']?.toString().split(',').take(2).join(', ');
    return (city, area, label);
  }

  String? _firstString(Map addr, List<String> keys) {
    for (final k in keys) {
      final v = addr[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  AppLocation? _nearestPopular(double lat, double lng, {double maxKm = 8}) {
    AppLocation? best;
    var bestKm = maxKm;
    for (final loc in kPopularLocations) {
      final km = Geolocator.distanceBetween(
            lat,
            lng,
            loc.latitude,
            loc.longitude,
          ) /
          1000.0;
      if (km < bestKm) {
        bestKm = km;
        best = loc;
      }
    }
    return best;
  }

  Future<void> saveLocal(AppLocation loc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(loc.toJson()));
  }

  Future<AppLocation?> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return AppLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToServer(AppLocation loc) async {
    try {
      final user = await ApiClient.instance.patch(
        '/auth/me',
        auth: true,
        body: {
          'latitude': loc.latitude,
          'longitude': loc.longitude,
          if (loc.city != null) 'city': loc.city,
          if (loc.area != null) 'area': loc.area,
        },
      ) as Map<String, dynamic>;
      final token = await AuthStorage.instance.getToken();
      if (token != null) {
        await AuthStorage.instance.saveSession(token: token, user: user);
      }
    } catch (_) {}
  }

  Future<void> apply(AppLocation loc) async {
    // Prefer keeping a good label (popular areas) — don't block on geocode.
    var finalLoc = loc;
    if (loc.labelLooksLikeCoordinates) {
      try {
        finalLoc = await resolvePlaceName(loc.latitude, loc.longitude)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await saveLocal(finalLoc);
    // Server update: best-effort, short timeout handled by caller too
    try {
      await saveToServer(finalLoc).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<AppLocation> resolve() async {
    final saved = await loadLocal();
    if (saved != null) {
      // Upgrade old saves that only stored coordinates
      if (saved.labelLooksLikeCoordinates) {
        try {
          final named =
              await resolvePlaceName(saved.latitude, saved.longitude);
          await saveLocal(named);
          return named;
        } catch (_) {
          return saved;
        }
      }
      return saved;
    }

    final live = await getCurrentLocation();
    if (live != null) {
      await saveLocal(live);
      return live;
    }

    return kPopularLocations.first;
  }
}

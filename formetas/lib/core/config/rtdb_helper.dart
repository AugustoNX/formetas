import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

abstract final class RtdbHelper {
  static const databaseUrl =
      'https://formetas-85c14-default-rtdb.firebaseio.com';

  static FirebaseDatabase get database => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: databaseUrl,
      );

  static DatabaseReference userRef(String userId) =>
      database.ref('users/$userId');

  static Map<String, dynamic> toStringKeyMap(Object? value) {
    if (value == null || value is! Map) return {};
    return value.map(
      (key, val) => MapEntry(key.toString(), _deepConvert(val)),
    );
  }

  static dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _deepConvert(v)));
    }
    if (value is List) {
      return value.map(_deepConvert).toList();
    }
    return value;
  }

  static List<T> parseChildren<T>(
    Object? value,
    T Function(Map<String, dynamic> map, String id) fromMap,
  ) {
    final map = toStringKeyMap(value);
    return map.entries
        .map((entry) {
          final data = entry.value;
          if (data is! Map) return null;
          return fromMap(Map<String, dynamic>.from(data), entry.key);
        })
        .whereType<T>()
        .toList();
  }
}

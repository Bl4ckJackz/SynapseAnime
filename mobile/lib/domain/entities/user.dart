import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String? nickname;
  final UserPreference? preference;

  const User({
    required this.id,
    required this.email,
    this.nickname,
    this.preference,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String?,
      preference: json['preference'] != null
          ? UserPreference.fromJson(json['preference'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'preference': preference?.toJson(),
    };
  }

  @override
  List<Object?> get props => [id, email, nickname, preference];
}

class UserPreference extends Equatable {
  final List<String> preferredLanguages;
  final List<String> preferredGenres;

  const UserPreference({
    this.preferredLanguages = const [],
    this.preferredGenres = const [],
  });

  factory UserPreference.fromJson(Map<String, dynamic> json) {
    return UserPreference(
      preferredLanguages: (json['preferredLanguages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      preferredGenres: (json['preferredGenres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferredLanguages': preferredLanguages,
      'preferredGenres': preferredGenres,
    };
  }

  @override
  List<Object?> get props => [preferredLanguages, preferredGenres];
}

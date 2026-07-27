/// Response from `GET` / `PATCH /api/me/profile`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.name,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.fitnessLevel,
    this.primaryGoal,
    this.trainingFrequency,
    this.availableEquipment,
    this.limitations,
    this.availableTimeMinutes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String? name;
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final String? fitnessLevel;
  final String? primaryGoal;
  final String? trainingFrequency;
  final String? availableEquipment;
  final String? limitations;
  final int? availableTimeMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      age: json['age'] as int?,
      sex: json['sex'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      fitnessLevel: json['fitness_level'] as String?,
      primaryGoal: json['primary_goal'] as String?,
      trainingFrequency: json['training_frequency'] as String?,
      availableEquipment: json['available_equipment'] as String?,
      limitations: json['limitations'] as String?,
      availableTimeMinutes: json['available_time_minutes'] as int?,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

/// Partial body for `PATCH /api/me/profile`. Only set fields are sent.
class ProfileUpdate {
  const ProfileUpdate({
    this.name,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.fitnessLevel,
    this.primaryGoal,
    this.trainingFrequency,
    this.availableEquipment,
    this.limitations,
    this.availableTimeMinutes,
  });

  final String? name;
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final String? fitnessLevel;
  final String? primaryGoal;
  final String? trainingFrequency;
  final String? availableEquipment;
  final String? limitations;
  final int? availableTimeMinutes;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (name != null) json['name'] = name;
    if (age != null) json['age'] = age;
    if (sex != null) json['sex'] = sex;
    if (heightCm != null) json['height_cm'] = heightCm;
    if (weightKg != null) json['weight_kg'] = weightKg;
    if (fitnessLevel != null) json['fitness_level'] = fitnessLevel;
    if (primaryGoal != null) json['primary_goal'] = primaryGoal;
    if (trainingFrequency != null) {
      json['training_frequency'] = trainingFrequency;
    }
    if (availableEquipment != null) {
      json['available_equipment'] = availableEquipment;
    }
    if (limitations != null) json['limitations'] = limitations;
    if (availableTimeMinutes != null) {
      json['available_time_minutes'] = availableTimeMinutes;
    }
    return json;
  }
}

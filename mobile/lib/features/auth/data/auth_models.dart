/// Request body for `POST /api/login`.
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };
}

/// Response body for `POST /api/login`.
class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    this.tokenType = 'bearer',
  });

  final String accessToken;
  final String tokenType;

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
    );
  }
}

/// Request body for `POST /api/register` (matches backend `UserCreate`).
class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.password,
    required this.name,
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.fitnessLevel,
    required this.primaryGoal,
    required this.trainingFrequency,
    this.availableEquipment = '',
    this.limitations = '',
  });

  final String email;
  final String password;
  final String name;
  final int age;
  final String sex;
  final double heightCm;
  final double weightKg;
  final String fitnessLevel;
  final String primaryGoal;
  final String trainingFrequency;
  final String availableEquipment;
  final String limitations;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'name': name,
    'age': age,
    'sex': sex,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'fitness_level': fitnessLevel,
    'primary_goal': primaryGoal,
    'training_frequency': trainingFrequency,
    'available_equipment': availableEquipment,
    'limitations': limitations,
  };
}

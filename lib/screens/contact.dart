class Contact {
  final String firstName;
  final String lastName;
  final String gender;
  final DateTime birthday;
  final String relationship;
  final String? imagePath;
  final List<String> likes;
  final List<String> dislikes;
  final List<Map<String, dynamic>> additionalDates;

  Contact({
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.birthday,
    required this.relationship,
    this.imagePath,
    required this.likes,
    required this.dislikes,
    required this.additionalDates,
  });

  // Convert Contact to JSON
  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'gender': gender,
    'birthday': birthday.toIso8601String(),
    'relationship': relationship,
    'imagePath': imagePath,
    'likes': likes,
    'dislikes': dislikes,
    'additionalDates': additionalDates,
  };

  // Create Contact from JSON
  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    firstName: json['firstName'],
    lastName: json['lastName'],
    gender: json['gender'],
    birthday: DateTime.parse(json['birthday']),
    relationship: json['relationship'],
    imagePath: json['imagePath'],
    likes: List<String>.from(json['likes']),
    dislikes: List<String>.from(json['dislikes']),
    additionalDates: List<Map<String, dynamic>>.from(json['additionalDates'] ?? []),
  );
}

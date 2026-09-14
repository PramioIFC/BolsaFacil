class UserAccount {
  const UserAccount({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory UserAccount.fromMap(Map<String, Object?> map) => UserAccount(
        id: map['id'] as int,
        name: map['name'] as String,
        email: map['email'] as String,
      );
}

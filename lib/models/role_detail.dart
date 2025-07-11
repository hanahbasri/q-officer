class RoleDetail {
  final String rolesId;
  final String appsId;
  final String roleName;

  RoleDetail({
    required this.rolesId,
    required this.appsId,
    required this.roleName,
  });

  factory RoleDetail.fromJson(Map<String, dynamic> json) {
    return RoleDetail(
      rolesId: json['roles_id'] ?? '',
      appsId: json['apps_id'] ?? '',
      roleName: json['role_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roles_id': rolesId,
      'apps_id': appsId,
      'role_name': roleName,
    };
  }
}

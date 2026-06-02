class UserModel {
  final String uid;
  final String nombre;
  final String correo;
  final String rol; 
  final String estado; 
  final String sede;

  UserModel({required this.uid, required this.nombre, required this.correo, required this.rol, required this.estado, required this.sede});

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      nombre: data['nombre'] ?? '',
      correo: data['correo'] ?? '',
      rol: data['rol'] ?? 'operador',
      estado: data['estado'] ?? 'activo',
      sede: data['sede'] ?? 'Sin sede',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'estado': estado,
      'sede': sede,
    };
  }
}

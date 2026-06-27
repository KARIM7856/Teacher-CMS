/// One achievement to celebrate, as returned by the `claim_achievements` RPC.
/// Drives the celebration overlay — adding a new achievement server-side needs
/// no client change.
class CelebrationData {
  const CelebrationData({
    required this.code,
    required this.title,
    this.message,
    this.icon,
  });

  final String code;
  final String title;
  final String? message;
  final String? icon;

  factory CelebrationData.fromRpc(Map<String, dynamic> map) {
    return CelebrationData(
      code: map['code'] as String,
      title: map['title'] as String,
      message: map['description'] as String?,
      icon: map['icon'] as String?,
    );
  }
}

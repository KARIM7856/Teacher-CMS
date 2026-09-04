import 'package:flutter/material.dart';

import '../../../core/config/app_info.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/external_link.dart';

/// Explains how a student gets their account and data deleted, and gives them
/// one tap to start the request.
///
/// The app deliberately has no self-service delete button: accounts are created
/// by the teacher, not by the student, so a student deleting their own account
/// would destroy a roster entry the teacher owns. Both app stores accept a
/// documented request route for teacher/school-administered accounts, but they
/// do expect it to be reachable *from inside the app* — which is what this
/// screen is. The same information is published at [AppInfo.accountDeletionUrl]
/// for the Play Console's data-deletion URL field.
class AccountDeletionScreen extends StatelessWidget {
  const AccountDeletionScreen({super.key, this.username});

  /// Pre-filled into the request so the teacher can find the account. Null when
  /// it couldn't be read from the session.
  final String? username;

  static Route<void> route({String? username}) {
    return MaterialPageRoute<void>(
      builder: (_) => AccountDeletionScreen(username: username),
    );
  }

  /// A mailto: with the subject and body already written, so the student only
  /// has to press send.
  ///
  /// The query is built by hand rather than with `Uri(queryParameters: …)`,
  /// which form-encodes spaces as `+`; mail clients render those literally, so
  /// the draft would arrive full of plus signs. Percent-encoding every component
  /// is also what makes the Arabic subject and the newlines survive.
  Uri get _requestEmail {
    final String account = username ?? '(اكتب اسم المستخدم هنا)';
    final String subject = Uri.encodeComponent('طلب حذف حساب');
    final String body = Uri.encodeComponent(
      'أرجو حذف حسابي وبياناتي من تطبيق ${AppInfo.appName}.\n\n'
      'اسم المستخدم: $account\n'
      'الاسم: \n'
      'المجموعة / الفصل: \n\n'
      'ملاحظة: لا ترسل كلمة المرور مع هذا الطلب.',
    );
    return Uri.parse(
      'mailto:${AppInfo.supportEmail}?subject=$subject&body=$body',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('حذف الحساب')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'حسابك ينشئه معلّمك ويديره، ولذلك لا يوجد زر حذف مباشر داخل '
                'التطبيق. يمكنك طلب الحذف بإحدى طريقتين.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Step(
            number: '1',
            title: 'اطلب من معلّمك',
            body: 'أسرع طريقة: اطلب من معلّمك حذف حسابك من صفحة «الطلاب» في بوابة '
                'الإدارة. يُنفَّذ الحذف فورًا.',
          ),
          const SizedBox(height: AppSpacing.md),
          _Step(
            number: '2',
            title: 'أو راسلنا',
            body: 'أرسل طلبًا إلى ${AppInfo.supportEmail} من اسم المستخدم الخاص بك. '
                'نعالج الطلب خلال 30 يومًا كحدٍّ أقصى. لا ترسل كلمة المرور أبدًا.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('ما الذي يُحذف', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const _Bullet('بيانات الدخول: اسم المستخدم وكلمة المرور.'),
          const _Bullet('الاسم المعروض وبيانات كشف الفصل المرتبطة بك.'),
          const _Bullet('سجل المشاهدة: الدروس المفتوحة ومواضع التوقّف في الفيديو.'),
          const _Bullet('أيام النشاط والإنجازات التي فتحتها.'),
          const _Bullet('عضويتك في المجموعات الدراسية.'),
          const SizedBox(height: AppSpacing.md),
          Text(
            'المحتوى التعليمي نفسه يخصّ المعلّم ولا يتأثّر. قد تبقى سجلات الخوادم '
            'التقنية مدة قصيرة لأغراض الأمان.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: () => openExternalUrl(
              context,
              _requestEmail.toString(),
              failureMessage: 'تعذّر فتح تطبيق البريد. راسلنا على '
                  '${AppInfo.supportEmail}',
            ),
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('إرسال طلب الحذف بالبريد'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () =>
                openExternalUrl(context, AppInfo.accountDeletionUrl),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('التفاصيل الكاملة على الويب'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'تريد التوقّف مؤقتًا فقط؟ اطلب من معلّمك تعطيل الحساب بدل حذفه — يمنع '
            'ذلك الدخول مع الاحتفاظ بتقدّمك.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            number,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(body, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppSpacing.xs,
        start: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: theme.textTheme.bodyMedium),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

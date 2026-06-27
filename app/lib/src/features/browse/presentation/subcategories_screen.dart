import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/placeholder_view.dart';
import '../../../models/category.dart';
import '../../../models/subcategory.dart';
import '../../content/application/content_providers.dart';
import 'posts_screen.dart';

/// Lists the subcategories under a [Category]. Tapping one shows its posts.
class SubcategoriesScreen extends ConsumerWidget {
  const SubcategoriesScreen({super.key, required this.category});

  final Category category;

  static Route<void> route(Category category) {
    return MaterialPageRoute<void>(
      builder: (_) => SubcategoriesScreen(category: category),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Subcategory>> subcategories =
        ref.watch(subcategoriesProvider(category.id));

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: AsyncValueWidget<List<Subcategory>>(
        value: subcategories,
        onRetry: () => ref.invalidate(subcategoriesProvider(category.id)),
        data: (items) {
          if (items.isEmpty) {
            return const PlaceholderView(
              icon: Icons.folder_open_outlined,
              title: 'لا توجد أقسام',
              message: 'لا توجد أقسام داخل هذا التصنيف بعد.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final Subcategory sub = items[index];
              return Card(
                margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: ListTile(
                  title: Text(sub.name),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () =>
                      Navigator.of(context).push(PostsScreen.route(sub)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

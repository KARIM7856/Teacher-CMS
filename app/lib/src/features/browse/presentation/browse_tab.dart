import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/placeholder_view.dart';
import '../../../models/category.dart';
import '../../content/application/content_providers.dart';
import 'subcategories_screen.dart';

/// The Browse tab: the catalog's top-level categories. Tapping one drills into
/// its subcategories.
class BrowseTab extends ConsumerWidget {
  const BrowseTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Category>> categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تصفّح')),
      body: AsyncValueWidget<List<Category>>(
        value: categories,
        onRetry: () => ref.invalidate(categoriesProvider),
        data: (items) {
          if (items.isEmpty) {
            return const PlaceholderView(
              icon: Icons.category_outlined,
              title: 'لا توجد تصنيفات',
              message: 'ستظهر التصنيفات هنا بمجرّد أن ينشرها معلّمك.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(categoriesProvider);
              await ref.read(categoriesProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _CategoryTile(category: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(Icons.folder_rounded,
              color: theme.colorScheme.onSecondaryContainer),
        ),
        title: Text(category.name, style: theme.textTheme.titleMedium),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => Navigator.of(context).push(
          SubcategoriesScreen.route(category),
        ),
      ),
    );
  }
}

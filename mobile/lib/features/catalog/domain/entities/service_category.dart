import 'package:zuno/features/catalog/domain/entities/service_sub_category.dart';

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    this.iconName,
    this.subCategories = const [],
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;

  /// Which built-in icon to draw for this category, chosen by the app owner and stored with the
  /// row. Null on a category nobody has picked one for, which the client then guesses from the name.
  final String? iconName;

  /// The narrower kinds of work offered inside this category.
  final List<ServiceSubCategory> subCategories;
}

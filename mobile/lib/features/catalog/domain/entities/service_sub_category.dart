/// A narrower kind of work inside a main category — "Kitchen cleaning" under "Cleaning".
///
/// Items on a service are tagged with one of these. The main category is never picked twice:
/// it comes from the parent service, and only that category's sub-categories are offered.
class ServiceSubCategory {
  const ServiceSubCategory({
    required this.id,
    required this.serviceCategoryId,
    required this.name,
    required this.slug,
  });

  final String id;
  final String serviceCategoryId;
  final String name;
  final String slug;
}

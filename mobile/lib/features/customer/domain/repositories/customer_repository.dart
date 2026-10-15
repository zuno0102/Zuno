import 'package:zuno/features/customer/domain/entities/business_detail.dart';
import 'package:zuno/features/customer/domain/entities/home_sections.dart';
import 'package:zuno/features/customer/domain/entities/service_detail.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';

abstract interface class CustomerRepository {
  /// Browses services across every business.
  Future<List<ServiceListing>> searchServices({
    String? categoryId,
    String? keyword,
    List<String>? districtIds,
  });

  /// Every section of the home screen, composed so none of them repeat.
  Future<HomeSections> getHomeSections({int? seed});

  /// Today's banner services, chosen and rotated by the server.
  Future<List<ServiceListing>> getBanners();

  /// One service on its own, with every package it is sold in.
  Future<ServiceDetail> getServiceDetail(String id);

  Future<BusinessDetail> getBusinessDetail(String id);
}

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/business_plan/data/business_plan_repository.dart';
import 'package:zuno/features/business_plan/domain/business_plan.dart';

part 'business_plan_providers.g.dart';

@Riverpod(keepAlive: true)
BusinessPlanRepository businessPlanRepository(Ref ref) =>
    BusinessPlanRepositoryImpl(ref.watch(dioClientProvider));

/// The business's plan and its use in each area. Read afresh whenever a screen asks for it again,
/// so a listing just added or a plan just bought shows at once.
@riverpod
Future<BusinessPlan> businessPlan(Ref ref) =>
    ref.watch(businessPlanRepositoryProvider).getPlan();

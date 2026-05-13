import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../services/purchase_service.dart';
import '../../../../services/api_service.dart';

// Events
abstract class BillingEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadOfferings extends BillingEvent {}

class PurchasePackage extends BillingEvent {
  final Package package;
  PurchasePackage(this.package);

  @override
  List<Object?> get props => [package];
}

class PurchaseStoreProduct extends BillingEvent {
  final StoreProduct product;
  PurchaseStoreProduct(this.product);

  @override
  List<Object?> get props => [product];
}

class RestorePurchases extends BillingEvent {}

// State
abstract class BillingState extends Equatable {
  @override
  List<Object?> get props => [];
}

class BillingInitial extends BillingState {}

class BillingLoading extends BillingState {}

class OfferingsLoaded extends BillingState {
  final Offerings offerings;
  OfferingsLoaded(this.offerings);

  @override
  List<Object?> get props => [offerings];
}

class PurchaseSuccess extends BillingState {
  final String entitlementId;
  PurchaseSuccess(this.entitlementId);

  @override
  List<Object?> get props => [entitlementId];
}

class PurchaseCancelled extends BillingState {}

class OfferingsLoadFailed extends BillingState {
  final String message;
  OfferingsLoadFailed(this.message);

  @override
  List<Object?> get props => [message];
}

class PurchaseFailed extends BillingState {
  final String message;
  PurchaseFailed(this.message);

  @override
  List<Object?> get props => [message];
}

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final PurchaseService _purchaseService = PurchaseService();
  final ApiService _apiService = ApiService();

  /// RevenueCat's REST payload can lag slightly behind StoreKit/Play success.
  /// Multiple syncs give the backend a fresh purchase list before the UI refetches `/me`.
  Future<void> _syncBillingBackendAfterPurchase() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: attempt == 1 ? 700 : 900),
        );
      }
      try {
        await _apiService.post('/api/v1/billing/sync');
      } catch (e) {
        // ignore: avoid_print
        print('Backend billing/sync attempt ${attempt + 1} failed: $e');
      }
    }
  }

  BillingBloc() : super(BillingInitial()) {
    on<LoadOfferings>(_onLoadOfferings);
    on<PurchasePackage>(_onPurchasePackage);
    on<PurchaseStoreProduct>(_onPurchaseStoreProduct);
    on<RestorePurchases>(_onRestorePurchases);
  }

  Future<void> _onLoadOfferings(LoadOfferings event, Emitter<BillingState> emit) async {
    emit(BillingLoading());
    try {
      final offerings = await _purchaseService.getOfferings();
      if (offerings != null) {
        emit(OfferingsLoaded(offerings));
      } else {
        emit(OfferingsLoadFailed("No offerings available."));
      }
    } catch (e) {
      emit(OfferingsLoadFailed(e.toString()));
    }
  }

  Future<void> _onPurchasePackage(PurchasePackage event, Emitter<BillingState> emit) async {
    emit(BillingLoading());
    try {
      final result = await _purchaseService.purchasePackage(event.package);
      if (result.outcome == PurchaseOutcome.success) {
        await _syncBillingBackendAfterPurchase();
        emit(PurchaseSuccess("active_plan"));
      } else if (result.outcome == PurchaseOutcome.cancelled) {
        emit(PurchaseCancelled());
      } else {
        emit(PurchaseFailed(result.message ?? "Purchase failed."));
      }
    } catch (e) {
      emit(PurchaseFailed(e.toString()));
    }
  }

  Future<void> _onPurchaseStoreProduct(PurchaseStoreProduct event, Emitter<BillingState> emit) async {
    emit(BillingLoading());
    try {
      final result = await _purchaseService.purchaseStoreProduct(event.product);
      if (result.outcome == PurchaseOutcome.success) {
        await _syncBillingBackendAfterPurchase();
        emit(PurchaseSuccess(event.product.identifier));
      } else if (result.outcome == PurchaseOutcome.cancelled) {
        emit(PurchaseCancelled());
      } else {
        emit(PurchaseFailed(result.message ?? "Purchase failed."));
      }
    } catch (e) {
      emit(PurchaseFailed(e.toString()));
    }
  }

  Future<void> _onRestorePurchases(RestorePurchases event, Emitter<BillingState> emit) async {
    emit(BillingLoading());
    try {
      await _purchaseService.restorePurchases();
      await _syncBillingBackendAfterPurchase();
      emit(BillingInitial()); // Refresh state
      add(LoadOfferings());
    } catch (e) {
      emit(OfferingsLoadFailed(e.toString()));
    }
  }
}

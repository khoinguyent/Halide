import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../services/purchase_service.dart';

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

class BillingError extends BillingState {
  final String message;
  BillingError(this.message);

  @override
  List<Object?> get props => [message];
}

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final PurchaseService _purchaseService = PurchaseService();

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
        emit(BillingError("No offerings available."));
      }
    } catch (e) {
      emit(BillingError(e.toString()));
    }
  }

  Future<void> _onPurchasePackage(PurchasePackage event, Emitter<BillingState> emit) async {
    emit(BillingLoading());
    try {
      final success = await _purchaseService.purchasePackage(event.package);
      if (success) {
        emit(PurchaseSuccess("active_plan"));
      } else {
        emit(BillingError("Purchase failed."));
      }
    } catch (e) {
      emit(BillingError(e.toString()));
    }
  }

  Future<void> _onPurchaseStoreProduct(PurchaseStoreProduct event, Emitter<BillingState> emit) async {
    emit(BillingLoading());
    try {
      final success = await _purchaseService.purchaseProduct(event.product.identifier);
      if (success) {
        emit(PurchaseSuccess(event.product.identifier));
      } else {
        emit(BillingError("Purchase failed."));
      }
    } catch (e) {
      emit(BillingError(e.toString()));
    }
  }

  Future<void> _onRestorePurchases(RestorePurchases event, Emitter<BillingState> emit) async {
    emit(BillingLoading());
    try {
      await _purchaseService.restorePurchases();
      emit(BillingInitial()); // Refresh state
      add(LoadOfferings());
    } catch (e) {
      emit(BillingError(e.toString()));
    }
  }
}

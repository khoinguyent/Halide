import '../../models/user_profile.dart';

/// Free Archive tier: up to [kFreeTierMaxCameras] bodies, each with at most
/// [kFreeTierMaxLensesPerCamera] mounted lens. Pro is unlimited.
const int kFreeTierMaxCameras = 3;
const int kFreeTierMaxLensesPerCamera = 1;

bool isFreeArchivePlan(UserPlan plan) => plan == UserPlan.free;

bool canAddCameraOnPlan(UserPlan plan, int currentCameraCount) =>
    !isFreeArchivePlan(plan) || currentCameraCount < kFreeTierMaxCameras;

bool canMountLensOnCamera(UserPlan plan, int lensesOnCamera) =>
    !isFreeArchivePlan(plan) || lensesOnCamera < kFreeTierMaxLensesPerCamera;

String freeTierCameraLimitMessage() =>
    'Free includes up to $kFreeTierMaxCameras cameras. Upgrade to Halide Pro for unlimited gear.';

String freeTierLensLimitMessage() =>
    'Free includes one lens per camera. Upgrade to Halide Pro to mount more.';

String freeTierStandaloneLensMessage() =>
    'On Free, add lenses from a camera\'s Mount screen (one lens per body).';

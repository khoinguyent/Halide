import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AgXel'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Analog heart, Digital Brain'**
  String get appTagline;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @less.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get less;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open link.'**
  String get couldNotOpenLink;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String lastUpdated(String date);

  /// No description provided for @languageSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get languageSettingsTitle;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get languageVietnamese;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language for the app.'**
  String get languageDescription;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get profileTitle;

  /// No description provided for @filmEnthusiast.
  ///
  /// In en, this message translates to:
  /// **'Film Enthusiast'**
  String get filmEnthusiast;

  /// No description provided for @halidePremium.
  ///
  /// In en, this message translates to:
  /// **'AgXel'**
  String get halidePremium;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @storageStrategy.
  ///
  /// In en, this message translates to:
  /// **'Storage strategy'**
  String get storageStrategy;

  /// No description provided for @themes.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get themes;

  /// No description provided for @shootingAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Shooting Analytics'**
  String get shootingAnalytics;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsAndConditions;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent. All your film rolls, EXIF logs, and cloud-synced images will be wiped from our servers immediately.'**
  String get deleteAccountBody;

  /// No description provided for @planPro.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get planPro;

  /// No description provided for @planFree.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get planFree;

  /// No description provided for @loginWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Login with Email'**
  String get loginWithEmail;

  /// No description provided for @loginWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Login with Phone'**
  String get loginWithPhone;

  /// No description provided for @loginWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Login with Google'**
  String get loginWithGoogle;

  /// No description provided for @loginWithApple.
  ///
  /// In en, this message translates to:
  /// **'Login with Apple'**
  String get loginWithApple;

  /// No description provided for @verifyPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhone;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get verificationCode;

  /// No description provided for @verifyAndLogin.
  ///
  /// In en, this message translates to:
  /// **'Verify & Login'**
  String get verifyAndLogin;

  /// No description provided for @backToOptions.
  ///
  /// In en, this message translates to:
  /// **'Back to options'**
  String get backToOptions;

  /// No description provided for @newHere.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get newHere;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @emailSignIn.
  ///
  /// In en, this message translates to:
  /// **'Email Sign In'**
  String get emailSignIn;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @phoneSignIn.
  ///
  /// In en, this message translates to:
  /// **'Phone Sign In'**
  String get phoneSignIn;

  /// No description provided for @phoneSignInHint.
  ///
  /// In en, this message translates to:
  /// **'We will send a code to your number'**
  String get phoneSignInHint;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCode;

  /// No description provided for @phoneVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Phone verification failed'**
  String get phoneVerificationFailed;

  /// No description provided for @welcomeSignIn.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AgXel, please sign in!'**
  String get welcomeSignIn;

  /// No description provided for @welcomeSignUp.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AgXel, please sign up!'**
  String get welcomeSignUp;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'CREATE ACCOUNT'**
  String get registerTitle;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @archiveTitle.
  ///
  /// In en, this message translates to:
  /// **'ARCHIVE'**
  String get archiveTitle;

  /// No description provided for @openNewRoll.
  ///
  /// In en, this message translates to:
  /// **'Open New Roll'**
  String get openNewRoll;

  /// No description provided for @loadYourFirstRoll.
  ///
  /// In en, this message translates to:
  /// **'Load your first roll'**
  String get loadYourFirstRoll;

  /// No description provided for @showAllRolls.
  ///
  /// In en, this message translates to:
  /// **'Show all rolls'**
  String get showAllRolls;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get filterInProgress;

  /// No description provided for @filterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get filterArchived;

  /// No description provided for @lifecycleShoot.
  ///
  /// In en, this message translates to:
  /// **'Shoot'**
  String get lifecycleShoot;

  /// No description provided for @lifecycleLab.
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get lifecycleLab;

  /// No description provided for @lifecycleScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get lifecycleScan;

  /// No description provided for @lifecycleArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get lifecycleArchive;

  /// No description provided for @rollStatusShooting.
  ///
  /// In en, this message translates to:
  /// **'Shooting'**
  String get rollStatusShooting;

  /// No description provided for @rollStatusLab.
  ///
  /// In en, this message translates to:
  /// **'At Lab'**
  String get rollStatusLab;

  /// No description provided for @rollStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get rollStatusSyncing;

  /// No description provided for @rollStatusScanned.
  ///
  /// In en, this message translates to:
  /// **'Scanned'**
  String get rollStatusScanned;

  /// No description provided for @rollStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get rollStatusArchived;

  /// No description provided for @addRollStep1.
  ///
  /// In en, this message translates to:
  /// **'THE ROLL'**
  String get addRollStep1;

  /// No description provided for @addRollStep2.
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get addRollStep2;

  /// No description provided for @totalFrames.
  ///
  /// In en, this message translates to:
  /// **'Total Frames (e.g. 12, 24, 36)'**
  String get totalFrames;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @iso.
  ///
  /// In en, this message translates to:
  /// **'ISO'**
  String get iso;

  /// No description provided for @expiredYear.
  ///
  /// In en, this message translates to:
  /// **'Expired Year'**
  String get expiredYear;

  /// No description provided for @driveUrlOptional.
  ///
  /// In en, this message translates to:
  /// **'Drive URL (optional)'**
  String get driveUrlOptional;

  /// No description provided for @shotNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get shotNotesLabel;

  /// No description provided for @shotNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — up to 500 characters'**
  String get shotNotesHint;

  /// No description provided for @startRoll.
  ///
  /// In en, this message translates to:
  /// **'Start Roll'**
  String get startRoll;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @filmStock.
  ///
  /// In en, this message translates to:
  /// **'Film Stock (*)'**
  String get filmStock;

  /// No description provided for @gear.
  ///
  /// In en, this message translates to:
  /// **'Gear'**
  String get gear;

  /// No description provided for @logShot.
  ///
  /// In en, this message translates to:
  /// **'Log Shot'**
  String get logShot;

  /// No description provided for @openRoll.
  ///
  /// In en, this message translates to:
  /// **'Open Roll'**
  String get openRoll;

  /// No description provided for @driveLink.
  ///
  /// In en, this message translates to:
  /// **'Drive Link'**
  String get driveLink;

  /// No description provided for @saveAndSync.
  ///
  /// In en, this message translates to:
  /// **'Save & Sync'**
  String get saveAndSync;

  /// No description provided for @recordShot.
  ///
  /// In en, this message translates to:
  /// **'Record Shot'**
  String get recordShot;

  /// No description provided for @shutterSpeed.
  ///
  /// In en, this message translates to:
  /// **'Shutter Speed'**
  String get shutterSpeed;

  /// No description provided for @aperture.
  ///
  /// In en, this message translates to:
  /// **'Aperture'**
  String get aperture;

  /// No description provided for @logShotTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Shot'**
  String get logShotTitle;

  /// No description provided for @manualAddFree.
  ///
  /// In en, this message translates to:
  /// **'Manual Add (Free)'**
  String get manualAddFree;

  /// No description provided for @submitAndSync.
  ///
  /// In en, this message translates to:
  /// **'Submit & Sync'**
  String get submitAndSync;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @shotLog.
  ///
  /// In en, this message translates to:
  /// **'Shot Log'**
  String get shotLog;

  /// No description provided for @lockerTitle.
  ///
  /// In en, this message translates to:
  /// **'THE GEARS'**
  String get lockerTitle;

  /// No description provided for @addGear.
  ///
  /// In en, this message translates to:
  /// **'Add gear'**
  String get addGear;

  /// No description provided for @addFirstGear.
  ///
  /// In en, this message translates to:
  /// **'Add first gear'**
  String get addFirstGear;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @manufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get manufacturer;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @serialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get serialNumber;

  /// No description provided for @saveGear.
  ///
  /// In en, this message translates to:
  /// **'Save {gearType}'**
  String saveGear(String gearType);

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @lens.
  ///
  /// In en, this message translates to:
  /// **'Lens'**
  String get lens;

  /// No description provided for @cameraNotFound.
  ///
  /// In en, this message translates to:
  /// **'Camera not found'**
  String get cameraNotFound;

  /// No description provided for @editGear.
  ///
  /// In en, this message translates to:
  /// **'Edit gear'**
  String get editGear;

  /// No description provided for @editGearImages.
  ///
  /// In en, this message translates to:
  /// **'Edit gear images'**
  String get editGearImages;

  /// No description provided for @createAndMount.
  ///
  /// In en, this message translates to:
  /// **'Create & Mount'**
  String get createAndMount;

  /// No description provided for @createNewLens.
  ///
  /// In en, this message translates to:
  /// **'Create new lens'**
  String get createNewLens;

  /// No description provided for @createMountLensHint.
  ///
  /// In en, this message translates to:
  /// **'Create and mount a new lens to this body.'**
  String get createMountLensHint;

  /// No description provided for @newLensDetails.
  ///
  /// In en, this message translates to:
  /// **'New Lens Details'**
  String get newLensDetails;

  /// No description provided for @selectLensToMount.
  ///
  /// In en, this message translates to:
  /// **'Select Lens to Mount'**
  String get selectLensToMount;

  /// No description provided for @noLensesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No lenses available'**
  String get noLensesAvailable;

  /// No description provided for @gearStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get gearStatusActive;

  /// No description provided for @gearStatusRepair.
  ///
  /// In en, this message translates to:
  /// **'In Repair'**
  String get gearStatusRepair;

  /// No description provided for @gearStatusSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get gearStatusSold;

  /// No description provided for @gearStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get gearStatusArchived;

  /// No description provided for @meterTitle.
  ///
  /// In en, this message translates to:
  /// **'METER'**
  String get meterTitle;

  /// No description provided for @startingCamera.
  ///
  /// In en, this message translates to:
  /// **'Starting camera…'**
  String get startingCamera;

  /// No description provided for @logToRoll.
  ///
  /// In en, this message translates to:
  /// **'Log to Roll'**
  String get logToRoll;

  /// No description provided for @zoneOverlay.
  ///
  /// In en, this message translates to:
  /// **'Zone Overlay'**
  String get zoneOverlay;

  /// No description provided for @multiSpot.
  ///
  /// In en, this message translates to:
  /// **'Multi-Spot'**
  String get multiSpot;

  /// No description provided for @lockExposure.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lockExposure;

  /// No description provided for @changesUpdateEv.
  ///
  /// In en, this message translates to:
  /// **'Changes will update EV and the computed exposure.'**
  String get changesUpdateEv;

  /// No description provided for @subscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'AGXEL'**
  String get subscriptionTitle;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @restoredSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Restored successfully.'**
  String get restoredSuccessfully;

  /// No description provided for @noPreviousPurchases.
  ///
  /// In en, this message translates to:
  /// **'No previous purchases found.'**
  String get noPreviousPurchases;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore could not be completed. Please try again.'**
  String get restoreFailed;

  /// No description provided for @privacyPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyLink;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @freePlanName.
  ///
  /// In en, this message translates to:
  /// **'The Archive'**
  String get freePlanName;

  /// No description provided for @proPlanName.
  ///
  /// In en, this message translates to:
  /// **'AgXel'**
  String get proPlanName;

  /// No description provided for @annual.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get annual;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @freeFeature1.
  ///
  /// In en, this message translates to:
  /// **'Roll & frame logging (aperture, shutter, location)'**
  String get freeFeature1;

  /// No description provided for @freeFeature2.
  ///
  /// In en, this message translates to:
  /// **'Shooting → Lab → Scanned → Archived workflow'**
  String get freeFeature2;

  /// No description provided for @freeFeature3.
  ///
  /// In en, this message translates to:
  /// **'Up to 3 cameras (1 lens each) & unlimited rolls'**
  String get freeFeature3;

  /// No description provided for @freeFeature4.
  ///
  /// In en, this message translates to:
  /// **'Fetch images from Lab Drive'**
  String get freeFeature4;

  /// No description provided for @freeFeature5.
  ///
  /// In en, this message translates to:
  /// **'Personal cloud sync (Google Drive, NAS)'**
  String get freeFeature5;

  /// No description provided for @freeFeature6.
  ///
  /// In en, this message translates to:
  /// **'Standard EXIF logging'**
  String get freeFeature6;

  /// No description provided for @proFeature1.
  ///
  /// In en, this message translates to:
  /// **'Everything in Free'**
  String get proFeature1;

  /// No description provided for @proFeature2.
  ///
  /// In en, this message translates to:
  /// **'AgXel Cloud Storage (hosted System Cloud)'**
  String get proFeature2;

  /// No description provided for @proFeature3.
  ///
  /// In en, this message translates to:
  /// **'Professional light meter (spot metering & EV)'**
  String get proFeature3;

  /// No description provided for @proFeature4.
  ///
  /// In en, this message translates to:
  /// **'Advanced exposure guidance'**
  String get proFeature4;

  /// No description provided for @proFeature5.
  ///
  /// In en, this message translates to:
  /// **'Priority support'**
  String get proFeature5;

  /// No description provided for @storageLocal.
  ///
  /// In en, this message translates to:
  /// **'Local Device'**
  String get storageLocal;

  /// No description provided for @storagePersonalCloud.
  ///
  /// In en, this message translates to:
  /// **'Personal Cloud'**
  String get storagePersonalCloud;

  /// No description provided for @storageSystemCloud.
  ///
  /// In en, this message translates to:
  /// **'System Cloud'**
  String get storageSystemCloud;

  /// No description provided for @localStorage.
  ///
  /// In en, this message translates to:
  /// **'LOCAL STORAGE'**
  String get localStorage;

  /// No description provided for @systemCloud.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM CLOUD'**
  String get systemCloud;

  /// No description provided for @systemCloudConnections.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM CLOUD CONNECTIONS'**
  String get systemCloudConnections;

  /// No description provided for @localAccounts.
  ///
  /// In en, this message translates to:
  /// **'LOCAL ACCOUNTS'**
  String get localAccounts;

  /// No description provided for @connectGoogle.
  ///
  /// In en, this message translates to:
  /// **'Connect Google'**
  String get connectGoogle;

  /// No description provided for @connectNas.
  ///
  /// In en, this message translates to:
  /// **'Connect NAS'**
  String get connectNas;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @passwordField.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordField;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection Failed'**
  String get connectionFailed;

  /// No description provided for @archiveStorage.
  ///
  /// In en, this message translates to:
  /// **'Archive Storage'**
  String get archiveStorage;

  /// No description provided for @labScanSync.
  ///
  /// In en, this message translates to:
  /// **'Lab Scan Sync'**
  String get labScanSync;

  /// No description provided for @addStorage.
  ///
  /// In en, this message translates to:
  /// **'Add Storage'**
  String get addStorage;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get supportTitle;

  /// No description provided for @supportHeadline.
  ///
  /// In en, this message translates to:
  /// **'We read every message.'**
  String get supportHeadline;

  /// No description provided for @supportDescription.
  ///
  /// In en, this message translates to:
  /// **'Send your feedback, bug reports, and feature requests to {email}.'**
  String supportDescription(String email);

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// No description provided for @supportTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: screenshots help a lot.'**
  String get supportTip;

  /// No description provided for @unableToOpenEmail.
  ///
  /// In en, this message translates to:
  /// **'Unable to open your email app.'**
  String get unableToOpenEmail;

  /// No description provided for @supportEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'AgXel Support'**
  String get supportEmailSubject;

  /// No description provided for @feedbackEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'AgXel Feedback'**
  String get feedbackEmailSubject;

  /// No description provided for @themesTitle.
  ///
  /// In en, this message translates to:
  /// **'THEMES'**
  String get themesTitle;

  /// No description provided for @themeDeepHarbor.
  ///
  /// In en, this message translates to:
  /// **'Deep Harbor'**
  String get themeDeepHarbor;

  /// No description provided for @themeMistyForest.
  ///
  /// In en, this message translates to:
  /// **'Misty Forest'**
  String get themeMistyForest;

  /// No description provided for @themeOceanRoot.
  ///
  /// In en, this message translates to:
  /// **'Ocean Root'**
  String get themeOceanRoot;

  /// No description provided for @themeBlueBell.
  ///
  /// In en, this message translates to:
  /// **'Blue Bell'**
  String get themeBlueBell;

  /// No description provided for @themeCherryBlossom.
  ///
  /// In en, this message translates to:
  /// **'Cherry Blossom'**
  String get themeCherryBlossom;

  /// No description provided for @themeMorningFrost.
  ///
  /// In en, this message translates to:
  /// **'Morning Frost'**
  String get themeMorningFrost;

  /// No description provided for @themeCarbonNight.
  ///
  /// In en, this message translates to:
  /// **'Carbon Night'**
  String get themeCarbonNight;

  /// No description provided for @themeHarvestTable.
  ///
  /// In en, this message translates to:
  /// **'Harvest Table'**
  String get themeHarvestTable;

  /// No description provided for @themeSpaceIndigo.
  ///
  /// In en, this message translates to:
  /// **'Space Indigo'**
  String get themeSpaceIndigo;

  /// No description provided for @analyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'SHOOTING ANALYTICS'**
  String get analyticsTitle;

  /// No description provided for @exposureMatrix.
  ///
  /// In en, this message translates to:
  /// **'EXPOSURE MATRIX'**
  String get exposureMatrix;

  /// No description provided for @favoriteEmulsion.
  ///
  /// In en, this message translates to:
  /// **'FAVORITE EMULSION'**
  String get favoriteEmulsion;

  /// No description provided for @activeHardware.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE HARDWARE'**
  String get activeHardware;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get streak;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get current;

  /// No description provided for @best.
  ///
  /// In en, this message translates to:
  /// **'BEST'**
  String get best;

  /// No description provided for @longestStreak.
  ///
  /// In en, this message translates to:
  /// **'longest streak'**
  String get longestStreak;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get total;

  /// No description provided for @shotsFired.
  ///
  /// In en, this message translates to:
  /// **'shots fired'**
  String get shotsFired;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get active;

  /// No description provided for @activeDays.
  ///
  /// In en, this message translates to:
  /// **'active days'**
  String get activeDays;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY'**
  String get privacyTitle;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'TERMS'**
  String get termsTitle;

  /// No description provided for @privacyDocumentLabel.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY POLICY'**
  String get privacyDocumentLabel;

  /// No description provided for @termsDocumentLabel.
  ///
  /// In en, this message translates to:
  /// **'TERMS OF SERVICE'**
  String get termsDocumentLabel;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'EDIT PROFILE'**
  String get editProfileTitle;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @professionalNickname.
  ///
  /// In en, this message translates to:
  /// **'Professional Nickname'**
  String get professionalNickname;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileUpdated;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update profile.'**
  String get profileUpdateFailed;

  /// No description provided for @rollDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'ROLL'**
  String get rollDetailTitle;

  /// No description provided for @labDigitalSync.
  ///
  /// In en, this message translates to:
  /// **'Lab Digital Sync'**
  String get labDigitalSync;

  /// No description provided for @labDigitalSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a Google Drive folder or ZIP link from your lab.'**
  String get labDigitalSyncSubtitle;

  /// No description provided for @driveUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://drive.google.com/...'**
  String get driveUrlHint;

  /// No description provided for @atLabNoDriveUrlHint.
  ///
  /// In en, this message translates to:
  /// **'No Drive link? Change status to Scanned (use Next: Mark scanned above) to add photos from this device.'**
  String get atLabNoDriveUrlHint;

  /// No description provided for @atLabAddFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Add from device'**
  String get atLabAddFromDevice;

  /// No description provided for @atLabAddFromDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Free plans keep scans on this device. Pick photos from your library.'**
  String get atLabAddFromDeviceSubtitle;

  /// No description provided for @chooseLabImportMethodFree.
  ///
  /// In en, this message translates to:
  /// **'Add scan photos from this device.'**
  String get chooseLabImportMethodFree;

  /// No description provided for @driveLabSyncProOnly.
  ///
  /// In en, this message translates to:
  /// **'Syncing scans from a Drive link requires Halide Pro. Add photos from this device instead.'**
  String get driveLabSyncProOnly;

  /// No description provided for @scannedDriveSyncedHint.
  ///
  /// In en, this message translates to:
  /// **'Photos came from your lab Drive link. To update them, sync the Drive folder again — manual add is disabled so frame order stays intact.'**
  String get scannedDriveSyncedHint;

  /// No description provided for @addMorePhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get addMorePhotos;

  /// No description provided for @cameraScanning.
  ///
  /// In en, this message translates to:
  /// **'Camera Scanning'**
  String get cameraScanning;

  /// No description provided for @cameraScanningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hands-free gyro-assisted scan over a light table.'**
  String get cameraScanningSubtitle;

  /// No description provided for @scanNegatives.
  ///
  /// In en, this message translates to:
  /// **'Scan Negatives (Light Table)'**
  String get scanNegatives;

  /// No description provided for @addImages.
  ///
  /// In en, this message translates to:
  /// **'Add Images'**
  String get addImages;

  /// No description provided for @addMore.
  ///
  /// In en, this message translates to:
  /// **'Add More'**
  String get addMore;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploading;

  /// No description provided for @uploadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading {done} / {total}…'**
  String uploadingProgress(int done, int total);

  /// No description provided for @tapToSelectPhotos.
  ///
  /// In en, this message translates to:
  /// **'Tap to select photos'**
  String get tapToSelectPhotos;

  /// No description provided for @tapToSelectUpTo.
  ///
  /// In en, this message translates to:
  /// **'Tap to select up to {count} photos'**
  String tapToSelectUpTo(int count);

  /// No description provided for @addPhotosLeft.
  ///
  /// In en, this message translates to:
  /// **'Add photos ({count} left)'**
  String addPhotosLeft(int count);

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @sendAsPrint.
  ///
  /// In en, this message translates to:
  /// **'Send as postcard'**
  String get sendAsPrint;

  /// No description provided for @printComposeTitle.
  ///
  /// In en, this message translates to:
  /// **'Send postcard'**
  String get printComposeTitle;

  /// No description provided for @printSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get printSend;

  /// No description provided for @printNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note on the back'**
  String get printNoteLabel;

  /// No description provided for @printNoteHint.
  ///
  /// In en, this message translates to:
  /// **'A little love, the old-fashioned way…'**
  String get printNoteHint;

  /// No description provided for @printNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a note before sending.'**
  String get printNoteRequired;

  /// No description provided for @printFontLabel.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get printFontLabel;

  /// No description provided for @printFontHand.
  ///
  /// In en, this message translates to:
  /// **'Handwriting'**
  String get printFontHand;

  /// No description provided for @printFontType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get printFontType;

  /// No description provided for @printSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get printSizeLabel;

  /// No description provided for @printPaperLabel.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get printPaperLabel;

  /// No description provided for @printRecipientsLabel.
  ///
  /// In en, this message translates to:
  /// **'Friend emails'**
  String get printRecipientsLabel;

  /// No description provided for @printRecipientsHint.
  ///
  /// In en, this message translates to:
  /// **'friend@email.com, other@email.com'**
  String get printRecipientsHint;

  /// No description provided for @printRecipientsRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one email address.'**
  String get printRecipientsRequired;

  /// No description provided for @printFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get printFromLabel;

  /// No description provided for @printFromHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get printFromHint;

  /// No description provided for @printFromRequired.
  ///
  /// In en, this message translates to:
  /// **'Add your name so they know who sent it.'**
  String get printFromRequired;

  /// No description provided for @printExpireLabel.
  ///
  /// In en, this message translates to:
  /// **'Link expires'**
  String get printExpireLabel;

  /// No description provided for @printExpireDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String printExpireDays(int days);

  /// No description provided for @printPrivacyHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone with the link can open the postcard (up to 30 days). Downloads include the photo and a text file of the note.'**
  String get printPrivacyHint;

  /// No description provided for @printTapBack.
  ///
  /// In en, this message translates to:
  /// **'Tap to flip · love note on the back'**
  String get printTapBack;

  /// No description provided for @printTapFront.
  ///
  /// In en, this message translates to:
  /// **'Tap to see the photo'**
  String get printTapFront;

  /// No description provided for @printTapToWrite.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to write'**
  String get printTapToWrite;

  /// No description provided for @printStampHint.
  ///
  /// In en, this message translates to:
  /// **'Drag stamp · pinch size · double-tap to lock QR'**
  String get printStampHint;

  /// No description provided for @printStampLocked.
  ///
  /// In en, this message translates to:
  /// **'QR stamp locked'**
  String get printStampLocked;

  /// No description provided for @printStampRequired.
  ///
  /// In en, this message translates to:
  /// **'Double-tap the stamp to lock a QR image before sending.'**
  String get printStampRequired;

  /// No description provided for @printStampSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Suggested stamp size · {percent}%'**
  String printStampSizeHint(int percent);

  /// No description provided for @printVersoHint.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get printVersoHint;

  /// No description provided for @printNeedsCloudScan.
  ///
  /// In en, this message translates to:
  /// **'This photo isn\'t on AgXel Cloud yet. Only paid plans can upload and send postcards.'**
  String get printNeedsCloudScan;

  /// No description provided for @printSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Postcard sent to {count} · link expires in {days} days'**
  String printSentSuccess(int count, int days);

  /// No description provided for @printShareSubject.
  ///
  /// In en, this message translates to:
  /// **'A postcard for you'**
  String get printShareSubject;

  /// No description provided for @saveToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Save to Photos'**
  String get saveToPhotos;

  /// No description provided for @couldNotRotateImage.
  ///
  /// In en, this message translates to:
  /// **'Could not rotate image.'**
  String get couldNotRotateImage;

  /// No description provided for @couldNotUploadRotated.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t upload your rotated photos to the cloud. They\'re still saved on this phone — open the roll and try again.'**
  String get couldNotUploadRotated;

  /// No description provided for @editsLocalOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Edits save on this device. Upgrade to Pro to sync rotated images to the cloud.'**
  String get editsLocalOnlyHint;

  /// No description provided for @unsavedCloudChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved cloud changes: {count} — leaving uploads to AgXel Cloud.'**
  String unsavedCloudChanges(int count);

  /// No description provided for @scannedDate.
  ///
  /// In en, this message translates to:
  /// **'Scanned: {date}'**
  String scannedDate(String date);

  /// No description provided for @isoValue.
  ///
  /// In en, this message translates to:
  /// **'ISO {iso}'**
  String isoValue(String iso);

  /// No description provided for @apertureMissing.
  ///
  /// In en, this message translates to:
  /// **'---'**
  String get apertureMissing;

  /// No description provided for @retryDownload.
  ///
  /// In en, this message translates to:
  /// **'Retry download'**
  String get retryDownload;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get copyAll;

  /// No description provided for @lightTableLockScreen.
  ///
  /// In en, this message translates to:
  /// **'Lock Screen'**
  String get lightTableLockScreen;

  /// No description provided for @freeTierCameraLimit.
  ///
  /// In en, this message translates to:
  /// **'Free includes up to {count} cameras. Upgrade to AgXel for unlimited gear.'**
  String freeTierCameraLimit(int count);

  /// No description provided for @freeTierLensLimit.
  ///
  /// In en, this message translates to:
  /// **'Free includes one lens per camera. Upgrade to AgXel to mount more.'**
  String get freeTierLensLimit;

  /// No description provided for @freeTierStandaloneLens.
  ///
  /// In en, this message translates to:
  /// **'On Free, add lenses from a camera\'s Mount screen (one lens per body).'**
  String get freeTierStandaloneLens;

  /// No description provided for @couldNotUpdateStatus.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t update the status. Please try again.'**
  String get couldNotUpdateStatus;

  /// No description provided for @savedPhotosOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} photo(s) on this device.'**
  String savedPhotosOnDevice(int count);

  /// No description provided for @guidanceGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get guidanceGotIt;

  /// No description provided for @guidanceNewRollStatus.
  ///
  /// In en, this message translates to:
  /// **'Tap the status badge to change where you are in the workflow—e.g. move to At lab when the film is at the lab, then Scanned when you have files.'**
  String get guidanceNewRollStatus;

  /// No description provided for @guidanceNewRollExif.
  ///
  /// In en, this message translates to:
  /// **'Tap the camera icon to log aperture, shutter, and location from a photo\'s EXIF, or enter them manually in the sheet. You can also log from the Light Meter tab.'**
  String get guidanceNewRollExif;

  /// No description provided for @guidanceNewRollViewLogs.
  ///
  /// In en, this message translates to:
  /// **'Tap this roll card to open it, then use the Shot Log tab to see every frame\'s technical data while you\'re shooting.'**
  String get guidanceNewRollViewLogs;

  /// No description provided for @guidancePersonalDriveBackup.
  ///
  /// In en, this message translates to:
  /// **'Tap the cloud upload icon (top right) to back up full-quality scans to your personal Google Drive under an Agxel Vault folder.'**
  String get guidancePersonalDriveBackup;

  /// No description provided for @archiveBackupGuideBody.
  ///
  /// In en, this message translates to:
  /// **'Back up scanned rolls to your personal Google Drive anytime — tap the cloud upload icon above.'**
  String get archiveBackupGuideBody;

  /// No description provided for @guidanceSyncAfterLink.
  ///
  /// In en, this message translates to:
  /// **'Your Drive link is saved. Tap the highlighted cloud icon to download scans from Google Drive (you can tap again later to refresh).'**
  String get guidanceSyncAfterLink;

  /// No description provided for @guidanceAtLabBadge.
  ///
  /// In en, this message translates to:
  /// **'AT LAB means your film is with the lab. When you get a Google Drive link, use the link or cloud icon on the right to add it and sync your scans.'**
  String get guidanceAtLabBadge;

  /// No description provided for @guidanceDriveLinkWithUrl.
  ///
  /// In en, this message translates to:
  /// **'The cloud icon downloads scans from your saved Drive link. Tap the link icon if you need to change the URL.'**
  String get guidanceDriveLinkWithUrl;

  /// No description provided for @guidanceDriveLinkNoUrl.
  ///
  /// In en, this message translates to:
  /// **'Tap the highlighted link icon (top right) to paste the Google Drive folder URL when your lab shares it. After saving, the icon becomes a cloud you can tap to download scans.'**
  String get guidanceDriveLinkNoUrl;

  /// No description provided for @guidanceMeterSpotIntro.
  ///
  /// In en, this message translates to:
  /// **'Tap the circle to spot-meter the center and return to aperture priority. Tap f/ or SS to set exposure, EV or ISO for compensation, then LOCK to hold exposure while you compose.'**
  String get guidanceMeterSpotIntro;

  /// No description provided for @guidanceMeterLogToRoll.
  ///
  /// In en, this message translates to:
  /// **'Tap LOG TO ROLL to save aperture, shutter, and meter details to a roll in Shooting. Entries show in Shot Log with your archive EXIF logs.'**
  String get guidanceMeterLogToRoll;

  /// No description provided for @guidancePrintStampIntro.
  ///
  /// In en, this message translates to:
  /// **'Drag this stamp over the part of the photo you want on the QR. Pinch to resize, then double-tap to lock before you send.'**
  String get guidancePrintStampIntro;

  /// No description provided for @guidanceGyroNegativePreview.
  ///
  /// In en, this message translates to:
  /// **'Raw negative shows the film as it sits on the light table — orange base, no processing. Use this to check alignment and framing.'**
  String get guidanceGyroNegativePreview;

  /// No description provided for @guidanceGyroPositivePreview.
  ///
  /// In en, this message translates to:
  /// **'Positive preview inverts the orange mask live so the scan looks like a finished print. This is the default for judging exposure while auto-capture runs.'**
  String get guidanceGyroPositivePreview;

  /// No description provided for @gyroScanTitle.
  ///
  /// In en, this message translates to:
  /// **'GYRO SCAN'**
  String get gyroScanTitle;

  /// No description provided for @gyroFormat35mm.
  ///
  /// In en, this message translates to:
  /// **'35mm'**
  String get gyroFormat35mm;

  /// No description provided for @gyroFormat120.
  ///
  /// In en, this message translates to:
  /// **'120'**
  String get gyroFormat120;

  /// No description provided for @noRollsYet.
  ///
  /// In en, this message translates to:
  /// **'No rolls yet'**
  String get noRollsYet;

  /// No description provided for @errorLoadingRolls.
  ///
  /// In en, this message translates to:
  /// **'Error loading rolls'**
  String get errorLoadingRolls;

  /// No description provided for @errorLoadingGear.
  ///
  /// In en, this message translates to:
  /// **'Error loading gear'**
  String get errorLoadingGear;

  /// No description provided for @rollNotFound.
  ///
  /// In en, this message translates to:
  /// **'Roll not found'**
  String get rollNotFound;

  /// No description provided for @storageLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Storage limit reached. Please upgrade your plan.'**
  String get storageLimitReached;

  /// No description provided for @purchaseComplete.
  ///
  /// In en, this message translates to:
  /// **'Purchase complete!'**
  String get purchaseComplete;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase could not be completed.'**
  String get purchaseFailed;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete.'**
  String get syncComplete;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Please try again.'**
  String get syncFailed;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete.'**
  String get downloadComplete;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed.'**
  String get downloadFailed;

  /// No description provided for @connectDriveFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Drive in Storage settings first.'**
  String get connectDriveFirst;

  /// No description provided for @savedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully.'**
  String get savedSuccessfully;

  /// No description provided for @imageCount.
  ///
  /// In en, this message translates to:
  /// **'{current} / {max}'**
  String imageCount(int current, int max);

  /// No description provided for @updateRollStatus.
  ///
  /// In en, this message translates to:
  /// **'Update Roll Status'**
  String get updateRollStatus;

  /// No description provided for @statusDescShooting.
  ///
  /// In en, this message translates to:
  /// **'Film loaded — log shots while you shoot'**
  String get statusDescShooting;

  /// No description provided for @statusDescLab.
  ///
  /// In en, this message translates to:
  /// **'Film is with the lab — add Drive link or scan'**
  String get statusDescLab;

  /// No description provided for @statusDescScanned.
  ///
  /// In en, this message translates to:
  /// **'Scans are in — browse your gallery'**
  String get statusDescScanned;

  /// No description provided for @statusDescArchived.
  ///
  /// In en, this message translates to:
  /// **'Finished — hidden from the active list'**
  String get statusDescArchived;

  /// No description provided for @statusDescSyncing.
  ///
  /// In en, this message translates to:
  /// **'Downloading scans from Drive…'**
  String get statusDescSyncing;

  /// No description provided for @alreadyPassed.
  ///
  /// In en, this message translates to:
  /// **'Already passed'**
  String get alreadyPassed;

  /// No description provided for @lifecycleDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get lifecycleDone;

  /// No description provided for @lifecycleSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get lifecycleSync;

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get appTheme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @emptyGearTitle.
  ///
  /// In en, this message translates to:
  /// **'Your locker is empty'**
  String get emptyGearTitle;

  /// No description provided for @emptyGearSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first camera to start logging rolls.'**
  String get emptyGearSubtitle;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get locationPermissionDenied;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable.'**
  String get locationUnavailable;

  /// No description provided for @logExifTitle.
  ///
  /// In en, this message translates to:
  /// **'Log EXIF'**
  String get logExifTitle;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @driveUrl.
  ///
  /// In en, this message translates to:
  /// **'Drive URL'**
  String get driveUrl;

  /// No description provided for @noPhotosYet.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get noPhotosYet;

  /// No description provided for @noShotsLogged.
  ///
  /// In en, this message translates to:
  /// **'No shots logged yet'**
  String get noShotsLogged;

  /// No description provided for @selectRoll.
  ///
  /// In en, this message translates to:
  /// **'Select Roll'**
  String get selectRoll;

  /// No description provided for @meterEv.
  ///
  /// In en, this message translates to:
  /// **'EV'**
  String get meterEv;

  /// No description provided for @meterIso.
  ///
  /// In en, this message translates to:
  /// **'ISO'**
  String get meterIso;

  /// No description provided for @meterAperture.
  ///
  /// In en, this message translates to:
  /// **'Aperture'**
  String get meterAperture;

  /// No description provided for @meterShutter.
  ///
  /// In en, this message translates to:
  /// **'Shutter'**
  String get meterShutter;

  /// No description provided for @meterCompensation.
  ///
  /// In en, this message translates to:
  /// **'Compensation'**
  String get meterCompensation;

  /// No description provided for @meterSpot.
  ///
  /// In en, this message translates to:
  /// **'Spot'**
  String get meterSpot;

  /// No description provided for @meterPriorityAperture.
  ///
  /// In en, this message translates to:
  /// **'Aperture Priority'**
  String get meterPriorityAperture;

  /// No description provided for @meterPriorityShutter.
  ///
  /// In en, this message translates to:
  /// **'Shutter Priority'**
  String get meterPriorityShutter;

  /// No description provided for @meterNoRolls.
  ///
  /// In en, this message translates to:
  /// **'No active rolls'**
  String get meterNoRolls;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get currentPlan;

  /// No description provided for @perYear.
  ///
  /// In en, this message translates to:
  /// **'per year'**
  String get perYear;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'per month'**
  String get perMonth;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription;

  /// No description provided for @productsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Products unavailable'**
  String get productsUnavailable;

  /// No description provided for @checkingStore.
  ///
  /// In en, this message translates to:
  /// **'Checking store…'**
  String get checkingStore;

  /// No description provided for @legalAppleEula.
  ///
  /// In en, this message translates to:
  /// **'Apple Standard EULA'**
  String get legalAppleEula;

  /// No description provided for @legalAppleEulaDescription.
  ///
  /// In en, this message translates to:
  /// **'Licensed applications are also subject to Apple\'s Standard EULA.'**
  String get legalAppleEulaDescription;

  /// No description provided for @viewAppleEula.
  ///
  /// In en, this message translates to:
  /// **'View Apple Standard EULA'**
  String get viewAppleEula;

  /// No description provided for @chooseYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Plan'**
  String get chooseYourPlan;

  /// No description provided for @paywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pro adds AgXel Cloud Storage and the professional light meter'**
  String get paywallSubtitle;

  /// No description provided for @monthlyBilling.
  ///
  /// In en, this message translates to:
  /// **'Monthly billing'**
  String get monthlyBilling;

  /// No description provided for @annualBilling.
  ///
  /// In en, this message translates to:
  /// **'Annual billing'**
  String get annualBilling;

  /// No description provided for @welcomeToHalidePro.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AgXel! Your plan is now active.'**
  String get welcomeToHalidePro;

  /// No description provided for @purchaseFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Purchase could not be completed. Please try again.'**
  String get purchaseFailedRetry;

  /// No description provided for @unableToLoadSubscription.
  ///
  /// In en, this message translates to:
  /// **'Unable to load subscription options. Please try again.'**
  String get unableToLoadSubscription;

  /// No description provided for @storeNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Store is not available.'**
  String get storeNotAvailable;

  /// No description provided for @restoreAppleIdHint.
  ///
  /// In en, this message translates to:
  /// **'You may be asked to sign in with your Apple ID to restore purchases.'**
  String get restoreAppleIdHint;

  /// No description provided for @startFreeTrial.
  ///
  /// In en, this message translates to:
  /// **'Start free trial'**
  String get startFreeTrial;

  /// No description provided for @getHalidePro.
  ///
  /// In en, this message translates to:
  /// **'Get AgXel'**
  String get getHalidePro;

  /// No description provided for @save20Percent.
  ///
  /// In en, this message translates to:
  /// **'SAVE 20%'**
  String get save20Percent;

  /// No description provided for @forever.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get forever;

  /// No description provided for @freeTrialWhereEligible.
  ///
  /// In en, this message translates to:
  /// **'Free trial where eligible'**
  String get freeTrialWhereEligible;

  /// No description provided for @planNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This plan is not available yet. Please try another option.'**
  String get planNotAvailable;

  /// No description provided for @subscriptionDisclosure.
  ///
  /// In en, this message translates to:
  /// **'A {price} subscription will be applied to your iTunes account on confirmation. Subscriptions will automatically renew unless canceled within 24-hours before the end of the current period. Manage anytime in iTunes settings. Any unused portion of a free trial will be forfeited if you purchase a subscription.'**
  String subscriptionDisclosure(String price);

  /// No description provided for @perYearShort.
  ///
  /// In en, this message translates to:
  /// **'/yr'**
  String get perYearShort;

  /// No description provided for @perMonthShort.
  ///
  /// In en, this message translates to:
  /// **'/mo'**
  String get perMonthShort;

  /// No description provided for @storageStrategyTitle.
  ///
  /// In en, this message translates to:
  /// **'STORAGE STRATEGY'**
  String get storageStrategyTitle;

  /// No description provided for @systemCloudQuota.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM CLOUD QUOTA'**
  String get systemCloudQuota;

  /// No description provided for @storageUsedOf.
  ///
  /// In en, this message translates to:
  /// **'{used} used of {cap}'**
  String storageUsedOf(String used, String cap);

  /// No description provided for @addonStorageFromPurchases.
  ///
  /// In en, this message translates to:
  /// **'+{amount} from add-on purchases'**
  String addonStorageFromPurchases(String amount);

  /// No description provided for @systemCloudRequiresPro.
  ///
  /// In en, this message translates to:
  /// **'System Cloud requires Pro features. Professional sync is limited to individual cloud accounts.'**
  String get systemCloudRequiresPro;

  /// No description provided for @upgradeProStorageHint.
  ///
  /// In en, this message translates to:
  /// **'Upgrade above to get Pro storage. Each account includes 5–10 GB by default.'**
  String get upgradeProStorageHint;

  /// No description provided for @storageManagement.
  ///
  /// In en, this message translates to:
  /// **'Storage Management'**
  String get storageManagement;

  /// No description provided for @manageStorageAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your cloud and local storage accounts'**
  String get manageStorageAccountsSubtitle;

  /// No description provided for @systemCloudAfterUpgradeHint.
  ///
  /// In en, this message translates to:
  /// **'Upgrade above to get Pro storage. After upgrading, your account will appear here.'**
  String get systemCloudAfterUpgradeHint;

  /// No description provided for @primaryBadge.
  ///
  /// In en, this message translates to:
  /// **'PRIMARY'**
  String get primaryBadge;

  /// No description provided for @setAsPrimary.
  ///
  /// In en, this message translates to:
  /// **'Set as Primary'**
  String get setAsPrimary;

  /// No description provided for @primaryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primaryTooltip;

  /// No description provided for @storageUsage.
  ///
  /// In en, this message translates to:
  /// **'STORAGE USAGE'**
  String get storageUsage;

  /// No description provided for @addMoreStorage.
  ///
  /// In en, this message translates to:
  /// **'ADD MORE STORAGE'**
  String get addMoreStorage;

  /// No description provided for @tierBadgeByo.
  ///
  /// In en, this message translates to:
  /// **'BYO'**
  String get tierBadgeByo;

  /// No description provided for @cloudProvidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud providers'**
  String get cloudProvidersTitle;

  /// No description provided for @cloudProvidersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your own cloud or network storage. Tap a provider to connect.'**
  String get cloudProvidersSubtitle;

  /// No description provided for @connectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Connected'**
  String connectedCount(int count);

  /// No description provided for @addAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addAction;

  /// No description provided for @archiveStorageDescription.
  ///
  /// In en, this message translates to:
  /// **'Backup gear and rolls to this account.'**
  String get archiveStorageDescription;

  /// No description provided for @labScanSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync film scans via Drive URLs.'**
  String get labScanSyncDescription;

  /// No description provided for @priBadge.
  ///
  /// In en, this message translates to:
  /// **'PRI'**
  String get priBadge;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get fillAllFields;

  /// No description provided for @nasConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'NAS CONFIGURATION'**
  String get nasConfigurationTitle;

  /// No description provided for @nasConfigSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your NAS details to set up storage'**
  String get nasConfigSubtitle;

  /// No description provided for @googleDrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get googleDrive;

  /// No description provided for @nasProvider.
  ///
  /// In en, this message translates to:
  /// **'NAS'**
  String get nasProvider;

  /// No description provided for @addStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'ADD STORAGE'**
  String get addStorageTitle;

  /// No description provided for @storagePurchaseIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick how much extra cloud space you need. Prices are shown in your local currency. You can buy the same size more than once — each purchase adds to your total.'**
  String get storagePurchaseIntro;

  /// No description provided for @storagePurchaseFooter.
  ///
  /// In en, this message translates to:
  /// **'Each pack adds to your vault total — you can buy the same size again anytime. Payment uses the method on this device; extra space usually appears within a few moments.'**
  String get storagePurchaseFooter;

  /// No description provided for @buyTier.
  ///
  /// In en, this message translates to:
  /// **'Buy {tier} — {price}'**
  String buyTier(String tier, String price);

  /// No description provided for @buyTierNoPrice.
  ///
  /// In en, this message translates to:
  /// **'BUY {tier}'**
  String buyTierNoPrice(String tier);

  /// No description provided for @refreshPrices.
  ///
  /// In en, this message translates to:
  /// **'Refresh prices'**
  String get refreshPrices;

  /// No description provided for @storageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Storage updated. Your new quota is active.'**
  String get storageUpdated;

  /// No description provided for @purchaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled.'**
  String get purchaseCancelled;

  /// No description provided for @couldNotRefreshPrices.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t refresh prices. Please try again in a moment.'**
  String get couldNotRefreshPrices;

  /// No description provided for @couldNotLoadStorageOptions.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load storage options. Check your connection and try again.'**
  String get couldNotLoadStorageOptions;

  /// No description provided for @stackable.
  ///
  /// In en, this message translates to:
  /// **'STACKABLE'**
  String get stackable;

  /// No description provided for @connectGoogleDriveTitle.
  ///
  /// In en, this message translates to:
  /// **'CONNECT GOOGLE DRIVE'**
  String get connectGoogleDriveTitle;

  /// No description provided for @connectGoogleDriveBody.
  ///
  /// In en, this message translates to:
  /// **'To import photos from a shared Drive link, AgXel needs access to your Google account (read-only). Connect once in Settings, or tap Connect below.'**
  String get connectGoogleDriveBody;

  /// No description provided for @connectGoogleUpper.
  ///
  /// In en, this message translates to:
  /// **'CONNECT GOOGLE'**
  String get connectGoogleUpper;

  /// No description provided for @cancelUpper.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancelUpper;

  /// No description provided for @googleDriveConnected.
  ///
  /// In en, this message translates to:
  /// **'Google Drive connected.'**
  String get googleDriveConnected;

  /// No description provided for @couldNotConnectGoogleDrive.
  ///
  /// In en, this message translates to:
  /// **'Could not connect Google Drive.'**
  String get couldNotConnectGoogleDrive;

  /// No description provided for @downloadFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download folder. Check Drive access and try again.'**
  String get downloadFolderFailed;

  /// No description provided for @couldNotRetrievePhotos.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t retrieve photos. Please check your Drive link.'**
  String get couldNotRetrievePhotos;

  /// No description provided for @fetchPhotosError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while fetching photos.'**
  String get fetchPhotosError;

  /// No description provided for @privacyLastUpdatedDate.
  ///
  /// In en, this message translates to:
  /// **'April 6, 2026'**
  String get privacyLastUpdatedDate;

  /// No description provided for @termsLastUpdatedDate.
  ///
  /// In en, this message translates to:
  /// **'April 20, 2026'**
  String get termsLastUpdatedDate;

  /// No description provided for @joinHalide.
  ///
  /// In en, this message translates to:
  /// **'Join AgXel'**
  String get joinHalide;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capture your analog journey'**
  String get registerSubtitle;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @signInTermsFooter.
  ///
  /// In en, this message translates to:
  /// **'By signing in, you agree to our terms and conditions.'**
  String get signInTermsFooter;

  /// No description provided for @displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your display name'**
  String get displayNameHint;

  /// No description provided for @nicknameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Film Shooter'**
  String get nicknameHint;

  /// No description provided for @bioHint.
  ///
  /// In en, this message translates to:
  /// **'A short bio for your profile'**
  String get bioHint;

  /// No description provided for @tapToUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload photo'**
  String get tapToUploadPhoto;

  /// No description provided for @photoSavedTapSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Photo saved on this device. Tap \"Save changes\" to update profile.'**
  String get photoSavedTapSaveChanges;

  /// No description provided for @couldNotSavePhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not save photo. Please try again.'**
  String get couldNotSavePhoto;

  /// No description provided for @emailGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi AgXel team,'**
  String get emailGreeting;

  /// No description provided for @supportEmailBodyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'(Describe what happened / what you need)'**
  String get supportEmailBodyPlaceholder;

  /// No description provided for @feedbackEmailBodyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'(Tell us what you loved / what you want improved)'**
  String get feedbackEmailBodyPlaceholder;

  /// No description provided for @emailBodySeparator.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get emailBodySeparator;

  /// No description provided for @emailAccountLine.
  ///
  /// In en, this message translates to:
  /// **'Account: {email}'**
  String emailAccountLine(String email);

  /// No description provided for @emailUserIdLine.
  ///
  /// In en, this message translates to:
  /// **'User ID: {uid}'**
  String emailUserIdLine(String uid);

  /// No description provided for @moveToArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to archive?'**
  String get moveToArchiveTitle;

  /// No description provided for @moveToArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'This roll will leave your active list. You can still open it anytime from the Archive tab on Home.'**
  String get moveToArchiveBody;

  /// No description provided for @archiveAction.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveAction;

  /// No description provided for @uploadedImages.
  ///
  /// In en, this message translates to:
  /// **'UPLOADED IMAGES'**
  String get uploadedImages;

  /// No description provided for @rollInfoSection.
  ///
  /// In en, this message translates to:
  /// **'ROLL INFO'**
  String get rollInfoSection;

  /// No description provided for @rollInfoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Roll info updated!'**
  String get rollInfoUpdated;

  /// No description provided for @couldNotUpdateRollInfo.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t update your roll info.'**
  String get couldNotUpdateRollInfo;

  /// No description provided for @atLabSection.
  ///
  /// In en, this message translates to:
  /// **'AT LAB'**
  String get atLabSection;

  /// No description provided for @chooseLabImportMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose how to bring scans into this roll.'**
  String get chooseLabImportMethod;

  /// No description provided for @nextStepLabel.
  ///
  /// In en, this message translates to:
  /// **'NEXT: {action}'**
  String nextStepLabel(String action);

  /// No description provided for @sendToLab.
  ///
  /// In en, this message translates to:
  /// **'SEND TO LAB'**
  String get sendToLab;

  /// No description provided for @markScanned.
  ///
  /// In en, this message translates to:
  /// **'MARK SCANNED'**
  String get markScanned;

  /// No description provided for @scansComplete.
  ///
  /// In en, this message translates to:
  /// **'Scans complete'**
  String get scansComplete;

  /// No description provided for @moveToArchiveLink.
  ///
  /// In en, this message translates to:
  /// **'Move to archive'**
  String get moveToArchiveLink;

  /// No description provided for @technicalDataCount.
  ///
  /// In en, this message translates to:
  /// **'TECHNICAL DATA ({count})'**
  String technicalDataCount(int count);

  /// No description provided for @noTechnicalLogs.
  ///
  /// In en, this message translates to:
  /// **'No technical logs recorded for this roll.'**
  String get noTechnicalLogs;

  /// No description provided for @alignmentCalibration.
  ///
  /// In en, this message translates to:
  /// **'ALIGNMENT CALIBRATION'**
  String get alignmentCalibration;

  /// No description provided for @framesOffset.
  ///
  /// In en, this message translates to:
  /// **'{count} frames offset'**
  String framesOffset(int count);

  /// No description provided for @alignmentCalibrationHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust if your scans start with blank loading frames.'**
  String get alignmentCalibrationHint;

  /// No description provided for @importOptions.
  ///
  /// In en, this message translates to:
  /// **'IMPORT OPTIONS'**
  String get importOptions;

  /// No description provided for @driveUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Shared Drive URL (folder or ZIP)'**
  String get driveUrlLabel;

  /// No description provided for @fetchFiles.
  ///
  /// In en, this message translates to:
  /// **'Fetch Files'**
  String get fetchFiles;

  /// No description provided for @foundFilesAtLeaf.
  ///
  /// In en, this message translates to:
  /// **'Found {count} file(s) at leaf level.'**
  String foundFilesAtLeaf(int count);

  /// No description provided for @pasteDriveLinkError.
  ///
  /// In en, this message translates to:
  /// **'Paste a shared Google Drive folder or ZIP link.'**
  String get pasteDriveLinkError;

  /// No description provided for @signInToSyncDrive.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync from Drive.'**
  String get signInToSyncDrive;

  /// No description provided for @driveLinkSavedSyncing.
  ///
  /// In en, this message translates to:
  /// **'Drive link saved — syncing…'**
  String get driveLinkSavedSyncing;

  /// No description provided for @syncStartedInBackground.
  ///
  /// In en, this message translates to:
  /// **'Sync started in background.'**
  String get syncStartedInBackground;

  /// No description provided for @importedPhotosFromDrive.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} photo(s) from Drive.'**
  String importedPhotosFromDrive(String count);

  /// No description provided for @couldNotSyncFromDrive.
  ///
  /// In en, this message translates to:
  /// **'Could not sync from Drive.'**
  String get couldNotSyncFromDrive;

  /// No description provided for @addedLocalImageReferences.
  ///
  /// In en, this message translates to:
  /// **'Added local image references (Free tier).'**
  String get addedLocalImageReferences;

  /// No description provided for @couldNotAddImageReferences.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add image references. Please try again.'**
  String get couldNotAddImageReferences;

  /// No description provided for @successfullyUploadedCount.
  ///
  /// In en, this message translates to:
  /// **'Successfully uploaded {count} image(s)!'**
  String successfullyUploadedCount(int count);

  /// No description provided for @pleasePasteDriveUrl.
  ///
  /// In en, this message translates to:
  /// **'Please paste a shared Drive URL (folder or ZIP).'**
  String get pleasePasteDriveUrl;

  /// No description provided for @mustSignInDriveSync.
  ///
  /// In en, this message translates to:
  /// **'You must be signed in to sync from Drive.'**
  String get mustSignInDriveSync;

  /// No description provided for @tryingCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Trying cloud sync…'**
  String get tryingCloudSync;

  /// No description provided for @zipDetectedSyncing.
  ///
  /// In en, this message translates to:
  /// **'ZIP detected. Extracting and syncing photos...'**
  String get zipDetectedSyncing;

  /// No description provided for @foundPhotosImporting.
  ///
  /// In en, this message translates to:
  /// **'Found {count} photos. Importing into roll...'**
  String foundPhotosImporting(int count);

  /// No description provided for @unexpectedDriveResponse.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response from Drive.'**
  String get unexpectedDriveResponse;

  /// No description provided for @backendErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Backend error{status}: {detail}'**
  String backendErrorDetail(String status, String detail);

  /// No description provided for @syncFailedVerifyDrive.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Please verify your Drive link and permissions.'**
  String get syncFailedVerifyDrive;

  /// No description provided for @somethingWrongDuringSync.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong during sync.'**
  String get somethingWrongDuringSync;

  /// No description provided for @successfullyImportedNewPhotos.
  ///
  /// In en, this message translates to:
  /// **'Successfully imported {count} new photos!'**
  String successfullyImportedNewPhotos(String count);

  /// No description provided for @couldNotImportFolderDevice.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t import folder on device. Check Drive access.'**
  String get couldNotImportFolderDevice;

  /// No description provided for @continueGyroScan.
  ///
  /// In en, this message translates to:
  /// **'Continue gyro scan'**
  String get continueGyroScan;

  /// No description provided for @continueGyroScanHint.
  ///
  /// In en, this message translates to:
  /// **'Add more frames, then tap Finish scanning when done.'**
  String get continueGyroScanHint;

  /// No description provided for @premiumGyroScanResumeHint.
  ///
  /// In en, this message translates to:
  /// **'Premium — scan negatives with the gyro HUD.'**
  String get premiumGyroScanResumeHint;

  /// No description provided for @premiumGyroScanFeatureHint.
  ///
  /// In en, this message translates to:
  /// **'Premium feature — upgrade to scan with the gyro HUD.'**
  String get premiumGyroScanFeatureHint;

  /// No description provided for @precisionMeterTitle.
  ///
  /// In en, this message translates to:
  /// **'PRECISION METER'**
  String get precisionMeterTitle;

  /// No description provided for @collapseExposurePanel.
  ///
  /// In en, this message translates to:
  /// **'Collapse exposure panel'**
  String get collapseExposurePanel;

  /// No description provided for @expandExposurePanel.
  ///
  /// In en, this message translates to:
  /// **'Expand exposure panel'**
  String get expandExposurePanel;

  /// No description provided for @unlockExposure.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK'**
  String get unlockExposure;

  /// No description provided for @lockExposureUpper.
  ///
  /// In en, this message translates to:
  /// **'LOCK EXPOSURE'**
  String get lockExposureUpper;

  /// No description provided for @lockedStatus.
  ///
  /// In en, this message translates to:
  /// **'LOCKED'**
  String get lockedStatus;

  /// No description provided for @stableStatus.
  ///
  /// In en, this message translates to:
  /// **'STABLE'**
  String get stableStatus;

  /// No description provided for @meteringStatus.
  ///
  /// In en, this message translates to:
  /// **'METERING…'**
  String get meteringStatus;

  /// No description provided for @multiSpotPinStatus.
  ///
  /// In en, this message translates to:
  /// **'MULTI-SPOT · {count} PIN{plural}'**
  String multiSpotPinStatus(int count, String plural);

  /// No description provided for @multiSpotTapAddPins.
  ///
  /// In en, this message translates to:
  /// **'MULTI-SPOT — TAP TO ADD PINS'**
  String get multiSpotTapAddPins;

  /// No description provided for @pinsLabel.
  ///
  /// In en, this message translates to:
  /// **'PINS'**
  String get pinsLabel;

  /// No description provided for @pinCountShort.
  ///
  /// In en, this message translates to:
  /// **'{count} pin{plural}'**
  String pinCountShort(int count, String plural);

  /// No description provided for @logToRollArrow.
  ///
  /// In en, this message translates to:
  /// **'LOG TO ROLL →'**
  String get logToRollArrow;

  /// No description provided for @logMeterReadingTitle.
  ///
  /// In en, this message translates to:
  /// **'LOG METER READING'**
  String get logMeterReadingTitle;

  /// No description provided for @logMeterReadingHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a roll in Shooting status. Saves aperture, shutter, and meter details to the shot log.'**
  String get logMeterReadingHint;

  /// No description provided for @couldNotLoadRolls.
  ///
  /// In en, this message translates to:
  /// **'Could not load rolls.'**
  String get couldNotLoadRolls;

  /// No description provided for @noRollsInShooting.
  ///
  /// In en, this message translates to:
  /// **'No rolls in Shooting status.\nStart a roll from the archive.'**
  String get noRollsInShooting;

  /// No description provided for @meterReadingLogged.
  ///
  /// In en, this message translates to:
  /// **'Meter reading logged'**
  String get meterReadingLogged;

  /// No description provided for @couldNotLogReading.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t log reading. Try again.'**
  String get couldNotLogReading;

  /// No description provided for @untitledRoll.
  ///
  /// In en, this message translates to:
  /// **'Untitled roll'**
  String get untitledRoll;

  /// No description provided for @noCamera.
  ///
  /// In en, this message translates to:
  /// **'No camera'**
  String get noCamera;

  /// No description provided for @proFeatureBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO FEATURE'**
  String get proFeatureBadge;

  /// No description provided for @precisionMeterProTitle.
  ///
  /// In en, this message translates to:
  /// **'Precision light metering is included with AgXel.'**
  String get precisionMeterProTitle;

  /// No description provided for @precisionMeterProSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to unlock spot metering, EV compensation, manual exposure, and logging to your rolls.'**
  String get precisionMeterProSubtitle;

  /// No description provided for @viewPlans.
  ///
  /// In en, this message translates to:
  /// **'VIEW PLANS'**
  String get viewPlans;

  /// No description provided for @logMeterReadingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Log meter reading to roll'**
  String get logMeterReadingTooltip;

  /// No description provided for @aperturePickerHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to set f-stop. Tap the meter circle to return to aperture priority.'**
  String get aperturePickerHint;

  /// No description provided for @shutterPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Selecting a shutter speed switches to Shutter Priority.\nTap the meter circle to return to Aperture Priority.'**
  String get shutterPickerHint;

  /// No description provided for @evCompensationValue.
  ///
  /// In en, this message translates to:
  /// **'Compensation: {value}'**
  String evCompensationValue(String value);

  /// No description provided for @driveUrlChip.
  ///
  /// In en, this message translates to:
  /// **'Drive URL'**
  String get driveUrlChip;

  /// No description provided for @nicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'NICKNAME'**
  String get nicknameLabel;

  /// No description provided for @brandLabel.
  ///
  /// In en, this message translates to:
  /// **'BRAND'**
  String get brandLabel;

  /// No description provided for @modelLabel.
  ///
  /// In en, this message translates to:
  /// **'MODEL'**
  String get modelLabel;

  /// No description provided for @gallerySection.
  ///
  /// In en, this message translates to:
  /// **'GALLERY'**
  String get gallerySection;

  /// No description provided for @noGearImagesYet.
  ///
  /// In en, this message translates to:
  /// **'No gear images yet'**
  String get noGearImagesYet;

  /// No description provided for @opticsSection.
  ///
  /// In en, this message translates to:
  /// **'OPTICS'**
  String get opticsSection;

  /// No description provided for @mountAction.
  ///
  /// In en, this message translates to:
  /// **'MOUNT'**
  String get mountAction;

  /// No description provided for @noOpticsMounted.
  ///
  /// In en, this message translates to:
  /// **'No optics mounted'**
  String get noOpticsMounted;

  /// No description provided for @createNewLensUpper.
  ///
  /// In en, this message translates to:
  /// **'CREATE NEW LENS'**
  String get createNewLensUpper;

  /// No description provided for @brandAndModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Brand and model are required.'**
  String get brandAndModelRequired;

  /// No description provided for @couldNotCreateLens.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t create the lens. Please try again.'**
  String get couldNotCreateLens;

  /// No description provided for @signInSaveGearPhotos.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save gear photos.'**
  String get signInSaveGearPhotos;

  /// No description provided for @uploadFailedCheckConnection.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Check connection or storage.'**
  String get uploadFailedCheckConnection;

  /// No description provided for @gearNotFoundRefresh.
  ///
  /// In en, this message translates to:
  /// **'Gear not found for this account. Open the locker, pull to refresh, then try again.'**
  String get gearNotFoundRefresh;

  /// No description provided for @storageLimitFreeSpace.
  ///
  /// In en, this message translates to:
  /// **'Storage limit reached. Free some space or upgrade your plan.'**
  String get storageLimitFreeSpace;

  /// No description provided for @uploadRejectedFormat.
  ///
  /// In en, this message translates to:
  /// **'Upload rejected. Check file size (max 15 MB) and format.'**
  String get uploadRejectedFormat;

  /// No description provided for @brandFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Brand (e.g. Leica)'**
  String get brandFieldHint;

  /// No description provided for @modelFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Model (e.g. 35mm f/2 Summicron)'**
  String get modelFieldHint;

  /// No description provided for @serialNumberOptional.
  ///
  /// In en, this message translates to:
  /// **'Serial Number (Optional)'**
  String get serialNumberOptional;

  /// No description provided for @nicknameFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Nickname (e.g. My Favorite)'**
  String get nicknameFieldHint;

  /// No description provided for @optionalField.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optionalField;

  /// No description provided for @formatLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get formatLabel;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// No description provided for @couldNotLoadAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Could not load analytics'**
  String get couldNotLoadAnalytics;

  /// No description provided for @noShotsLoggedYear.
  ///
  /// In en, this message translates to:
  /// **'No shots logged in the last year yet. Log frames from the meter or roll detail to start building your exposure map.'**
  String get noShotsLoggedYear;

  /// No description provided for @shotsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} shots'**
  String shotsCount(int count);

  /// No description provided for @last365Days.
  ///
  /// In en, this message translates to:
  /// **'Last 365 days'**
  String get last365Days;

  /// No description provided for @periodRange.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String periodRange(String start, String end);

  /// No description provided for @lightingHabit.
  ///
  /// In en, this message translates to:
  /// **'LIGHTING HABIT'**
  String get lightingHabit;

  /// No description provided for @goldenHour.
  ///
  /// In en, this message translates to:
  /// **'Golden Hour'**
  String get goldenHour;

  /// No description provided for @goldenHourBiasStrong.
  ///
  /// In en, this message translates to:
  /// **'You have a strong golden hour bias — a large share of your sessions fall between 4 PM and 6 PM. Your exposures often score highest during this window.'**
  String get goldenHourBiasStrong;

  /// No description provided for @goldenHourBiasModerate.
  ///
  /// In en, this message translates to:
  /// **'Golden hour makes up a meaningful part of your shooting rhythm. Consider leaning into dawn sessions to broaden your tonal range.'**
  String get goldenHourBiasModerate;

  /// No description provided for @goldenHourBiasLow.
  ///
  /// In en, this message translates to:
  /// **'Most of your sessions happen outside golden hour. You may prefer consistent midday light or indoor setups.'**
  String get goldenHourBiasLow;

  /// No description provided for @goldenHourShotsSummary.
  ///
  /// In en, this message translates to:
  /// **'{golden} of {total} shots between 4–6 PM local time'**
  String goldenHourShotsSummary(int golden, int total);

  /// No description provided for @refreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// No description provided for @daysUnit.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get daysUnit;

  /// No description provided for @periodDaysOf.
  ///
  /// In en, this message translates to:
  /// **'/ {days}'**
  String periodDaysOf(int days);

  /// No description provided for @gridOn.
  ///
  /// In en, this message translates to:
  /// **'Grid: On'**
  String get gridOn;

  /// No description provided for @gridOff.
  ///
  /// In en, this message translates to:
  /// **'Grid: Off'**
  String get gridOff;

  /// No description provided for @kelvinValue.
  ///
  /// In en, this message translates to:
  /// **'{kelvin} K'**
  String kelvinValue(int kelvin);

  /// No description provided for @guidanceGotItUpper.
  ///
  /// In en, this message translates to:
  /// **'GOT IT'**
  String get guidanceGotItUpper;

  /// No description provided for @sessionFullRoll.
  ///
  /// In en, this message translates to:
  /// **'Full roll'**
  String get sessionFullRoll;

  /// No description provided for @sessionHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get sessionHeavy;

  /// No description provided for @sessionActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sessionActive;

  /// No description provided for @sessionLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get sessionLight;

  /// No description provided for @sessionNoShots.
  ///
  /// In en, this message translates to:
  /// **'No shots'**
  String get sessionNoShots;

  /// No description provided for @heatLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get heatLess;

  /// No description provided for @heatMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get heatMore;

  /// No description provided for @noExposuresRecorded.
  ///
  /// In en, this message translates to:
  /// **'No exposures recorded'**
  String get noExposuresRecorded;

  /// No description provided for @exposureCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exposure} other{{count} exposures}}'**
  String exposureCount(int count);

  /// No description provided for @tapCellToInspect.
  ///
  /// In en, this message translates to:
  /// **'Tap any cell to inspect that day'**
  String get tapCellToInspect;

  /// No description provided for @halideDialogBarrier.
  ///
  /// In en, this message translates to:
  /// **'AgXel dialog barrier'**
  String get halideDialogBarrier;

  /// No description provided for @halideBottomSheetBarrier.
  ///
  /// In en, this message translates to:
  /// **'AgXel bottom sheet barrier'**
  String get halideBottomSheetBarrier;

  /// No description provided for @archivedCannotModify.
  ///
  /// In en, this message translates to:
  /// **'Images are archived and can no longer be modified.'**
  String get archivedCannotModify;

  /// No description provided for @fileMissed.
  ///
  /// In en, this message translates to:
  /// **'File missed'**
  String get fileMissed;

  /// No description provided for @uploadAllCount.
  ///
  /// In en, this message translates to:
  /// **'Upload All ({count})'**
  String uploadAllCount(int count);

  /// No description provided for @uploadedSuccessfullyCount.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {count} image(s) successfully.'**
  String uploadedSuccessfullyCount(int count);

  /// No description provided for @maxImagesAllowed.
  ///
  /// In en, this message translates to:
  /// **'Maximum of {max} images allowed per gear item.'**
  String maxImagesAllowed(int max);

  /// No description provided for @onlyAddedRemainingImages.
  ///
  /// In en, this message translates to:
  /// **'Only added {count} images to stay within the limit of {max}.'**
  String onlyAddedRemainingImages(int count, int max);

  /// No description provided for @signInUploadGearPhotos.
  ///
  /// In en, this message translates to:
  /// **'Sign in to upload gear photos.'**
  String get signInUploadGearPhotos;

  /// No description provided for @successfullyUploadedGearImages.
  ///
  /// In en, this message translates to:
  /// **'Successfully uploaded {count} image(s)!'**
  String successfullyUploadedGearImages(int count);

  /// No description provided for @gearReady.
  ///
  /// In en, this message translates to:
  /// **'Your {gearType} is ready!'**
  String gearReady(String gearType);

  /// No description provided for @couldNotAddGear.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t add your {gearType}. Please try again.'**
  String couldNotAddGear(String gearType);

  /// No description provided for @addGearTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'ADD {gearType}'**
  String addGearTypeTitle(String gearType);

  /// No description provided for @saveGearType.
  ///
  /// In en, this message translates to:
  /// **'SAVE {gearType}'**
  String saveGearType(String gearType);

  /// No description provided for @clearPinsCount.
  ///
  /// In en, this message translates to:
  /// **'Clear Pins ({count})'**
  String clearPinsCount(int count);

  /// No description provided for @zoneOverlayTitle.
  ///
  /// In en, this message translates to:
  /// **'ZONE OVERLAY'**
  String get zoneOverlayTitle;

  /// No description provided for @zoneOverlayIntro.
  ///
  /// In en, this message translates to:
  /// **'Colors show how bright each part of the scene is compared to your EV target. Green (Zone V) is middle gray at that exposure.'**
  String get zoneOverlayIntro;

  /// No description provided for @zoneOverlayTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: Lock exposure, then scan the frame — keep important tones out of deep violet (Zone 0) and bright red (Zone X) unless you want blocked shadows or blown highlights.'**
  String get zoneOverlayTip;

  /// No description provided for @zone0Meaning.
  ///
  /// In en, this message translates to:
  /// **'Pure black — no detail'**
  String get zone0Meaning;

  /// No description provided for @zoneIMeaning.
  ///
  /// In en, this message translates to:
  /// **'Very deep shadow'**
  String get zoneIMeaning;

  /// No description provided for @zoneIIMeaning.
  ///
  /// In en, this message translates to:
  /// **'Deep shadow, slight texture'**
  String get zoneIIMeaning;

  /// No description provided for @zoneIIIMeaning.
  ///
  /// In en, this message translates to:
  /// **'Dark tones with clear texture'**
  String get zoneIIIMeaning;

  /// No description provided for @zoneIVMeaning.
  ///
  /// In en, this message translates to:
  /// **'Dark foliage, shadow skin'**
  String get zoneIVMeaning;

  /// No description provided for @zoneVMeaning.
  ///
  /// In en, this message translates to:
  /// **'Middle gray — your EV target'**
  String get zoneVMeaning;

  /// No description provided for @zoneVIMeaning.
  ///
  /// In en, this message translates to:
  /// **'Light skin, light stone'**
  String get zoneVIMeaning;

  /// No description provided for @zoneVIIMeaning.
  ///
  /// In en, this message translates to:
  /// **'Very light skin, bright snow'**
  String get zoneVIIMeaning;

  /// No description provided for @zoneVIIIMeaning.
  ///
  /// In en, this message translates to:
  /// **'Bright snow, white objects'**
  String get zoneVIIIMeaning;

  /// No description provided for @zoneIXMeaning.
  ///
  /// In en, this message translates to:
  /// **'Near paper white'**
  String get zoneIXMeaning;

  /// No description provided for @zoneXMeaning.
  ///
  /// In en, this message translates to:
  /// **'Specular highlights, pure white'**
  String get zoneXMeaning;

  /// No description provided for @zone0Short.
  ///
  /// In en, this message translates to:
  /// **'Zone 0'**
  String get zone0Short;

  /// No description provided for @zoneVShort.
  ///
  /// In en, this message translates to:
  /// **'Zone V'**
  String get zoneVShort;

  /// No description provided for @zoneXShort.
  ///
  /// In en, this message translates to:
  /// **'Zone X'**
  String get zoneXShort;

  /// No description provided for @scanningCompleteFrames.
  ///
  /// In en, this message translates to:
  /// **'Scanning complete — {count} frame(s)'**
  String scanningCompleteFrames(int count);

  /// No description provided for @couldNotFinishScanning.
  ///
  /// In en, this message translates to:
  /// **'Could not finish scanning. Try again.'**
  String get couldNotFinishScanning;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get processing;

  /// No description provided for @frameNumber.
  ///
  /// In en, this message translates to:
  /// **'Frame {number}'**
  String frameNumber(String number);

  /// No description provided for @reviewingFrameTapLive.
  ///
  /// In en, this message translates to:
  /// **'Reviewing frame {number} — tap to scan live'**
  String reviewingFrameTapLive(String number);

  /// No description provided for @pauseAndReturn.
  ///
  /// In en, this message translates to:
  /// **'Pause and return'**
  String get pauseAndReturn;

  /// No description provided for @filmFormatSection.
  ///
  /// In en, this message translates to:
  /// **'FILM FORMAT'**
  String get filmFormatSection;

  /// No description provided for @negativeRawTooltip.
  ///
  /// In en, this message translates to:
  /// **'Negative (raw)'**
  String get negativeRawTooltip;

  /// No description provided for @positiveInvertedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Positive (inverted)'**
  String get positiveInvertedTooltip;

  /// No description provided for @captureFramesToFinish.
  ///
  /// In en, this message translates to:
  /// **'Capture frames to finish'**
  String get captureFramesToFinish;

  /// No description provided for @finishScanning.
  ///
  /// In en, this message translates to:
  /// **'Finish scanning'**
  String get finishScanning;

  /// No description provided for @historicalFramePositive.
  ///
  /// In en, this message translates to:
  /// **'Historical frame — saved as positive preview'**
  String get historicalFramePositive;

  /// No description provided for @levelPhoneOverTable.
  ///
  /// In en, this message translates to:
  /// **'Level the phone over the light table'**
  String get levelPhoneOverTable;

  /// No description provided for @almostLevelHoldSteady.
  ///
  /// In en, this message translates to:
  /// **'Almost level — hold steady'**
  String get almostLevelHoldSteady;

  /// No description provided for @leveledFocusingNegative.
  ///
  /// In en, this message translates to:
  /// **'Leveled — focusing on negative…'**
  String get leveledFocusingNegative;

  /// No description provided for @focusedCapturingPositive.
  ///
  /// In en, this message translates to:
  /// **'Focused — capturing (positive view)'**
  String get focusedCapturingPositive;

  /// No description provided for @focusedCapturingNegative.
  ///
  /// In en, this message translates to:
  /// **'Focused — capturing (negative view)'**
  String get focusedCapturingNegative;

  /// No description provided for @mediumFormatDimensions.
  ///
  /// In en, this message translates to:
  /// **'Medium format · {dimensions}'**
  String mediumFormatDimensions(String dimensions);

  /// No description provided for @imageNotAvailableOffline.
  ///
  /// In en, this message translates to:
  /// **'Image not available offline yet. Wait for download or check connection.'**
  String get imageNotAvailableOffline;

  /// No description provided for @couldNotShareImage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share image.'**
  String get couldNotShareImage;

  /// No description provided for @photosAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Photos library access denied. Enable in settings.'**
  String get photosAccessDenied;

  /// No description provided for @savedToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Saved to Photos.'**
  String get savedToPhotos;

  /// No description provided for @couldNotSaveToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save to Photos.'**
  String get couldNotSaveToPhotos;

  /// No description provided for @cannotRotateImageType.
  ///
  /// In en, this message translates to:
  /// **'Cannot rotate this image type.'**
  String get cannotRotateImageType;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// No description provided for @dowSun.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get dowSun;

  /// No description provided for @dowMon.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get dowMon;

  /// No description provided for @dowTue.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get dowTue;

  /// No description provided for @dowWed.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get dowWed;

  /// No description provided for @dowThu.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get dowThu;

  /// No description provided for @dowFri.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get dowFri;

  /// No description provided for @dowSat.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get dowSat;

  /// No description provided for @toggleOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get toggleOn;

  /// No description provided for @toggleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get toggleOff;

  /// No description provided for @framesCapturedProgress.
  ///
  /// In en, this message translates to:
  /// **'{captured} / {max} captured'**
  String framesCapturedProgress(int captured, int max);

  /// No description provided for @format35mmDimensions.
  ///
  /// In en, this message translates to:
  /// **'35 mm · {dimensions}'**
  String format35mmDimensions(String dimensions);

  /// No description provided for @rotate90CounterClockwise.
  ///
  /// In en, this message translates to:
  /// **'90° counter-clockwise'**
  String get rotate90CounterClockwise;

  /// No description provided for @rotate90Clockwise.
  ///
  /// In en, this message translates to:
  /// **'90° clockwise'**
  String get rotate90Clockwise;

  /// No description provided for @languageChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageChooseTitle;

  /// No description provided for @languageChooseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language for AgXel.'**
  String get languageChooseSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'en',
    'es',
    'fr',
    'ja',
    'ko',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

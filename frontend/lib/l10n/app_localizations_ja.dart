// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'AgXel';

  @override
  String get appTagline => 'アナログの心、デジタルの頭脳';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get saveChanges => '変更を保存する';

  @override
  String get delete => '削除';

  @override
  String get retry => 'リトライ';

  @override
  String get back => '戻る';

  @override
  String get close => '閉じる';

  @override
  String get clear => 'クリア';

  @override
  String get more => 'もっと';

  @override
  String get less => '少ない';

  @override
  String get status => '状態';

  @override
  String get loading => '読み込み中…';

  @override
  String get somethingWentWrong => '何か問題が発生しました';

  @override
  String get couldNotOpenLink => 'リンクを開けませんでした。';

  @override
  String get tryAgain => 'もう一度やり直してください';

  @override
  String lastUpdated(String date) {
    return '最終更新: $date';
  }

  @override
  String get languageSettingsTitle => '言語';

  @override
  String get languageSystemDefault => 'システムのデフォルト';

  @override
  String get languageEnglish => '英語';

  @override
  String get languageVietnamese => 'ベトナム語';

  @override
  String get languageDescription => 'アプリの優先言語を選択します。';

  @override
  String get profileTitle => 'プロフィール';

  @override
  String get filmEnthusiast => 'フィルム愛好家';

  @override
  String get halidePremium => 'AgXel';

  @override
  String get editProfile => 'プロフィールの編集';

  @override
  String get storageStrategy => 'ストレージ戦略';

  @override
  String get themes => 'テーマ';

  @override
  String get shootingAnalytics => '撮影分析';

  @override
  String get support => 'サポート';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get termsAndConditions => '利用規約';

  @override
  String get deleteAccount => 'アカウントの削除';

  @override
  String get signOut => 'サインアウト';

  @override
  String get deleteAccountTitle => 'アカウントを削除しますか?';

  @override
  String get deleteAccountBody =>
      'このアクションは永続的です。すべてのフィルム ロール、EXIF ログ、クラウド同期画像は当社のサーバーから直ちに消去されます。';

  @override
  String get planPro => 'PRO';

  @override
  String get planFree => 'FREE';

  @override
  String get loginWithEmail => 'メールでログイン';

  @override
  String get loginWithPhone => '電話でログイン';

  @override
  String get loginWithGoogle => 'Googleでログイン';

  @override
  String get loginWithApple => 'Appleでログイン';

  @override
  String get verifyPhone => '電話番号を確認する';

  @override
  String get verificationCode => '検証コード';

  @override
  String get verifyAndLogin => '認証してログイン';

  @override
  String get backToOptions => 'オプションに戻る';

  @override
  String get newHere => '初めてですか？';

  @override
  String get createAccount => 'アカウントを作成する';

  @override
  String get emailSignIn => 'メールでサインイン';

  @override
  String get email => 'メール';

  @override
  String get password => 'パスワード';

  @override
  String get login => 'ログイン';

  @override
  String get phoneSignIn => '電話番号でサインイン';

  @override
  String get phoneSignInHint => 'あなたの番号にコードを送信します';

  @override
  String get phoneNumber => '電話番号';

  @override
  String get sendCode => 'コードを送信する';

  @override
  String get phoneVerificationFailed => '電話認証に失敗しました';

  @override
  String get welcomeSignIn => 'AgXel へようこそ。サインインしてください。';

  @override
  String get welcomeSignUp => 'AgXel へようこそ。サインアップしてください。';

  @override
  String get registerTitle => 'アカウント作成';

  @override
  String get alreadyHaveAccount => 'すでにアカウントをお持ちですか?';

  @override
  String get signIn => 'サインイン';

  @override
  String get archiveTitle => 'アーカイブ';

  @override
  String get openNewRoll => '新しいロールを開く';

  @override
  String get loadYourFirstRoll => '最初のロールを読み込む';

  @override
  String get showAllRolls => 'すべてのロールを表示';

  @override
  String get filterAll => '全て';

  @override
  String get filterInProgress => '進行中';

  @override
  String get filterArchived => 'アーカイブ済み';

  @override
  String get lifecycleShoot => '撮影';

  @override
  String get lifecycleLab => '現像';

  @override
  String get lifecycleScan => 'スキャン';

  @override
  String get lifecycleArchive => 'アーカイブ';

  @override
  String get rollStatusShooting => '撮影中';

  @override
  String get rollStatusLab => '現像中';

  @override
  String get rollStatusSyncing => '同期中…';

  @override
  String get rollStatusScanned => 'スキャン済み';

  @override
  String get rollStatusArchived => 'アーカイブ済み';

  @override
  String get addRollStep1 => 'ザ・ロール';

  @override
  String get addRollStep2 => '詳細';

  @override
  String get totalFrames => '合計フレーム数 (例: 12、24、36)';

  @override
  String get title => 'タイトル';

  @override
  String get description => '説明';

  @override
  String get iso => 'ISO';

  @override
  String get expiredYear => '有効期限が切れた年';

  @override
  String get driveUrlOptional => 'ドライブの URL (オプション)';

  @override
  String get shotNotesLabel => 'メモ';

  @override
  String get shotNotesHint => '任意 — 最大500文字';

  @override
  String get startRoll => 'スタートロール';

  @override
  String get next => '次';

  @override
  String get filmStock => 'フィルムストック(*)';

  @override
  String get gear => 'ギヤ';

  @override
  String get logShot => 'ログショット';

  @override
  String get openRoll => 'オープンロール';

  @override
  String get driveLink => 'ドライブリンク';

  @override
  String get saveAndSync => '保存と同期';

  @override
  String get recordShot => 'レコードショット';

  @override
  String get shutterSpeed => 'シャッタースピード';

  @override
  String get aperture => '絞り';

  @override
  String get logShotTitle => 'ログショット';

  @override
  String get manualAddFree => '手動追加（無料）';

  @override
  String get submitAndSync => '送信して同期';

  @override
  String get reset => 'リセット';

  @override
  String get photos => '写真';

  @override
  String get shotLog => 'ショットログ';

  @override
  String get lockerTitle => '歯車';

  @override
  String get addGear => 'ギアを追加する';

  @override
  String get addFirstGear => '1速ギアを追加する';

  @override
  String get nickname => 'ニックネーム';

  @override
  String get manufacturer => 'メーカー';

  @override
  String get model => 'モデル';

  @override
  String get serialNumber => 'シリアルナンバー';

  @override
  String saveGear(String gearType) {
    return '保存$gearType';
  }

  @override
  String get camera => 'カメラ';

  @override
  String get lens => 'レンズ';

  @override
  String get cameraNotFound => 'カメラが見つかりません';

  @override
  String get editGear => 'ギアを編集する';

  @override
  String get editGearImages => 'ギア画像を編集する';

  @override
  String get createAndMount => '作成とマウント';

  @override
  String get createNewLens => '新しいレンズを作成する';

  @override
  String get createMountLensHint => 'このボディに新しいレンズを作成して取り付けます。';

  @override
  String get newLensDetails => '新しいレンズの詳細';

  @override
  String get selectLensToMount => 'マウントするレンズを選択してください';

  @override
  String get noLensesAvailable => '使用可能なレンズがありません';

  @override
  String get gearStatusActive => 'アクティブ';

  @override
  String get gearStatusRepair => '修理中';

  @override
  String get gearStatusSold => '販売済み';

  @override
  String get gearStatusArchived => 'アーカイブ済み';

  @override
  String get meterTitle => 'メーター';

  @override
  String get startingCamera => 'カメラを起動中…';

  @override
  String get logToRoll => 'ログからロールまで';

  @override
  String get zoneOverlay => 'ゾーンオーバーレイ';

  @override
  String get multiSpot => 'マルチスポット';

  @override
  String get lockExposure => 'ロック';

  @override
  String get changesUpdateEv => '変更により EV と計算された露出が更新されます。';

  @override
  String get subscriptionTitle => 'AgXel';

  @override
  String get restorePurchases => '購入を復元する';

  @override
  String get restoredSuccessfully => '正常に復元されました。';

  @override
  String get noPreviousPurchases => '以前の購入は見つかりませんでした。';

  @override
  String get restoreFailed => '復元を完了できませんでした。もう一度試してください。';

  @override
  String get privacyPolicyLink => 'プライバシーポリシー';

  @override
  String get termsOfUse => '利用規約';

  @override
  String get subscribe => '購読する';

  @override
  String get freePlanName => 'アーカイブ';

  @override
  String get proPlanName => 'AgXel';

  @override
  String get annual => '年間';

  @override
  String get monthly => '毎月';

  @override
  String get freeFeature1 => 'ロール＆フレームロギング（絞り、シャッター、位置）';

  @override
  String get freeFeature2 => '撮影→ラボ→スキャン→アーカイブのワークフロー';

  @override
  String get freeFeature3 => '最大 3 台のカメラ (各レンズ 1 台) と無制限のロール';

  @override
  String get freeFeature4 => 'Lab Drive から画像を取得する';

  @override
  String get freeFeature5 => 'パーソナルクラウド同期 (Google ドライブ、NAS)';

  @override
  String get freeFeature6 => '標準の EXIF ログ';

  @override
  String get proFeature1 => 'すべてが無料';

  @override
  String get proFeature2 => 'AgXel クラウド ストレージ (ホスト型システム クラウド)';

  @override
  String get proFeature3 => 'プロフェッショナル露出計（スポット測光＆EV）';

  @override
  String get proFeature4 => '高度な露出ガイダンス';

  @override
  String get proFeature5 => '優先サポート';

  @override
  String get storageLocal => 'ローカルデバイス';

  @override
  String get storagePersonalCloud => 'パーソナルクラウド';

  @override
  String get storageSystemCloud => 'システムクラウド';

  @override
  String get localStorage => 'ローカルストレージ';

  @override
  String get systemCloud => 'システムクラウド';

  @override
  String get systemCloudConnections => 'システムクラウド接続';

  @override
  String get localAccounts => 'ローカルアカウント';

  @override
  String get connectGoogle => 'Google に接続する';

  @override
  String get connectNas => 'NASを接続する';

  @override
  String get host => 'ホスト';

  @override
  String get username => 'ユーザー名';

  @override
  String get passwordField => 'パスワード';

  @override
  String get connectionFailed => '接続に失敗しました';

  @override
  String get archiveStorage => 'アーカイブストレージ';

  @override
  String get labScanSync => 'ラボスキャン同期';

  @override
  String get addStorage => 'ストレージの追加';

  @override
  String get supportTitle => 'サポート';

  @override
  String get supportHeadline => '私たちはすべてのメッセージを読みます。';

  @override
  String supportDescription(String email) {
    return 'フィードバック、バグレポート、機能リクエストを以下に送信してください。$email。';
  }

  @override
  String get contactSupport => 'サポートに連絡する';

  @override
  String get sendFeedback => 'フィードバックを送信する';

  @override
  String get supportTip => 'ヒント: スクリーンショットは非常に役立ちます。';

  @override
  String get unableToOpenEmail => 'メールアプリを開けません。';

  @override
  String get supportEmailSubject => 'ハロゲン化物のサポート';

  @override
  String get feedbackEmailSubject => 'ハロゲン化物フィードバック';

  @override
  String get themesTitle => 'テーマ';

  @override
  String get themeDeepHarbor => 'ディープハーバー';

  @override
  String get themeMistyForest => '霧の森';

  @override
  String get themeOceanRoot => 'オーシャンルート';

  @override
  String get themeBlueBell => 'ブルーベル';

  @override
  String get themeCherryBlossom => '桜';

  @override
  String get themeMorningFrost => '朝の霜';

  @override
  String get themeCarbonNight => 'カーボンナイト';

  @override
  String get themeHarvestTable => '収穫テーブル';

  @override
  String get themeSpaceIndigo => 'スペースインディゴ';

  @override
  String get analyticsTitle => '射撃分析';

  @override
  String get exposureMatrix => '露出マトリックス';

  @override
  String get favoriteEmulsion => 'お気に入りのエマルジョン';

  @override
  String get activeHardware => 'アクティブなハードウェア';

  @override
  String get streak => 'ストリーク';

  @override
  String get current => '現在';

  @override
  String get best => '最高';

  @override
  String get longestStreak => '最長連続記録';

  @override
  String get total => '合計';

  @override
  String get shotsFired => '発砲された';

  @override
  String get active => 'アクティブ';

  @override
  String get activeDays => '活動的な日々';

  @override
  String get privacyTitle => 'プライバシー';

  @override
  String get termsTitle => '条項';

  @override
  String get privacyDocumentLabel => 'プライバシーポリシー';

  @override
  String get termsDocumentLabel => '利用規約';

  @override
  String get editProfileTitle => 'プロフィールの編集';

  @override
  String get displayName => '表示名';

  @override
  String get professionalNickname => '職業上のニックネーム';

  @override
  String get bio => 'バイオ';

  @override
  String get profileUpdated => 'プロフィールを更新しました。';

  @override
  String get profileUpdateFailed => 'プロフィールを更新できませんでした。';

  @override
  String get rollDetailTitle => 'ロール';

  @override
  String get labDigitalSync => 'ラボデジタル同期';

  @override
  String get labDigitalSyncSubtitle =>
      'ラボから Google ドライブ フォルダーまたは ZIP リンクを貼り付けます。';

  @override
  String get driveUrlHint => 'https://drive.google.com/...';

  @override
  String get atLabNoDriveUrlHint =>
      'Driveリンクがない場合は、ステータスをスキャン済みに変更（上の「次へ：スキャン済みにする」）して、この端末から写真を追加できます。';

  @override
  String get atLabAddFromDevice => '端末から追加';

  @override
  String get atLabAddFromDeviceSubtitle =>
      '無料プランではスキャンをこの端末に保存します。ライブラリから写真を選んでください。';

  @override
  String get chooseLabImportMethodFree => 'この端末からスキャン写真を追加します。';

  @override
  String get driveLabSyncProOnly =>
      'Driveリンクからのスキャン同期には Halide Pro が必要です。代わりに端末から写真を追加してください。';

  @override
  String get scannedDriveSyncedHint =>
      '写真はラボのDriveリンクから取り込みました。更新するにはDriveフォルダを再同期してください。コマ順を保つため手動追加はできません。';

  @override
  String get addMorePhotos => '写真を追加';

  @override
  String get cameraScanning => 'カメラスキャン';

  @override
  String get cameraScanningSubtitle => 'ライトテーブル上でのハンズフリーのジャイロ支援スキャン。';

  @override
  String get scanNegatives => 'スキャンネガ（ライトテーブル）';

  @override
  String get addImages => '画像の追加';

  @override
  String get addMore => 'さらに追加';

  @override
  String get uploading => 'アップロード中…';

  @override
  String uploadingProgress(int done, int total) {
    return 'アップロード中$done / $total…';
  }

  @override
  String get tapToSelectPhotos => 'タップして写真を選択します';

  @override
  String tapToSelectUpTo(int count) {
    return 'タップして最大まで選択します$count写真';
  }

  @override
  String addPhotosLeft(int count) {
    return '写真を追加 ($count左）';
  }

  @override
  String get share => '共有';

  @override
  String get sendAsPrint => 'Send as postcard';

  @override
  String get printComposeTitle => 'Send postcard';

  @override
  String get printSend => 'Send';

  @override
  String get printNoteLabel => 'Note on the back';

  @override
  String get printNoteHint => 'A little love, the old-fashioned way…';

  @override
  String get printNoteRequired => 'Add a note before sending.';

  @override
  String get printFontLabel => 'Font';

  @override
  String get printFontHand => 'Handwriting';

  @override
  String get printFontType => 'Type';

  @override
  String get printSizeLabel => 'Size';

  @override
  String get printPaperLabel => 'Paper';

  @override
  String get printRecipientsLabel => 'Friend emails';

  @override
  String get printRecipientsHint => 'friend@email.com, other@email.com';

  @override
  String get printRecipientsRequired => 'Add at least one email address.';

  @override
  String get printFromLabel => 'From';

  @override
  String get printFromHint => 'Your name';

  @override
  String get printFromRequired => 'Add your name so they know who sent it.';

  @override
  String get printExpireLabel => 'Link expires';

  @override
  String printExpireDays(int days) {
    return '$days days';
  }

  @override
  String get printPrivacyHint =>
      'Anyone with the link can open the postcard (up to 30 days). Downloads include the photo and a text file of the note.';

  @override
  String get printTapBack => 'Tap to flip · love note on the back';

  @override
  String get printTapFront => 'Tap to see the photo';

  @override
  String get printTapToWrite => 'Tap anywhere to write';

  @override
  String get printStampHint =>
      'Drag stamp · pinch size · double-tap to lock QR';

  @override
  String get printStampLocked => 'QR stamp locked';

  @override
  String get printStampRequired =>
      'Double-tap the stamp to lock a QR image before sending.';

  @override
  String printStampSizeHint(int percent) {
    return 'Suggested stamp size · $percent%';
  }

  @override
  String get printVersoHint => 'Back';

  @override
  String get printNeedsCloudScan =>
      'This photo isn\'t on AgXel Cloud yet. Only paid plans can upload and send postcards.';

  @override
  String printSentSuccess(int count, int days) {
    return 'Postcard sent to $count · link expires in $days days';
  }

  @override
  String get printShareSubject => 'A postcard for you';

  @override
  String get saveToPhotos => '写真に保存';

  @override
  String get couldNotRotateImage => '画像を回転できませんでした。';

  @override
  String get couldNotUploadRotated =>
      '回転した写真をクラウドにアップロードできませんでした。それらはまだこの携帯電話に保存されています。ロールを開いて、もう一度試してください。';

  @override
  String get editsLocalOnlyHint =>
      '編集内容はこのデバイスに保存されます。 Pro にアップグレードすると、回転した画像をクラウドに同期できます。';

  @override
  String unsavedCloudChanges(int count) {
    return '保存されていないクラウドの変更:$count— アップロードを AgXel Cloud に残します。';
  }

  @override
  String scannedDate(String date) {
    return 'スキャン済み:$date';
  }

  @override
  String isoValue(String iso) {
    return 'ISO$iso';
  }

  @override
  String get apertureMissing => '---';

  @override
  String get retryDownload => 'ダウンロードを再試行します';

  @override
  String get copyAll => 'すべてコピー';

  @override
  String get lightTableLockScreen => 'ロック画面';

  @override
  String freeTierCameraLimit(int count) {
    return '無料には以下が含まれます$countカメラ。 AgXel にアップグレードすると、無制限のギアが利用できます。';
  }

  @override
  String get freeTierLensLimit =>
      '無料にはカメラごとに 1 つのレンズが含まれます。さらにマウントするには、AgXel にアップグレードしてください。';

  @override
  String get freeTierStandaloneLens =>
      'Free では、カメラのマウント画面からレンズを追加します (ボディごとに 1 つのレンズ)。';

  @override
  String get couldNotUpdateStatus => 'ステータスを更新できませんでした。もう一度試してください。';

  @override
  String savedPhotosOnDevice(int count) {
    return '保存されました$countこのデバイス上の写真。';
  }

  @override
  String get guidanceGotIt => 'わかった';

  @override
  String get guidanceNewRollStatus =>
      'ステータス バッジをタップして、ワークフロー内の位置を変更します。フィルムがラボにある場合は「ラボ」に移動し、ファイルがある場合は「スキャン」します。';

  @override
  String get guidanceNewRollExif =>
      'カメラアイコンをタップして、写真のEXIFから絞り、シャッター、位置を記録するか、シートに手動で入力します。 [ライトメーター]タブからログを記録することもできます。';

  @override
  String get guidanceNewRollViewLogs =>
      'このロールカードをタップして開き、[ショット ログ] タブで撮影中の各フレームの技術データを確認できます。';

  @override
  String get guidancePersonalDriveBackup =>
      '右上のクラウドアップロードアイコンをタップすると、フル品質のスキャンを個人の Google Drive の Agxel Vault フォルダにバックアップできます。';

  @override
  String get archiveBackupGuideBody =>
      'スキャン済みロールはいつでも個人の Google Drive にバックアップできます — 上のクラウドアップロードアイコンをタップしてください。';

  @override
  String get guidanceSyncAfterLink =>
      'ドライブのリンクが保存されました。強調表示されたクラウド アイコンをタップして、Google ドライブからスキャンをダウンロードします (後でもう一度タップして更新できます)。';

  @override
  String get guidanceAtLabBadge =>
      'AT LAB は、あなたのフィルムがラボにあることを意味します。 Google ドライブのリンクを取得したら、右側のリンクまたはクラウド アイコンを使用して追加し、スキャンを同期します。';

  @override
  String get guidanceDriveLinkWithUrl =>
      'クラウド アイコンは、保存されたドライブ リンクからスキャンをダウンロードします。 URLを変更する必要がある場合は、リンクアイコンをタップします。';

  @override
  String get guidanceDriveLinkNoUrl =>
      'ラボで共有する場合は、強調表示されたリンク アイコン (右上) をタップして、Google ドライブ フォルダーの URL を貼り付けます。保存後、アイコンは雲になり、タップしてスキャンをダウンロードできるようになります。';

  @override
  String get guidanceMeterSpotIntro =>
      '円をタップして中心をスポット測光し、絞り優先に戻ります。 f/ または SS をタップして露出を設定し、EV または ISO で補正してから、LOCK をタップして構図を決めている間露出を保持します。';

  @override
  String get guidanceMeterLogToRoll =>
      '「LOG TO ROLL」をタップすると、絞り、シャッター、メーターの詳細を撮影時のロールに保存します。エントリは、アーカイブ EXIF ログとともにショット ログに表示されます。';

  @override
  String get guidancePrintStampIntro =>
      'Drag this stamp over the part of the photo you want on the QR. Pinch to resize, then double-tap to lock before you send.';

  @override
  String get guidanceGyroNegativePreview =>
      '生のネガは、ライト テーブル上に置かれたフィルムを示しています。オレンジ色のベースで、処理は行われていません。アライメントやフレームの確認に使用します。';

  @override
  String get guidanceGyroPositivePreview =>
      'ポジティブ プレビューでは、オレンジ マスクがライブで反転されるため、スキャンが完成したプリントのように見えます。これは、自動キャプチャの実行中に露出を判断するためのデフォルトです。';

  @override
  String get gyroScanTitle => 'ジャイロスキャン';

  @override
  String get gyroFormat35mm => '35mm';

  @override
  String get gyroFormat120 => '120';

  @override
  String get noRollsYet => 'まだロールがありません';

  @override
  String get errorLoadingRolls => 'ロールの読み込みエラー';

  @override
  String get errorLoadingGear => 'ギアの読み込みエラー';

  @override
  String get rollNotFound => 'ロールが見つかりません';

  @override
  String get storageLimitReached => 'ストレージ制限に達しました。プランをアップグレードしてください。';

  @override
  String get purchaseComplete => '購入完了！';

  @override
  String get purchaseFailed => '購入を完了できませんでした。';

  @override
  String get syncComplete => '同期が完了しました。';

  @override
  String get syncFailed => '同期に失敗しました。もう一度試してください。';

  @override
  String get downloadComplete => 'ダウンロードが完了しました。';

  @override
  String get downloadFailed => 'ダウンロードに失敗しました。';

  @override
  String get connectDriveFirst => 'まずストレージ設定で Google ドライブを接続します。';

  @override
  String get savedSuccessfully => '正常に保存されました。';

  @override
  String imageCount(int current, int max) {
    return '$current / $max';
  }

  @override
  String get updateRollStatus => 'ロールステータスの更新';

  @override
  String get statusDescShooting => 'フィルムをロードしました - 撮影中にショットをログに記録します';

  @override
  String get statusDescLab => 'フィルムはラボにあります - ドライブのリンクを追加するかスキャンします';

  @override
  String get statusDescScanned => 'スキャンが含まれています — ギャラリーを参照してください';

  @override
  String get statusDescArchived => '完了 — アクティブリストから非表示';

  @override
  String get statusDescSyncing => 'ドライブからスキャンをダウンロード中…';

  @override
  String get alreadyPassed => 'すでに合格しました';

  @override
  String get lifecycleDone => '終わり';

  @override
  String get lifecycleSync => '同期';

  @override
  String get appTheme => 'アプリのテーマ';

  @override
  String get language => '言語';

  @override
  String get archive => 'アーカイブ';

  @override
  String get emptyGearTitle => 'あなたのロッカーは空です';

  @override
  String get emptyGearSubtitle => '最初のカメラを追加してロールの記録を開始します。';

  @override
  String get locationPermissionDenied => '位置情報の許可が拒否されました。';

  @override
  String get locationUnavailable => '場所が利用できません。';

  @override
  String get logExifTitle => 'EXIF をログに記録する';

  @override
  String get confirm => '確認する';

  @override
  String get driveUrl => 'ドライブの URL';

  @override
  String get noPhotosYet => '写真はまだありません';

  @override
  String get noShotsLogged => 'まだショットが記録されていません';

  @override
  String get selectRoll => '選択ロール';

  @override
  String get meterEv => 'EV';

  @override
  String get meterIso => 'ISO';

  @override
  String get meterAperture => '絞り';

  @override
  String get meterShutter => 'シャッター';

  @override
  String get meterCompensation => '補償';

  @override
  String get meterSpot => 'スポット';

  @override
  String get meterPriorityAperture => '絞り優先';

  @override
  String get meterPriorityShutter => 'シャッター優先';

  @override
  String get meterNoRolls => 'アクティブなロールがありません';

  @override
  String get continueButton => '続く';

  @override
  String get upgradeToPro => 'プロにアップグレード';

  @override
  String get currentPlan => '現在の計画';

  @override
  String get perYear => '年間';

  @override
  String get perMonth => '月あたり';

  @override
  String get free => '無料';

  @override
  String get manageSubscription => 'サブスクリプションの管理';

  @override
  String get productsUnavailable => '利用できない製品';

  @override
  String get checkingStore => 'ストアを確認中…';

  @override
  String get legalAppleEula => 'Apple 標準 EULA';

  @override
  String get legalAppleEulaDescription =>
      'ライセンスされたアプリケーションには、Apple の標準 EULA も適用されます。';

  @override
  String get viewAppleEula => 'Apple 標準 EULA を表示する';

  @override
  String get chooseYourPlan => 'プランを選択してください';

  @override
  String get paywallSubtitle => 'Pro には、AgXel Cloud Storage とプロ仕様の露出計が追加されています';

  @override
  String get monthlyBilling => '月額課金';

  @override
  String get annualBilling => '年間請求';

  @override
  String get welcomeToHalidePro => 'AgXelへようこそ！プランは現在有効です。';

  @override
  String get purchaseFailedRetry => '購入を完了できませんでした。もう一度試してください。';

  @override
  String get unableToLoadSubscription => 'サブスクリプション オプションを読み込めません。もう一度試してください。';

  @override
  String get storeNotAvailable => 'ストアは利用できません。';

  @override
  String get restoreAppleIdHint => '購入を復元するには、Apple ID でサインインするよう求められる場合があります。';

  @override
  String get startFreeTrial => '無料トライアルを開始する';

  @override
  String get getHalidePro => 'AgXelを入手';

  @override
  String get save20Percent => '20% 節約';

  @override
  String get forever => '永遠に';

  @override
  String get freeTrialWhereEligible => '対象となる場合は無料トライアル';

  @override
  String get planNotAvailable => 'このプランはまだご利用いただけません。別のオプションを試してください。';

  @override
  String subscriptionDisclosure(String price) {
    return 'あ$priceサブスクリプションは確認時に iTunes アカウントに適用されます。現在の期間が終了する 24 時間以内にキャンセルしない限り、サブスクリプションは自動的に更新されます。 iTunes の設定でいつでも管理できます。サブスクリプションを購入すると、無料トライアルの未使用部分は失われます。';
  }

  @override
  String get perYearShort => '/年';

  @override
  String get perMonthShort => '/月';

  @override
  String get storageStrategyTitle => 'ストレージ戦略';

  @override
  String get systemCloudQuota => 'システムクラウドクォータ';

  @override
  String storageUsedOf(String used, String cap) {
    return '$used使われた$cap';
  }

  @override
  String addonStorageFromPurchases(String amount) {
    return '+$amount追加購入から';
  }

  @override
  String get systemCloudRequiresPro =>
      'System Cloud には Pro 機能が必要です。プロフェッショナルな同期は、個々のクラウド アカウントに限定されます。';

  @override
  String get upgradeProStorageHint =>
      'Pro ストレージを入手するには、上記をアップグレードしてください。各アカウントにはデフォルトで 5 ～ 10 GB が含まれています。';

  @override
  String get storageManagement => 'ストレージ管理';

  @override
  String get manageStorageAccountsSubtitle => 'クラウドおよびローカル ストレージ アカウントを管理する';

  @override
  String get systemCloudAfterUpgradeHint =>
      'Pro ストレージを入手するには、上記をアップグレードしてください。アップグレード後、アカウントがここに表示されます。';

  @override
  String get primaryBadge => '主要な';

  @override
  String get setAsPrimary => 'プライマリとして設定';

  @override
  String get primaryTooltip => '主要な';

  @override
  String get storageUsage => 'ストレージの使用量';

  @override
  String get addMoreStorage => 'ストレージを追加する';

  @override
  String get tierBadgeByo => 'BYO';

  @override
  String get cloudProvidersTitle => 'クラウドプロバイダー';

  @override
  String get cloudProvidersSubtitle =>
      '独自のクラウドまたはネットワーク ストレージを追加します。接続するプロバイダーをタップします。';

  @override
  String connectedCount(int count) {
    return '$count接続済み';
  }

  @override
  String get addAction => '追加';

  @override
  String get archiveStorageDescription => 'ギアとロールをこのアカウントにバックアップします。';

  @override
  String get labScanSyncDescription => 'ドライブ URL 経由でフィルム スキャンを自動同期します。';

  @override
  String get priBadge => 'PRI';

  @override
  String get fillAllFields => 'すべてのフィールドに入力してください';

  @override
  String get nasConfigurationTitle => 'NASの構成';

  @override
  String get nasConfigSubtitle => 'NAS の詳細を入力してストレージを設定します';

  @override
  String get googleDrive => 'Googleドライブ';

  @override
  String get nasProvider => 'NAS';

  @override
  String get addStorageTitle => 'ストレージの追加';

  @override
  String get storagePurchaseIntro =>
      '必要な追加のクラウド スペースの量を選択します。価格は現地通貨で表示されます。同じサイズを複数回購入できます。購入するたびに合計金額が加算されます。';

  @override
  String get storagePurchaseFooter =>
      '各パックは保管庫の合計に追加されます。いつでも同じサイズを再度購入できます。支払いにはこのデバイスの方法が使用されます。通常、余分なスペースは数秒以内に表示されます。';

  @override
  String buyTier(String tier, String price) {
    return '買う$tier — $price';
  }

  @override
  String buyTierNoPrice(String tier) {
    return '買う$tier';
  }

  @override
  String get refreshPrices => '価格を更新する';

  @override
  String get storageUpdated => 'ストレージが更新されました。新しいクォータは有効です。';

  @override
  String get purchaseCancelled => '購入はキャンセルされました。';

  @override
  String get couldNotRefreshPrices => '価格を更新できませんでした。しばらくしてからもう一度お試しください。';

  @override
  String get couldNotLoadStorageOptions =>
      'ストレージ オプションを読み込めませんでした。接続を確認して、もう一度試してください。';

  @override
  String get stackable => '積み重ね可能';

  @override
  String get connectGoogleDriveTitle => 'Googleドライブを接続する';

  @override
  String get connectGoogleDriveBody =>
      '共有ドライブ リンクから写真をインポートするには、AgXel は Google アカウント (読み取り専用) にアクセスする必要があります。 [設定] で一度接続するか、下の [接続] をタップします。';

  @override
  String get connectGoogleUpper => 'Googleに接続する';

  @override
  String get cancelUpper => 'キャンセル';

  @override
  String get googleDriveConnected => 'Googleドライブが接続されました。';

  @override
  String get couldNotConnectGoogleDrive => 'Googleドライブに接続できませんでした。';

  @override
  String get downloadFolderFailed =>
      'フォルダーをダウンロードできませんでした。ドライブへのアクセスを確認して、再試行してください。';

  @override
  String get couldNotRetrievePhotos => '写真を取得できませんでした。ドライブのリンクを確認してください。';

  @override
  String get fetchPhotosError => '写真の取得中に問題が発生しました。';

  @override
  String get privacyLastUpdatedDate => '2026 年 4 月 6 日';

  @override
  String get termsLastUpdatedDate => '2026 年 4 月 20 日';

  @override
  String get joinHalide => 'AgXelに参加する';

  @override
  String get registerSubtitle => 'アナログな旅を記録する';

  @override
  String get confirmPassword => 'パスワードを認証する';

  @override
  String get passwordsDoNotMatch => 'パスワードが一致しません';

  @override
  String get signInTermsFooter => 'サインインすると、利用規約に同意したことになります。';

  @override
  String get displayNameHint => 'あなたの表示名';

  @override
  String get nicknameHint => '例えばフィルムシューター';

  @override
  String get bioHint => 'プロフィールの短い自己紹介';

  @override
  String get tapToUploadPhoto => 'タップして写真をアップロード';

  @override
  String get photoSavedTapSaveChanges =>
      'このデバイスに保存された写真。 「変更を保存」をタップしてプロフィールを更新します。';

  @override
  String get couldNotSavePhoto => '写真を保存できませんでした。もう一度試してください。';

  @override
  String get emailGreeting => 'こんにちは、AgXelチームです。';

  @override
  String get supportEmailBodyPlaceholder => '(何が起こったのか/何が必要なのか説明してください)';

  @override
  String get feedbackEmailBodyPlaceholder => '(気に入った点/改善してほしい点を教えてください)';

  @override
  String get emailBodySeparator => '—';

  @override
  String emailAccountLine(String email) {
    return 'アカウント：$email';
  }

  @override
  String emailUserIdLine(String uid) {
    return 'ユーザーID：$uid';
  }

  @override
  String get moveToArchiveTitle => 'アーカイブに移動しますか?';

  @override
  String get moveToArchiveBody =>
      'このロールはアクティブなリストから残ります。ホームの [アーカイブ] タブからいつでも開くことができます。';

  @override
  String get archiveAction => 'アーカイブ';

  @override
  String get uploadedImages => 'アップロードされた画像';

  @override
  String get rollInfoSection => 'ロール情報';

  @override
  String get rollInfoUpdated => 'ロール情報更新しました！';

  @override
  String get couldNotUpdateRollInfo => 'ロール情報を更新できませんでした。';

  @override
  String get atLabSection => 'アットラボ';

  @override
  String get chooseLabImportMethod => 'スキャンをこのロールに取り込む方法を選択します。';

  @override
  String nextStepLabel(String action) {
    return '次：$action';
  }

  @override
  String get sendToLab => 'ラボに送信';

  @override
  String get markScanned => 'スキャン済みとしてマークを付ける';

  @override
  String get scansComplete => 'スキャンが完了しました';

  @override
  String get moveToArchiveLink => 'アーカイブに移動';

  @override
  String technicalDataCount(int count) {
    return '技術データ ($count）';
  }

  @override
  String get noTechnicalLogs => 'このロールに関して記録された技術ログはありません。';

  @override
  String get alignmentCalibration => 'アライメントのキャリブレーション';

  @override
  String framesOffset(int count) {
    return '$countフレームオフセット';
  }

  @override
  String get alignmentCalibrationHint => 'スキャンが空の読み込みフレームから始まるかどうかを調整します。';

  @override
  String get importOptions => 'インポートオプション';

  @override
  String get driveUrlLabel => '共有ドライブの URL (フォルダーまたは ZIP)';

  @override
  String get fetchFiles => 'ファイルをフェッチする';

  @override
  String foundFilesAtLeaf(int count) {
    return '見つかった$countリーフレベルのファイル。';
  }

  @override
  String get pasteDriveLinkError => '共有の Google ドライブ フォルダーまたは ZIP リンクを貼り付けます。';

  @override
  String get signInToSyncDrive => 'ドライブから同期するにはログインします。';

  @override
  String get driveLinkSavedSyncing => 'ドライブ リンクが保存されました — 同期中…';

  @override
  String get syncStartedInBackground => 'バックグラウンドで同期が開始されました。';

  @override
  String importedPhotosFromDrive(String count) {
    return '輸入品$countドライブからの写真。';
  }

  @override
  String get couldNotSyncFromDrive => 'ドライブから同期できませんでした。';

  @override
  String get addedLocalImageReferences => 'ローカル画像参照を追加しました (無料枠)。';

  @override
  String get couldNotAddImageReferences => '画像参照を追加できませんでした。もう一度試してください。';

  @override
  String successfullyUploadedCount(int count) {
    return '正常にアップロードされました$count画像！';
  }

  @override
  String get pleasePasteDriveUrl => '共有ドライブの URL (フォルダーまたは ZIP) を貼り付けてください。';

  @override
  String get mustSignInDriveSync => 'ドライブから同期するにはログインする必要があります。';

  @override
  String get tryingCloudSync => 'クラウド同期を試行しています…';

  @override
  String get zipDetectedSyncing => 'ZIP が検出されました。写真を抽出して同期しています...';

  @override
  String foundPhotosImporting(int count) {
    return '見つかった$count写真。ロールにインポート中...';
  }

  @override
  String get unexpectedDriveResponse => 'ドライブからの予期しない応答。';

  @override
  String backendErrorDetail(String status, String detail) {
    return 'バックエンドエラー$status: $detail';
  }

  @override
  String get syncFailedVerifyDrive => '同期に失敗しました。ドライブのリンクと権限を確認してください。';

  @override
  String get somethingWrongDuringSync => '同期中に問題が発生しました。';

  @override
  String successfullyImportedNewPhotos(String count) {
    return '正常にインポートされました$count新しい写真！';
  }

  @override
  String get couldNotImportFolderDevice =>
      'デバイスにフォルダーをインポートできませんでした。ドライブへのアクセスを確認します。';

  @override
  String get continueGyroScan => 'ジャイロスキャンを続行';

  @override
  String get continueGyroScanHint => 'さらにフレームを追加し、完了したら「スキャンを終了」をタップします。';

  @override
  String get premiumGyroScanResumeHint => 'プレミアム — ジャイロ HUD を使用してネガをスキャンします。';

  @override
  String get premiumGyroScanFeatureHint =>
      'プレミアム機能 — ジャイロ HUD を使用してスキャンするようにアップグレードします。';

  @override
  String get precisionMeterTitle => '精密計器';

  @override
  String get collapseExposurePanel => '露出パネルを折りたたむ';

  @override
  String get expandExposurePanel => '露出パネルを拡張する';

  @override
  String get unlockExposure => 'ロックを解除する';

  @override
  String get lockExposureUpper => 'ロック露出';

  @override
  String get lockedStatus => 'ロック済み';

  @override
  String get stableStatus => '安定した';

  @override
  String get meteringStatus => '測光…';

  @override
  String multiSpotPinStatus(int count, String plural) {
    return 'マルチスポット・$countピン$plural';
  }

  @override
  String get multiSpotTapAddPins => 'マルチスポット — タップしてピンを追加';

  @override
  String get pinsLabel => 'ピン';

  @override
  String pinCountShort(int count, String plural) {
    return '$countピン$plural';
  }

  @override
  String get logToRollArrow => 'ログトゥロール→';

  @override
  String get logMeterReadingTitle => 'ログメーターの測定値';

  @override
  String get logMeterReadingHint =>
      '撮影ステータスでロールを選択します。絞り、シャッター、メーターの詳細をショットログに保存します。';

  @override
  String get couldNotLoadRolls => 'ロールをロードできませんでした。';

  @override
  String get noRollsInShooting => '射撃ステータスでロールがありません。\nアーカイブからロールを開始します。';

  @override
  String get meterReadingLogged => 'メーターの測定値が記録されました';

  @override
  String get couldNotLogReading => '読み取りのログを記録できませんでした。もう一度やり直してください。';

  @override
  String get untitledRoll => '無題のロール';

  @override
  String get noCamera => 'カメラなし';

  @override
  String get proFeatureBadge => 'プロの機能';

  @override
  String get precisionMeterProTitle => 'AgXel には高精度の測光機能が搭載されています。';

  @override
  String get precisionMeterProSubtitle =>
      'アップグレードすると、スポット測光、EV 補正、マニュアル露出、ロールへのログのロックが解除されます。';

  @override
  String get viewPlans => 'プランを見る';

  @override
  String get logMeterReadingTooltip => 'ログメーターの測定値をロールアップする';

  @override
  String get aperturePickerHint => 'ドラッグして F 値を設定します。メーターの円をタップすると絞り優先に戻ります。';

  @override
  String get shutterPickerHint =>
      'シャッタースピードを選択するとシャッター優先に切り替わります。\nメーターの円をタップすると絞り優先に戻ります。';

  @override
  String evCompensationValue(String value) {
    return '補償：$value';
  }

  @override
  String get driveUrlChip => 'ドライブの URL';

  @override
  String get nicknameLabel => 'ニックネーム';

  @override
  String get brandLabel => 'ブランド';

  @override
  String get modelLabel => 'モデル';

  @override
  String get gallerySection => 'ギャラリー';

  @override
  String get noGearImagesYet => 'ギアの画像はまだありません';

  @override
  String get opticsSection => '光学';

  @override
  String get mountAction => 'マウント';

  @override
  String get noOpticsMounted => '光学系は搭載されていません';

  @override
  String get createNewLensUpper => '新しいレンズの作成';

  @override
  String get brandAndModelRequired => 'ブランドとモデルは必須です。';

  @override
  String get couldNotCreateLens => 'レンズを作ることができませんでした。もう一度試してください。';

  @override
  String get signInSaveGearPhotos => 'ギアの写真を保存するにはサインインしてください。';

  @override
  String get uploadFailedCheckConnection =>
      'アップロードに失敗しました。接続またはストレージを確認してください。';

  @override
  String get gearNotFoundRefresh =>
      'このアカウントのギアが見つかりません。ロッカーを開け、引いて更新してから、もう一度試してください。';

  @override
  String get storageLimitFreeSpace =>
      'ストレージ制限に達しました。スペースを解放するか、プランをアップグレードしてください。';

  @override
  String get uploadRejectedFormat =>
      'アップロードが拒否されました。ファイルサイズ (最大 15 MB) と形式を確認してください。';

  @override
  String get brandFieldHint => 'ブランド (例: ライカ)';

  @override
  String get modelFieldHint => 'モデル (例: 35mm f/2 Summicron)';

  @override
  String get serialNumberOptional => 'シリアル番号 (オプション)';

  @override
  String get nicknameFieldHint => 'ニックネーム (例: 私のお気に入り)';

  @override
  String get optionalField => 'オプション';

  @override
  String get formatLabel => '形式';

  @override
  String errorWithMessage(String message) {
    return 'エラー：$message';
  }

  @override
  String get couldNotLoadAnalytics => '分析を読み込めませんでした';

  @override
  String get noShotsLoggedYear =>
      '昨年はまだショットが記録されていません。メーターまたはロールの詳細からフレームをログに記録して、露出マップの構築を開始します。';

  @override
  String shotsCount(int count) {
    return '$countショット';
  }

  @override
  String get last365Days => '過去 365 日';

  @override
  String periodRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get lightingHabit => '照明の習慣';

  @override
  String get goldenHour => 'ゴールデンアワー';

  @override
  String get goldenHourBiasStrong =>
      'あなたは強いゴールデンアワーバイアスを持っています。セッションの大部分は午後 4 時から午後 6 時の間にあります。多くの場合、露出はこの期間中に最高のスコアを獲得します。';

  @override
  String get goldenHourBiasModerate =>
      'ゴールデンアワーは撮影リズムの重要な部分を占めます。音域を広げるために夜明けのセッションに傾くことを検討してください。';

  @override
  String get goldenHourBiasLow =>
      'ほとんどのセッションはゴールデンアワー以外に行われます。一貫した正午の光または屋内の設定を好む場合があります。';

  @override
  String goldenHourShotsSummary(int golden, int total) {
    return '$goldenの$total現地時間の午後 4 時から 6 時までのショット';
  }

  @override
  String get refreshTooltip => 'リフレッシュ';

  @override
  String get daysUnit => '日';

  @override
  String periodDaysOf(int days) {
    return '/ $days';
  }

  @override
  String get gridOn => 'グリッド: オン';

  @override
  String get gridOff => 'グリッド: オフ';

  @override
  String kelvinValue(int kelvin) {
    return '${kelvin}K';
  }

  @override
  String get guidanceGotItUpper => 'わかった';

  @override
  String get sessionFullRoll => 'フルロール';

  @override
  String get sessionHeavy => '重い';

  @override
  String get sessionActive => 'アクティブ';

  @override
  String get sessionLight => 'ライト';

  @override
  String get sessionNoShots => 'ショットはありません';

  @override
  String get heatLess => '少ない';

  @override
  String get heatMore => 'もっと';

  @override
  String get noExposuresRecorded => '露出は記録されていません';

  @override
  String exposureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count回の露出',
      one: '1回の露出',
    );
    return '$_temp0';
  }

  @override
  String get tapCellToInspect => '任意のセルをタップしてその日を確認します';

  @override
  String get halideDialogBarrier => 'AgXelダイアログバリア';

  @override
  String get halideBottomSheetBarrier => 'ハロゲン化物ボトムシートバリア';

  @override
  String get archivedCannotModify => '画像はアーカイブされ、変更できなくなります。';

  @override
  String get fileMissed => 'ファイルが見つかりませんでした';

  @override
  String uploadAllCount(int count) {
    return 'すべてアップロード ($count）';
  }

  @override
  String uploadedSuccessfullyCount(int count) {
    return 'アップロードされました$count画像が正常に取得されました。';
  }

  @override
  String maxImagesAllowed(int max) {
    return '最大値$maxギアアイテムごとに許可される画像。';
  }

  @override
  String onlyAddedRemainingImages(int count, int max) {
    return '追加のみ$count画像は制限内に収める必要があります$max。';
  }

  @override
  String get signInUploadGearPhotos => 'ギアの写真をアップロードするにはサインインしてください。';

  @override
  String successfullyUploadedGearImages(int count) {
    return '正常にアップロードされました$count画像！';
  }

  @override
  String gearReady(String gearType) {
    return 'あなたの$gearType準備ができています！';
  }

  @override
  String couldNotAddGear(String gearType) {
    return 'あなたを追加できませんでした$gearType。もう一度試してください。';
  }

  @override
  String addGearTypeTitle(String gearType) {
    return '追加$gearType';
  }

  @override
  String saveGearType(String gearType) {
    return '保存$gearType';
  }

  @override
  String clearPinsCount(int count) {
    return 'クリアピン ($count）';
  }

  @override
  String get zoneOverlayTitle => 'ゾーンオーバーレイ';

  @override
  String get zoneOverlayIntro =>
      '色は、シーンの各部分が EV ターゲットと比較してどれだけ明るいかを示します。緑 (ゾーン V) は、その露出では中間の灰色です。';

  @override
  String get zoneOverlayTip =>
      'ヒント: 露出をロックしてからフレームをスキャンします。影をブロックしたり、ハイライトを飛ばしたりしない限り、重要なトーンを深い紫 (ゾーン 0) や明るい赤 (ゾーン X) から遠ざけてください。';

  @override
  String get zone0Meaning => '純粋な黒 - 詳細なし';

  @override
  String get zoneIMeaning => 'とても深い影';

  @override
  String get zoneIIMeaning => '深い影、わずかなテクスチャー';

  @override
  String get zoneIIIMeaning => 'ダークトーンとクリアな質感';

  @override
  String get zoneIVMeaning => '濃い葉、影のある肌';

  @override
  String get zoneVMeaning => '中間のグレー — EV ターゲット';

  @override
  String get zoneVIMeaning => '軽い肌、軽い石';

  @override
  String get zoneVIIMeaning => 'とても明るい肌、明るい雪';

  @override
  String get zoneVIIIMeaning => '明るい雪、白い物体';

  @override
  String get zoneIXMeaning => 'ペーパーホワイトに近い';

  @override
  String get zoneXMeaning => '鏡面ハイライト、純白';

  @override
  String get zone0Short => 'ゾーン0';

  @override
  String get zoneVShort => 'ゾーン V';

  @override
  String get zoneXShort => 'ゾーンX';

  @override
  String scanningCompleteFrames(int count) {
    return 'スキャン完了 —$countフレーム';
  }

  @override
  String get couldNotFinishScanning => 'スキャンを完了できませんでした。もう一度やり直してください。';

  @override
  String get processing => '処理…';

  @override
  String frameNumber(String number) {
    return 'フレーム$number';
  }

  @override
  String reviewingFrameTapLive(String number) {
    return '検討フレーム$number— タップしてライブスキャンします';
  }

  @override
  String get pauseAndReturn => '一時停止して戻る';

  @override
  String get filmFormatSection => 'フィルムフォーマット';

  @override
  String get negativeRawTooltip => 'ネガティブ（生）';

  @override
  String get positiveInvertedTooltip => '正（反転）';

  @override
  String get captureFramesToFinish => 'フレームをキャプチャして終了する';

  @override
  String get finishScanning => 'スキャンを終了する';

  @override
  String get historicalFramePositive => '履歴フレーム — ポジティブ プレビューとして保存';

  @override
  String get levelPhoneOverTable => '携帯電話をライトテーブルの上に水平に置きます';

  @override
  String get almostLevelHoldSteady => 'ほぼ水平 — 安定した状態を保つ';

  @override
  String get leveledFocusingNegative => '平準化 — ネガティブな部分に焦点を当てる…';

  @override
  String get focusedCapturingPositive => '集中 — 捕捉 (肯定的な見方)';

  @override
  String get focusedCapturingNegative => '集中 — 捉える（否定的な見方）';

  @override
  String mediumFormatDimensions(String dimensions) {
    return '中判・$dimensions';
  }

  @override
  String get imageNotAvailableOffline =>
      '画像はまだオフラインでは利用できません。ダウンロードを待つか、接続を確認してください。';

  @override
  String get couldNotShareImage => '画像を共有できませんでした。';

  @override
  String get photosAccessDenied => '写真ライブラリへのアクセスが拒否されました。設定で有効にします。';

  @override
  String get savedToPhotos => '写真に保存されました。';

  @override
  String get couldNotSaveToPhotos => '写真に保存できませんでした。';

  @override
  String get cannotRotateImageType => 'この画像タイプは回転できません。';

  @override
  String get monthJan => '1月';

  @override
  String get monthFeb => '2月';

  @override
  String get monthMar => '3月';

  @override
  String get monthApr => '4月';

  @override
  String get monthMay => '5月';

  @override
  String get monthJun => 'ジュン';

  @override
  String get monthJul => '7月';

  @override
  String get monthAug => '8月';

  @override
  String get monthSep => '9月';

  @override
  String get monthOct => '10月';

  @override
  String get monthNov => '11月';

  @override
  String get monthDec => '12月';

  @override
  String get dowSun => 'S';

  @override
  String get dowMon => 'M';

  @override
  String get dowTue => 'T';

  @override
  String get dowWed => 'W';

  @override
  String get dowThu => 'T';

  @override
  String get dowFri => 'F';

  @override
  String get dowSat => 'S';

  @override
  String get toggleOn => 'の上';

  @override
  String get toggleOff => 'オフ';

  @override
  String framesCapturedProgress(int captured, int max) {
    return '$captured / $max捕らえられた';
  }

  @override
  String format35mmDimensions(String dimensions) {
    return '35mm・$dimensions';
  }

  @override
  String get rotate90CounterClockwise => '反時計回りに 90°';

  @override
  String get rotate90Clockwise => '時計回りに90°';

  @override
  String get languageChooseTitle => '言語を選択してください';

  @override
  String get languageChooseSubtitle => 'AgXel で使う言語を選んでください。';
}

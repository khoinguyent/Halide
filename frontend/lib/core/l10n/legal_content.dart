import '../../config/app_config.dart';

typedef LegalSection = ({String title, String body});

/// Localized privacy and terms section bodies keyed by [languageCode] (`en`, `vi`).
abstract final class LegalContent {
  static String privacyLastUpdated(String languageCode) =>
      _isVi(languageCode) ? '6 tháng 4, 2026' : 'April 6, 2026';

  static String termsLastUpdated(String languageCode) =>
      _isVi(languageCode) ? '20 tháng 4, 2026' : 'April 20, 2026';

  static List<LegalSection> privacySections(String languageCode) =>
      _isVi(languageCode) ? _privacyVi : _privacyEn;

  static List<LegalSection> termsSections(String languageCode) =>
      _isVi(languageCode) ? _termsVi : _termsEn;

  static bool _isVi(String languageCode) => languageCode == 'vi';

  static final List<LegalSection> _privacyEn = [
    (
      title: '1. Overview',
      body:
          'This Privacy Policy explains how AgXel (“we”, “us”) collects, uses, shares, and protects information when you use our mobile application and related services (the “Service”). It should be read together with your app store terms and any in-app notices.\n\n'
          'If you do not agree with this Policy, please do not use the Service.',
    ),
    (
      title: '2. Information we collect',
      body:
          'Account & profile: email address, display name, and profile details you choose to provide; identifiers from sign-in providers (such as Apple, Google, or Facebook) when you use those options.\n\n'
          'Content & usage: film roll and gear data you enter, images and metadata you upload or sync, app interactions needed to provide features (for example sync status), and diagnostic data that helps us maintain reliability.\n\n'
          'Device & app: device type, OS version, app version, and similar technical data; where you allow it, approximate location or camera-related data used for features you turn on (such as exposure logging or metering).\n\n'
          'Purchases: subscription status and transaction identifiers as provided by Apple, Google, or our billing partner (for example RevenueCat)—we do not receive your full payment card number from those stores.\n\n'
          'Optional integrations: if you connect third-party services (such as Google Drive), we process information needed to perform the actions you request, in line with your permissions with that provider.',
    ),
    (
      title: '3. How we use information',
      body:
          'We use information to: provide, secure, and improve the Service; authenticate you; sync and store your content as you direct; process subscriptions; respond to support requests; detect abuse and fraud; comply with law; and communicate service-related messages.\n\n'
          'We do not sell your personal information. We do not use your photos for advertising profiling.',
    ),
    (
      title: '4. Legal bases (EEA/UK/Switzerland)',
      body:
          'Where GDPR or similar laws apply, we rely on: performance of a contract (providing the Service); legitimate interests (security, product improvement, aggregated analytics compatible with your rights); consent where required (for example certain optional features or marketing, if offered); and legal obligations.',
    ),
    (
      title: '5. Sharing',
      body:
          'We share information with service providers who process data on our behalf (for example hosting, authentication, billing validation, customer support tools), bound by appropriate contracts and safeguards.\n\n'
          'We may disclose information if required by law, to protect rights and safety, or as part of a merger or asset transfer with notice where required.\n\n'
          'Aggregated or de-identified information that cannot reasonably identify you may be used without restriction.',
    ),
    (
      title: '6. Retention',
      body:
          'We keep information as long as your account is active and as needed to provide the Service, unless a longer period is required by law or legitimate interests (for example security logs). You may request deletion as described below; some residual copies may persist for a short time in backups.',
    ),
    (
      title: '7. Security',
      body:
          'We use administrative, technical, and organizational measures designed to protect information. No method of transmission or storage is completely secure; we cannot guarantee absolute security.',
    ),
    (
      title: '8. International transfers',
      body:
          'We may process information in countries other than where you live. Where required, we use appropriate safeguards (such as standard contractual clauses) for transfers from the EEA, UK, or Switzerland.',
    ),
    (
      title: '9. Your choices & rights',
      body:
          'Depending on your location, you may have rights to access, correct, delete, or export personal information; object to or restrict certain processing; and withdraw consent where processing is consent-based. You may also lodge a complaint with a supervisory authority.\n\n'
          'You can manage many choices in the app or device settings (permissions, sign-in). To exercise rights, contact us through support channels listed in the app or on our site. We may verify your request as permitted by law.',
    ),
    (
      title: '10. Children',
      body:
          'The Service is not directed to children under the age required by your region to consent to data processing (often 13 or 16). We do not knowingly collect personal information from children in that category. If you believe we have, contact us and we will take appropriate steps.',
    ),
    (
      title: '11. California (U.S.)',
      body:
          'California residents may have additional rights under the CCPA/CPRA, including to know, delete, and opt out of certain sharing (we do not “sell” or “share” personal information as those terms are defined for cross-context behavioral advertising). You may designate an authorized agent where allowed by law.',
    ),
    (
      title: '12. Changes',
      body:
          'We may update this Policy and will revise the “Last updated” date. Material changes may be communicated through the app or email where appropriate.',
    ),
    (
      title: '13. Contact',
      body:
          'Questions about privacy: use the contact or support channel provided in the app or on our website, if listed.',
    ),
  ];

  static final List<LegalSection> _privacyVi = [
    (
      title: '1. Tổng quan',
      body:
          'Chính sách Bảo mật này giải thích cách AgXel (“chúng tôi”) thu thập, sử dụng, chia sẻ và bảo vệ thông tin khi bạn dùng ứng dụng di động và dịch vụ liên quan (“Dịch vụ”). Hãy đọc cùng điều khoản cửa hàng ứng dụng và thông báo trong ứng dụng.\n\n'
          'Nếu bạn không đồng ý với Chính sách này, vui lòng không sử dụng Dịch vụ.',
    ),
    (
      title: '2. Thông tin chúng tôi thu thập',
      body:
          'Tài khoản & hồ sơ: địa chỉ email, tên hiển thị và chi tiết hồ sơ bạn cung cấp; mã định danh từ nhà cung cấp đăng nhập (như Apple, Google hoặc Facebook) khi bạn dùng các tùy chọn đó.\n\n'
          'Nội dung & sử dụng: dữ liệu cuộn phim và thiết bị bạn nhập, ảnh và siêu dữ liệu bạn tải lên hoặc đồng bộ, tương tác ứng dụng cần thiết để cung cấp tính năng (ví dụ trạng thái đồng bộ), và dữ liệu chẩn đoán giúp duy trì độ tin cậy.\n\n'
          'Thiết bị & ứng dụng: loại thiết bị, phiên bản hệ điều hành, phiên bản ứng dụng và dữ liệu kỹ thuật tương tự; khi bạn cho phép, vị trí gần đúng hoặc dữ liệu liên quan camera dùng cho tính năng bạn bật (như ghi phơi sáng hoặc đo sáng).\n\n'
          'Mua hàng: trạng thái đăng ký và mã giao dịch do Apple, Google hoặc đối tác thanh toán (ví dụ RevenueCat) cung cấp — chúng tôi không nhận số thẻ thanh toán đầy đủ từ các cửa hàng đó.\n\n'
          'Tích hợp tùy chọn: nếu bạn kết nối dịch vụ bên thứ ba (như Google Drive), chúng tôi xử lý thông tin cần thiết để thực hiện hành động bạn yêu cầu, phù hợp quyền của bạn với nhà cung cấp đó.',
    ),
    (
      title: '3. Cách chúng tôi sử dụng thông tin',
      body:
          'Chúng tôi dùng thông tin để: cung cấp, bảo mật và cải thiện Dịch vụ; xác thực bạn; đồng bộ và lưu nội dung theo chỉ dẫn của bạn; xử lý đăng ký; phản hồi hỗ trợ; phát hiện lạm dụng và gian lận; tuân thủ pháp luật; và gửi thông báo liên quan dịch vụ.\n\n'
          'Chúng tôi không bán thông tin cá nhân của bạn. Chúng tôi không dùng ảnh của bạn để lập hồ sơ quảng cáo.',
    ),
    (
      title: '4. Cơ sở pháp lý (EEA/UK/Thụy Sĩ)',
      body:
          'Khi GDPR hoặc luật tương tự áp dụng, chúng tôi dựa vào: thực hiện hợp đồng (cung cấp Dịch vụ); lợi ích hợp pháp (bảo mật, cải thiện sản phẩm, phân tích tổng hợp tương thích quyền của bạn); đồng ý khi bắt buộc (ví dụ tính năng tùy chọn hoặc tiếp thị, nếu có); và nghĩa vụ pháp lý.',
    ),
    (
      title: '5. Chia sẻ',
      body:
          'Chúng tôi chia sẻ thông tin với nhà cung cấp dịch vụ xử lý dữ liệu thay mặt chúng tôi (ví dụ lưu trữ, xác thực, xác minh thanh toán, công cụ hỗ trợ), theo hợp đồng và biện pháp bảo vệ phù hợp.\n\n'
          'Chúng tôi có thể tiết lộ thông tin khi pháp luật yêu cầu, để bảo vệ quyền và an toàn, hoặc trong sáp nhập/chuyển nhượng tài sản với thông báo khi bắt buộc.\n\n'
          'Thông tin tổng hợp hoặc ẩn danh không thể nhận dạng hợp lý bạn có thể được dùng không hạn chế.',
    ),
    (
      title: '6. Lưu giữ',
      body:
          'Chúng tôi giữ thông tin khi tài khoản còn hoạt động và theo nhu cầu cung cấp Dịch vụ, trừ khi luật hoặc lợi ích hợp pháp yêu cầu lâu hơn (ví dụ nhật ký bảo mật). Bạn có thể yêu cầu xóa như mô tả bên dưới; một số bản sao dư có thể còn ngắn hạn trong sao lưu.',
    ),
    (
      title: '7. Bảo mật',
      body:
          'Chúng tôi dùng biện pháp hành chính, kỹ thuật và tổ chức nhằm bảo vệ thông tin. Không có phương thức truyền hoặc lưu trữ nào hoàn toàn an toàn; chúng tôi không thể đảm bảo bảo mật tuyệt đối.',
    ),
    (
      title: '8. Chuyển giao quốc tế',
      body:
          'Chúng tôi có thể xử lý thông tin ở quốc gia khác nơi bạn sống. Khi bắt buộc, chúng tôi dùng biện pháp bảo vệ phù hợp (như điều khoản hợp đồng tiêu chuẩn) cho chuyển giao từ EEA, UK hoặc Thụy Sĩ.',
    ),
    (
      title: '9. Lựa chọn & quyền của bạn',
      body:
          'Tùy vị trí, bạn có thể có quyền truy cập, sửa, xóa hoặc xuất thông tin cá nhân; phản đối hoặc hạn chế xử lý nhất định; và rút đồng ý khi xử lý dựa trên đồng ý. Bạn cũng có thể khiếu nại với cơ quan giám sát.\n\n'
          'Bạn có thể quản lý nhiều lựa chọn trong ứng dụng hoặc cài đặt thiết bị (quyền, đăng nhập). Để thực hiện quyền, liên hệ qua kênh hỗ trợ trong ứng dụng hoặc trên trang web. Chúng tôi có thể xác minh yêu cầu theo pháp luật.',
    ),
    (
      title: '10. Trẻ em',
      body:
          'Dịch vụ không hướng tới trẻ dưới độ tuổi khu vực bạn cần để đồng ý xử lý dữ liệu (thường 13 hoặc 16). Chúng tôi không cố ý thu thập thông tin cá nhân từ trẻ thuộc nhóm đó. Nếu bạn cho rằng chúng tôi đã làm vậy, hãy liên hệ để chúng tôi xử lý phù hợp.',
    ),
    (
      title: '11. California (Hoa Kỳ)',
      body:
          'Cư dân California có thể có quyền bổ sung theo CCPA/CPRA, gồm biết, xóa và từ chối chia sẻ nhất định (chúng tôi không “bán” hoặc “chia sẻ” thông tin cá nhân theo định nghĩa quảng cáo hành vi đa ngữ cảnh). Bạn có thể chỉ định đại diện được ủy quyền khi pháp luật cho phép.',
    ),
    (
      title: '12. Thay đổi',
      body:
          'Chúng tôi có thể cập nhật Chính sách và sửa ngày “Cập nhật lần cuối”. Thay đổi quan trọng có thể được thông báo qua ứng dụng hoặc email khi phù hợp.',
    ),
    (
      title: '13. Liên hệ',
      body:
          'Câu hỏi về bảo mật: dùng kênh liên hệ hoặc hỗ trợ trong ứng dụng hoặc trên trang web, nếu có.',
    ),
  ];

  static final List<LegalSection> _termsEn = [
    (
      title: '1. Licensed application (Apple Standard EULA)',
      body:
          'Apps distributed through the Apple App Store are licensed, not sold, to you. Your license to the AgXel iOS application is subject to your acceptance of Apple’s Licensed Application End User License Agreement (the “Standard EULA”), unless Apple offers a custom end user license agreement for the app.\n\n'
          'The full Standard EULA is published by Apple at:\n${AppConfig.appleStandardEulaUrl}\n\n'
          'For the AgXel app obtained from the App Store, the Standard EULA (and not a separate AgXel EULA) is the primary license agreement for the application as between you and Apple, as described in that document.',
    ),
    (
      title: '2. Supplemental terms (AgXel Service)',
      body:
          'The following sections are supplemental terms between you and AgXel regarding the AgXel mobile application and related online services (collectively, the “Service”). They apply in addition to the Apple Standard EULA (where applicable), your app store’s rules, and our Privacy Policy. If you do not agree, do not use the Service.\n\n'
          'We may update these supplemental terms from time to time. We will indicate the “Last updated” date at the bottom of this screen. Continued use after changes constitutes acceptance of the revised terms, except where applicable law requires additional consent.',
    ),
    (
      title: '3. The Service',
      body:
          'AgXel helps you manage analog film photography workflows, including gear and roll tracking, exposure-related tools, optional cloud sync of your content, and integrations you enable (such as linked cloud storage). Features may differ by platform or subscription tier.\n\n'
          'We may add, change, or discontinue features with reasonable notice where practicable. The Service is provided for personal, non-commercial use unless we agree otherwise in writing.',
    ),
    (
      title: '4. Accounts & eligibility',
      body:
          'You must provide accurate registration information and keep your credentials secure. You are responsible for activity under your account. You must be old enough to enter a binding contract where you live (and at least the age required by your app store). Notify us promptly if you suspect unauthorized access.',
    ),
    (
      title: '5. Acceptable use',
      body:
          'You agree not to misuse the Service. Without limitation, you must not: violate law or third-party rights; attempt to probe, scan, or test vulnerabilities; interfere with or overload the Service; use automated means to scrape or bulk-collect data without permission; reverse engineer except as allowed by law; upload malware; impersonate others; or use the Service to harass or harm others.\n\n'
          'We may suspend or terminate access for violations or risk to the Service or other users.',
    ),
    (
      title: '6. Your content',
      body:
          'You retain ownership of content you submit (for example roll metadata, images, and notes). To operate the Service, you grant AgXel a worldwide, non-exclusive license to host, process, transmit, display, and back up your content solely to provide and improve the Service for you, including security and abuse prevention.\n\n'
          'You represent that you have the rights needed to upload your content and that it does not infringe others’ rights. Exposure and metering tools are informational; you remain responsible for creative and technical decisions in the field.',
    ),
    (
      title: '7. Subscriptions & purchases',
      body:
          'Paid features may be offered through in-app purchases processed by Apple App Store, Google Play, or other platforms. Pricing, renewal, cancellation, and refunds are governed by the applicable store’s policies and your payment provider. Subscription status may be validated through our billing partner (for example RevenueCat).\n\n'
          'If a payment fails or a subscription ends, access to paid features may change in line with your account status.',
    ),
    (
      title: '8. Third-party services',
      body:
          'The Service may rely on or link to third parties (including authentication, analytics, cloud infrastructure, storage providers, and optional integrations such as Google Drive). Their use is subject to their respective terms and privacy policies. We are not responsible for third-party services we do not control.',
    ),
    (
      title: '9. Disclaimers',
      body:
          'THE SERVICE IS PROVIDED “AS IS” AND “AS AVAILABLE” WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT, TO THE MAXIMUM EXTENT PERMITTED BY LAW.\n\n'
          'We do not guarantee uninterrupted or error-free operation. Tools that rely on device sensors or estimates (such as light metering) are approximate and depend on conditions and hardware; they are not a substitute for professional judgment or dedicated hardware where required.',
    ),
    (
      title: '10. Limitation of liability',
      body:
          'TO THE MAXIMUM EXTENT PERMITTED BY LAW, AGXEL AND ITS AFFILIATES, DIRECTORS, EMPLOYEES, AND SUPPLIERS WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS, DATA, OR GOODWILL, ARISING OUT OF OR RELATED TO THE SERVICE OR THESE SUPPLEMENTAL TERMS.\n\n'
          'OUR TOTAL LIABILITY FOR ANY CLAIM ARISING OUT OF THE SERVICE OR THESE SUPPLEMENTAL TERMS IS LIMITED TO THE GREATER OF (A) THE AMOUNTS YOU PAID US FOR THE SERVICE IN THE TWELVE (12) MONTHS BEFORE THE CLAIM OR (B) FIFTY U.S. DOLLARS (US\$50), EXCEPT WHERE PROHIBITED BY LAW.',
    ),
    (
      title: '11. Indemnity',
      body:
          'You will defend and indemnify AgXel and its affiliates against third-party claims and costs (including reasonable attorneys’ fees) arising from your content, your use of the Service, or your violation of these supplemental terms or applicable law, except to the extent caused by our willful misconduct.',
    ),
    (
      title: '12. Termination',
      body:
          'You may stop using the Service at any time. We may suspend or terminate access if you breach these supplemental terms, if we must comply with law, or to protect the Service or users. Provisions that by their nature should survive (including ownership, disclaimers, limitations, and indemnity) will survive termination.',
    ),
    (
      title: '13. Governing law & disputes',
      body:
          'Unless mandatory local law requires otherwise, these supplemental terms are governed by the laws applicable in your primary place of residence’s jurisdiction for consumer contracts, without regard to conflict-of-law rules. Courts in that jurisdiction may have exclusive jurisdiction over disputes, unless you have mandatory rights elsewhere.',
    ),
    (
      title: '14. Contact',
      body:
          'Questions about these supplemental terms: use the contact or support channel provided in the app or on our website, if listed.',
    ),
  ];

  static final List<LegalSection> _termsVi = [
    (
      title: '1. Ứng dụng được cấp phép (EULA tiêu chuẩn Apple)',
      body:
          'Ứng dụng phân phối qua Apple App Store được cấp phép, không bán, cho bạn. Giấy phép ứng dụng AgXel iOS phụ thuộc việc bạn chấp nhận Thỏa thuận Cấp phép Người dùng Cuối Ứng dụng được Cấp phép của Apple (“EULA tiêu chuẩn”), trừ khi Apple cung cấp EULA tùy chỉnh cho ứng dụng.\n\n'
          'EULA tiêu chuẩn đầy đủ do Apple công bố tại:\n${AppConfig.appleStandardEulaUrl}\n\n'
          'Với ứng dụng AgXel từ App Store, EULA tiêu chuẩn (không phải EULA AgXel riêng) là thỏa thuận cấp phép chính cho ứng dụng giữa bạn và Apple, như mô tả trong tài liệu đó.',
    ),
    (
      title: '2. Điều khoản bổ sung (Dịch vụ AgXel)',
      body:
          'Các mục sau là điều khoản bổ sung giữa bạn và AgXel về ứng dụng di động AgXel và dịch vụ trực tuyến liên quan (gọi chung là “Dịch vụ”). Chúng áp dụng cùng EULA tiêu chuẩn Apple (nếu có), quy tắc cửa hàng ứng dụng và Chính sách Bảo mật. Nếu không đồng ý, đừng dùng Dịch vụ.\n\n'
          'Chúng tôi có thể cập nhật điều khoản bổ sung theo thời gian. Ngày “Cập nhật lần cuối” ở cuối màn hình. Tiếp tục dùng sau thay đổi đồng nghĩa chấp nhận điều khoản sửa đổi, trừ khi pháp luật yêu cầu đồng ý thêm.',
    ),
    (
      title: '3. Dịch vụ',
      body:
          'AgXel giúp bạn quản lý quy trình nhiếp ảnh phim analog, gồm theo dõi thiết bị và cuộn phim, công cụ phơi sáng, đồng bộ đám mây tùy chọn và tích hợp bạn bật (như lưu trữ đám mây liên kết). Tính năng có thể khác theo nền tảng hoặc gói đăng ký.\n\n'
          'Chúng tôi có thể thêm, đổi hoặc ngừng tính năng với thông báo hợp lý khi khả thi. Dịch vụ dành cho dùng cá nhân, phi thương mại trừ khi chúng tôi đồng ý khác bằng văn bản.',
    ),
    (
      title: '4. Tài khoản & đủ điều kiện',
      body:
          'Bạn phải cung cấp thông tin đăng ký chính xác và bảo mật thông tin đăng nhập. Bạn chịu trách nhiệm hoạt động dưới tài khoản. Bạn phải đủ tuổi ký hợp đồng ràng buộc tại nơi cư trú (và ít nhất độ tuổi cửa hàng ứng dụng yêu cầu). Thông báo ngay nếu nghi ngờ truy cập trái phép.',
    ),
    (
      title: '5. Sử dụng chấp nhận được',
      body:
          'Bạn đồng ý không lạm dụng Dịch vụ. Không giới hạn, bạn không được: vi phạm pháp luật hoặc quyền bên thứ ba; thăm dò, quét hoặc thử lỗ hổng; cản trở hoặc quá tải Dịch vụ; dùng phương tiện tự động thu thập dữ liệu hàng loạt không được phép; reverse engineer trừ khi pháp luật cho phép; tải malware; mạo danh; hoặc dùng Dịch vụ quấy rối hoặc gây hại.\n\n'
          'Chúng tôi có thể tạm ngừng hoặc chấm dứt quyền truy cập khi vi phạm hoặc rủi ro cho Dịch vụ hoặc người dùng khác.',
    ),
    (
      title: '6. Nội dung của bạn',
      body:
          'Bạn giữ quyền sở hữu nội dung gửi (ví dụ siêu dữ liệu cuộn, ảnh và ghi chú). Để vận hành Dịch vụ, bạn cấp AgXel giấy phép toàn cầu, không độc quyền lưu trữ, xử lý, truyền, hiển thị và sao lưu nội dung chỉ để cung cấp và cải thiện Dịch vụ cho bạn, gồm bảo mật và chống lạm dụng.\n\n'
          'Bạn cam kết có quyền tải nội dung và không vi phạm quyền người khác. Công cụ phơi sáng và đo sáng mang tính tham khảo; bạn vẫn chịu trách nhiệm quyết định sáng tạo và kỹ thuật tại hiện trường.',
    ),
    (
      title: '7. Đăng ký & mua hàng',
      body:
          'Tính năng trả phí có thể qua mua trong ứng dụng do Apple App Store, Google Play hoặc nền tảng khác xử lý. Giá, gia hạn, hủy và hoàn tiền theo chính sách cửa hàng và nhà cung cấp thanh toán. Trạng thái đăng ký có thể được xác minh qua đối tác thanh toán (ví dụ RevenueCat).\n\n'
          'Nếu thanh toán thất bại hoặc đăng ký kết thúc, quyền truy cập tính năng trả phí có thể thay đổi theo trạng thái tài khoản.',
    ),
    (
      title: '8. Dịch vụ bên thứ ba',
      body:
          'Dịch vụ có thể dựa hoặc liên kết bên thứ ba (gồm xác thực, phân tích, hạ tầng đám mây, lưu trữ và tích hợp tùy chọn như Google Drive). Việc dùng tuân theo điều khoản và chính sách bảo mật của họ. Chúng tôi không chịu trách nhiệm dịch vụ bên thứ ba ngoài tầm kiểm soát.',
    ),
    (
      title: '9. Tuyên bố miễn trừ',
      body:
          'DỊCH VỤ ĐƯỢC CUNG CẤP “NGUYÊN TRẠNG” VÀ “SẴN CÓ” KHÔNG CÓ BẢO ĐẢM DƯỚI MỌI HÌNH THỨC, DÙ RÕ RÀNG HAY NGỤ Ý, GỒM KHẢ NĂNG THƯƠNG MẠI, PHÙ HỢP MỤC ĐÍCH CỤ THỂ VÀ KHÔNG VI PHẠM, TRONG PHẠM VI PHÁP LUẬT CHO PHÉP.\n\n'
          'Chúng tôi không đảm bảo vận hành liên tục hoặc không lỗi. Công cụ dựa cảm biến hoặc ước lượng (như đo sáng) là gần đúng và phụ thuộc điều kiện và phần cứng; không thay thế phán đoán chuyên nghiệp hoặc thiết bị chuyên dụng khi cần.',
    ),
    (
      title: '10. Giới hạn trách nhiệm',
      body:
          'TRONG PHẠM VI PHÁP LUẬT CHO PHÉP, AGXEL VÀ CÔNG TY LIÊN KẾT, GIÁM ĐỐC, NHÂN VIÊN VÀ NHÀ CUNG CẤP KHÔNG CHỊU TRÁCH NHIỆM VỀ THIỆT HẠI GIÁN TIẾP, NGẪU NHIÊN, ĐẶC BIỆT, HẬU QUẢ HOẶC TRỪNG PHẠT, HOẶC MẤT LỢI NHUẬN, DỮ LIỆU HOẶC UY TÍN, PHÁT SINH TỪ HOẶC LIÊN QUAN DỊCH VỤ HOẶC ĐIỀU KHOẢN BỔ SUNG NÀY.\n\n'
          'TỔNG TRÁCH NHIỆM CỦA CHÚNG TÔI VỚI MỌI KHIẾU NẠI PHÁT SINH TỪ DỊCH VỤ HOẶC ĐIỀU KHOẢN BỔ SUNG NÀY GIỚI HẠN Ở MỨC CAO HƠN (A) SỐ TIỀN BẠN ĐÃ TRẢ CHO DỊCH VỤ TRONG MƯỜI HAI (12) THÁNG TRƯỚC KHIẾU NẠI HOẶC (B) NĂM MƯƠI ĐÔ LA MỸ (US\$50), TRỪ KHI PHÁP LUẬT CẤM.',
    ),
    (
      title: '11. Bồi thường',
      body:
          'Bạn sẽ bảo vệ và bồi thường AgXel và công ty liên kết trước khiếu nại và chi phí bên thứ ba (gồm phí luật sư hợp lý) phát sinh từ nội dung, việc dùng Dịch vụ hoặc vi phạm điều khoản bổ sung hoặc pháp luật, trừ phần do hành vi cố ý của chúng tôi.',
    ),
    (
      title: '12. Chấm dứt',
      body:
          'Bạn có thể ngừng dùng Dịch vụ bất cứ lúc nào. Chúng tôi có thể tạm ngừng hoặc chấm dứt quyền truy cập nếu bạn vi phạm điều khoản bổ sung, phải tuân thủ pháp luật, hoặc để bảo vệ Dịch vụ hoặc người dùng. Điều khoản theo bản chất cần tồn tại (gồm sở hữu, miễn trừ, giới hạn và bồi thường) vẫn có hiệu lực sau chấm dứt.',
    ),
    (
      title: '13. Luật điều chỉnh & tranh chấp',
      body:
          'Trừ khi pháp luật địa phương bắt buộc khác, điều khoản bổ sung này tuân theo luật áp dụng tại nơi cư trú chính của bạn cho hợp đồng tiêu dùng, không xét xung đột pháp luật. Tòa án tại khu vực đó có thể có thẩm quyền độc quyền, trừ khi bạn có quyền bắt buộc ở nơi khác.',
    ),
    (
      title: '14. Liên hệ',
      body:
          'Câu hỏi về điều khoản bổ sung: dùng kênh liên hệ hoặc hỗ trợ trong ứng dụng hoặc trên trang web, nếu có.',
    ),
  ];
}

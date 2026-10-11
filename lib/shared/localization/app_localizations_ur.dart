// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appName => 'کلاس کھاتہ';

  @override
  String get loading => 'لوڈ ہو رہا ہے…';

  @override
  String get save => 'محفوظ کریں';

  @override
  String get cancel => 'منسوخ کریں';

  @override
  String get delete => 'حذف کریں';

  @override
  String get edit => 'ترمیم کریں';

  @override
  String get add => 'شامل کریں';

  @override
  String get search => 'تلاش کریں';

  @override
  String get next => 'اگلا';

  @override
  String get back => 'پچھلا';

  @override
  String get finish => 'مکمل کریں';

  @override
  String get confirm => 'تصدیق کریں';

  @override
  String get yes => 'ہاں';

  @override
  String get no => 'نہیں';

  @override
  String get close => 'بند کریں';

  @override
  String get submit => 'جمع کریں';

  @override
  String get print => 'پرنٹ کریں';

  @override
  String get export => 'برآمد کریں';

  @override
  String get import => 'درآمد کریں';

  @override
  String get refresh => 'تازہ کریں';

  @override
  String get navDashboard => 'ڈیش بورڈ';

  @override
  String get navStudents => 'طلباء';

  @override
  String get navFees => 'فیس';

  @override
  String get navPayroll => 'تنخواہ';

  @override
  String get navInventory => 'انوینٹری';

  @override
  String get navReports => 'رپورٹس';

  @override
  String get navSettings => 'ترتیبات';

  @override
  String get loginTitle => 'کلاس کھاتہ میں خوش آمدید';

  @override
  String get loginSubtitle => 'جاری رکھنے کے لیے سائن ان کریں';

  @override
  String get email => 'ای میل';

  @override
  String get password => 'پاس ورڈ';

  @override
  String get signIn => 'سائن ان';

  @override
  String get forgotPassword => 'پاس ورڈ بھول گئے؟';

  @override
  String get loginFailed => 'ای میل یا پاس ورڈ غلط ہے۔';

  @override
  String accountLocked(int minutes) {
    return 'اکاؤنٹ مقفل ہے۔ $minutes منٹ بعد کوشش کریں۔';
  }

  @override
  String get setupTitle => 'کلاس کھاتہ میں خوش آمدید';

  @override
  String get setupSubtitle => 'چند آسان مراحل میں اپنی اکیڈمی ترتیب دیں۔';

  @override
  String get setupStep1 => 'اکیڈمی پروفائل';

  @override
  String get setupStep2 => 'ایڈمن اکاؤنٹ';

  @override
  String get setupStep3 => 'بازیابی کلید';

  @override
  String get academyName => 'اکیڈمی کا نام';

  @override
  String get academyTagline => 'ٹیگ لائن (اختیاری)';

  @override
  String get academyPhone => 'فون نمبر';

  @override
  String get academyAddress => 'پتہ';

  @override
  String get adminName => 'آپ کا نام';

  @override
  String get adminEmail => 'ایڈمن ای میل';

  @override
  String get adminPassword => 'پاس ورڈ';

  @override
  String get confirmPassword => 'پاس ورڈ کی تصدیق کریں';

  @override
  String get passwordMismatch => 'پاس ورڈ مطابقت نہیں رکھتا۔';

  @override
  String get passwordTooShort => 'پاس ورڈ کم از کم 8 حروف کا ہونا چاہیے۔';

  @override
  String get recoveryKeyTitle => 'اپنی بازیابی کلید محفوظ کریں';

  @override
  String get recoveryKeyWarning =>
      'یہ کلید صرف ایک بار دکھائی جائے گی۔ اسے محفوظ جگہ پر رکھیں — گم ہونے پر دوبارہ نہیں مل سکتی۔';

  @override
  String get recoveryKeyCopied => 'بازیابی کلید کلپ بورڈ پر کاپی ہو گئی۔';

  @override
  String get setupComplete => 'سیٹ اپ مکمل';

  @override
  String get setupCompleteMsg => 'کلاس کھاتہ استعمال کے لیے تیار ہے۔';

  @override
  String get statusPaid => 'ادا شدہ';

  @override
  String get statusPending => 'زیر التواء';

  @override
  String get statusOverdue => 'مدت گزری';

  @override
  String get statusPartial => 'جزوی';

  @override
  String get statusActive => 'فعال';

  @override
  String get statusInactive => 'غیر فعال';

  @override
  String get errorUnexpected => 'غیر متوقع غلطی ہوئی۔ دوبارہ کوشش کریں۔';

  @override
  String get errorPermission => 'آپ کو یہ کام کرنے کی اجازت نہیں ہے۔';

  @override
  String get errorDatabase => 'ڈیٹا بیس میں غلطی ہوئی۔ سپورٹ سے رابطہ کریں۔';

  @override
  String get errorValidation => 'نشان زدہ خانوں کو چیک کریں۔';

  @override
  String get currency => 'روپے';

  @override
  String get noData => 'کوئی ڈیٹا نہیں ملا۔';

  @override
  String get confirmDeleteTitle => 'حذف کرنے کی تصدیق';

  @override
  String get confirmDeleteMessage =>
      'کیا آپ واقعی اس آئٹم کو حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں ہو سکتا۔';

  @override
  String get backupSuccess => 'بیک اپ کامیابی سے بنایا گیا۔';

  @override
  String get backupFailed => 'بیک اپ ناکام ہوا۔ دوبارہ کوشش کریں۔';

  @override
  String get restoreSuccess => 'ڈیٹا بیس کامیابی سے بحال ہوا۔';

  @override
  String get restoreFailed => 'بحالی ناکام ہوئی۔ بیک اپ فائل خراب ہو سکتی ہے۔';

  @override
  String get auditIntegrityOk => 'آڈٹ لاگ کی سالمیت جانچ کامیاب رہی۔';

  @override
  String get auditIntegrityFailed =>
      'آڈٹ لاگ کی سالمیت جانچ ناکام ہوئی۔ لاگ سے چھیڑ چھاڑ ہو سکتی ہے۔';

  @override
  String trialDaysRemaining(int days) {
    return 'آپ کے ٹرائل میں $days دن باقی ہیں۔';
  }

  @override
  String get trialExpired => 'آپ کا ٹرائل ختم ہو گیا ہے۔ لائسنس فعال کریں۔';

  @override
  String get licenseActive => 'لائسنس فعال ہے۔';

  @override
  String get autoLockMessage => 'سیشن غیر فعالیت کی وجہ سے مقفل ہو گیا۔';

  @override
  String get unlockSession => 'سیشن کھولیں';
}

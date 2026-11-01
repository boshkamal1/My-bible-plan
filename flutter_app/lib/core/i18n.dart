bool gEn = false;

const Map<String, List<String>> _m = {
  'appName': ['رحلة الكتاب المقدس', 'Bible Journey'],
  'home': ['الرئيسية', 'Home'],
  'plan': ['الخطة', 'Plan'],
  'books': ['الأسفار', 'Books'],
  'stats': ['الإنجاز', 'Progress'],
  'more': ['المزيد', 'More'],
  'today': ['النهاردة', 'Today'],
  'day': ['يوم', 'Day'],
  'of': ['من', 'of'],
  'chapters': ['أصحاحات', 'chapters'],
  'chapter': ['أصحاح', 'Chapter'],
  'psalm': ['مزمور', 'Psalm'],
  'readNow': ['اقرأ الآن', 'Read now'],
  'markDone': ['تم القراءة', 'Mark as read'],
  'markUndone': ['إلغاء القراءة', 'Mark unread'],
  'allDone': ['خلصت قراية اليوم', "Today's reading is done"],
  'streak': ['أيام متتالية', 'Day streak'],
  'bestStreak': ['أطول سلسلة', 'Best streak'],
  'streakRisk': [
    'سلسلتك في خطر! اقرأ النهاردة',
    'Your streak is at risk! Read today'
  ],
  'settings': ['الإعدادات', 'Settings'],
  'language': ['اللغة', 'Language'],
  'arabic': ['العربية', 'Arabic'],
  'english': ['English', 'English'],
  'translation': ['الترجمة', 'Translation'],
  'svd': ['فان دايك (عربي)', 'Van Dyck (Arabic)'],
  'kjv': ['الملك جيمس (إنجليزي)', 'King James (English)'],
  'fontSize': ['حجم الخط', 'Font size'],
  'theme': ['المظهر', 'Theme'],
  'themeLight': ['فاتح', 'Light'],
  'themeDark': ['داكن', 'Dark'],
  'themeSystem': ['حسب الجهاز', 'System'],
  'reminders': ['التذكيرات', 'Reminders'],
  'dailyReminder': ['تذكير يومي', 'Daily reminder'],
  'streakReminder': [
    'تنبيه السلسلة (المساء)',
    'Streak-at-risk alert (evening)'
  ],
  'reminderTime': ['وقت التذكير', 'Reminder time'],
  'account': ['الحساب', 'Account'],
  'signIn': ['تسجيل الدخول', 'Sign in'],
  'signInGoogle': ['الدخول بحساب جوجل', 'Continue with Google'],
  'signOut': ['تسجيل الخروج', 'Sign out'],
  'email': ['البريد الإلكتروني', 'Email'],
  'password': ['كلمة المرور', 'Password'],
  'register': ['إنشاء حساب', 'Create account'],
  'cloudOff': [
    'المزامنة السحابية غير مفعّلة في هذه النسخة',
    'Cloud sync is not configured in this build'
  ],
  'synced': ['تمت المزامنة', 'Synced'],
  'syncNow': ['زامن الآن', 'Sync now'],
  'deleteAccount': ['حذف الحساب وبياناتي', 'Delete account and my data'],
  'deleteConfirm': [
    'هيتم حذف حسابك وبياناتك السحابية نهائيًا. متأكد؟',
    'Your account and cloud data will be permanently deleted. Sure?'
  ],
  'resetData': ['مسح بيانات الجهاز', 'Erase on-device data'],
  'privacy': ['سياسة الخصوصية', 'Privacy policy'],
  'cancel': ['إلغاء', 'Cancel'],
  'ok': ['تمام', 'OK'],
  'save': ['حفظ', 'Save'],
  'delete': ['حذف', 'Delete'],
  'search': ['بحث', 'Search'],
  'searchHint': ['ابحث في النص…', 'Search the text…'],
  'noResults': ['مفيش نتائج', 'No results'],
  'notes': ['ملاحظاتي', 'My notes'],
  'favorites': ['المفضلة', 'Favorites'],
  'highlights': ['التمييز', 'Highlights'],
  'addNote': ['أضف ملاحظة', 'Add note'],
  'note': ['ملاحظة', 'Note'],
  'favorite': ['مفضلة', 'Favorite'],
  'highlight': ['تمييز', 'Highlight'],
  'copy': ['نسخ', 'Copy'],
  'share': ['مشاركة', 'Share'],
  'shareProgress': ['شارك إنجازك', 'Share progress'],
  'listen': ['استماع', 'Listen'],
  'stop': ['إيقاف', 'Stop'],
  'speed': ['السرعة', 'Speed'],
  'readyPlans': ['خطط جاهزة', 'Ready plans'],
  'groups': ['المجموعات', 'Groups'],
  'createGroup': ['إنشاء مجموعة', 'Create group'],
  'joinGroup': ['انضمام بكود', 'Join with code'],
  'groupName': ['اسم المجموعة', 'Group name'],
  'groupCode': ['كود المجموعة', 'Group code'],
  'members': ['الأعضاء', 'Members'],
  'leave': ['مغادرة', 'Leave'],
  'needSignIn': ['سجّل الدخول الأول', 'Please sign in first'],
  'badges': ['الأوسمة', 'Badges'],
  'readingTime': ['وقت القراءة', 'Reading time'],
  'minutes': ['دقيقة', 'min'],
  'last30': ['آخر ٣٠ يوم', 'Last 30 days'],
  'chaptersRead': ['أصحاحات مقروءة', 'Chapters read'],
  'daysLeft': ['يوم متبقي', 'days left'],
  'buffer': ['أيام احتياطية', 'Buffer days'],
  'useBuffer': ['فعّل يوم احتياطي', 'Use a buffer day'],
  'redistribute': ['وزّع الأصحاحات', 'Redistribute chapters'],
  'redistributed': [
    'اتوزعت الأصحاحات على الأيام الجاية',
    'Chapters redistributed'
  ],
  'bufferUsed': ['اتفعّل يوم احتياطي', 'Buffer day used'],
  'undo': ['تراجع', 'Undo'],
  'newJourney': ['رحلة جديدة', 'New journey'],
  'setup': ['إعداد الخطة', 'Plan setup'],
  'scope': ['هتقرا إيه؟', 'What to read?'],
  'ot': ['العهد القديم', 'Old Testament'],
  'nt': ['العهد الجديد', 'New Testament'],
  'all': ['الكتاب المقدس كامل', 'Whole Bible'],
  'seq': ['واحد بعد التاني', 'One after the other'],
  'mix': ['القديم والجديد مع بعض', 'Both together'],
  'order': ['الترتيب', 'Order'],
  'finishIn': ['عايز تخلص إمتى؟', 'When to finish?'],
  'inDays': ['خلال عدد أيام', 'In N days'],
  'byDate': ['في تاريخ معين', 'By a date'],
  'daysCount': ['عدد الأيام', 'Number of days'],
  'endDate': ['تاريخ النهاية', 'End date'],
  'startFrom': ['وصلت لفين؟', 'Where are you now?'],
  'fromStart': ['من البداية', 'From the beginning'],
  'skipBooks': ['أسفار مش هقراها', 'Books to skip'],
  'start': ['ابدأ', 'Start'],
  'perDay': ['تقريبًا في اليوم', 'about per day'],
  'deutBooks': ['الأسفار القانونية الثانية', 'Deuterocanonical books'],
  'bookGroup_moses': ['أسفار موسى', 'Books of Moses'],
  'bookGroup_history': ['الأسفار التاريخية', 'Historical books'],
  'bookGroup_wisdom': ['أسفار الحكمة', 'Wisdom books'],
  'bookGroup_prophets': ['الأنبياء', 'Prophets'],
  'bookGroup_deut': ['القانونية الثانية', 'Deuterocanon'],
  'bookGroup_gospels': ['الأناجيل وأعمال الرسل', 'Gospels & Acts'],
  'bookGroup_paul': ['رسائل بولس', 'Paul’s letters'],
  'bookGroup_general': [
    'الرسائل العامة والرؤيا',
    'General letters & Revelation'
  ],
  'deutNoteAr': [
    'النص العربي لهذا السفر غير متاح بعد، بيظهر بالإنجليزية (KJV).',
    'Arabic text for this book is not bundled yet; showing KJV.'
  ],
  'prev': ['السابق', 'Previous'],
  'next': ['التالي', 'Next'],
  'done': ['تمت', 'Done'],
  'ofBook': ['من السفر', 'of book'],
  'notifDailyTitle': ['وقت القراءة', 'Reading time'],
  'notifDailyBody': ['قراية النهاردة مستنياك', "Today's reading is waiting"],
  'notifRiskTitle': ['السلسلة في خطر', 'Streak at risk'],
  'notifRiskBody': [
    'لسه ما قريتش النهاردة. خمس دقايق كفاية.',
    "You haven't read today. Five minutes is enough."
  ],
  'verses': ['آيات', 'verses'],
  'shareText': [
    'أنا ماشي في رحلة الكتاب المقدس',
    "I'm on my Bible reading journey"
  ],
  'widgetNone': ['افتح التطبيق لتبدأ', 'Open the app to start'],
  'welcome': ['أهلاً بيك', 'Welcome'],
  'welcomeSub': [
    'ابدأ رحلة قراءة منتظمة في الكتاب المقدس',
    'Start a steady Bible reading journey'
  ],
  'planDone': ['خلصت الخطة! 🎉', 'Plan completed! 🎉'],
  'copied': ['اتنسخ', 'Copied'],
  'yes': ['أيوه', 'Yes'],
  'no': ['لأ', 'No'],
  'restartPlan': ['ابدأ خطة جديدة', 'Start a new plan'],
  'restartConfirm': [
    'هتتمسح الخطة الحالية. متأكد؟',
    'The current plan will be replaced. Sure?'
  ],
  'error': ['حصلت مشكلة', 'Something went wrong'],
  'members0': ['مفيش أعضاء', 'No members'],
  'useGroupPlan': ['استخدم خطة المجموعة', 'Use group plan'],
  'chapterShort': ['أص', 'ch'],
  'readToday': ['قريت النهاردة', 'Read today'],
  'notReadToday': ['لسه', 'Not yet'],
};

String tr(String k) {
  final v = _m[k];
  if (v == null) return k;
  return gEn ? v[1] : v[0];
}

const String _arDigits = '٠١٢٣٤٥٦٧٨٩';
String nf(int n) {
  if (gEn) return '$n';
  return '$n'.split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : _arDigits[d];
  }).join();
}

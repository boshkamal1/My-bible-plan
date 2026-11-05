import 'package:flutter/material.dart';

import '../core/i18n.dart';
import 'theme.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  String _device = 'android';

  String _t(String ar, String en) => gEn ? en : ar;

  @override
  Widget build(BuildContext context) {
    final steps = switch (_device) {
      'ios' => [
          _StepData(
            '1',
            'افتح الموقع في Safari',
            'افتح mybibleplan.web.app باستخدام متصفح Safari على iPhone أو iPad.',
            'Open the site in Safari',
            'Visit mybibleplan.web.app in Safari on your iPhone or iPad.',
            _Picture.share,
          ),
          _StepData(
            '2',
            'اضغط مشاركة',
            'اضغط زر المشاركة أسفل الشاشة، ثم اختر «إضافة إلى الشاشة الرئيسية».',
            'Tap Share',
            'Tap the Share button, then choose “Add to Home Screen”.',
            _Picture.menu,
          ),
          _StepData(
            '3',
            'أضف التطبيق',
            'اترك خيار «فتح كتطبيق ويب» مفعّلًا، ثم اضغط «إضافة». ستجد الأيقونة على الشاشة الرئيسية.',
            'Add the app',
            'Keep “Open as Web App” enabled and tap “Add”. The app icon will appear on your Home Screen.',
            _Picture.home,
          ),
        ],
      'desktop' => [
          _StepData(
            '1',
            'افتح الموقع في Chrome أو Edge',
            'اكتب mybibleplan.web.app في شريط العنوان.',
            'Open the site in Chrome or Edge',
            'Go to mybibleplan.web.app in your browser.',
            _Picture.browser,
          ),
          _StepData(
            '2',
            'اختر تثبيت التطبيق',
            'في Chrome اضغط أيقونة التثبيت بجوار شريط العنوان، أو من قائمة المتصفح اختر «تثبيت My Bible Plan». في Edge: التطبيقات ← تثبيت هذا الموقع كتطبيق.',
            'Choose Install app',
            'In Chrome, use the install icon by the address bar or choose “Install My Bible Plan” from the menu. In Edge, choose Apps → Install this site as an app.',
            _Picture.menu,
          ),
          _StepData(
            '3',
            'افتحه من جهازك',
            'سيظهر التطبيق في قائمة التطبيقات، ويمكنك تثبيته على شريط المهام أو سطح المكتب.',
            'Open it from your computer',
            'Find it in your apps list, then pin it to your taskbar or desktop if you like.',
            _Picture.home,
          ),
        ],
      _ => [
          _StepData(
            '1',
            'افتح الموقع في Chrome',
            'افتح mybibleplan.web.app على هاتف Android باستخدام متصفح Chrome.',
            'Open the site in Chrome',
            'Visit mybibleplan.web.app on your Android phone using Chrome.',
            _Picture.browser,
          ),
          _StepData(
            '2',
            'افتح قائمة المتصفح',
            'اضغط قائمة النقاط الثلاث أعلى الشاشة، ثم اختر «تثبيت التطبيق» أو «إضافة إلى الشاشة الرئيسية».',
            'Open the browser menu',
            'Tap the three-dot menu, then choose “Install app” or “Add to Home screen”.',
            _Picture.menu,
          ),
          _StepData(
            '3',
            'أكد التثبيت',
            'اضغط «تثبيت» أو «إضافة». ستظهر أيقونة My Bible Plan على الشاشة الرئيسية.',
            'Confirm installation',
            'Tap “Install” or “Add”. My Bible Plan will appear on your Home Screen.',
            _Picture.home,
          ),
        ],
    };

    return Scaffold(
      appBar: AppBar(title: Text(_t('التنزيل', 'Download'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            children: [
              Icon(Icons.install_mobile, size: 48, color: kGold),
              const SizedBox(height: 10),
              Text(
                _t('نزّل My Bible Plan على جهازك',
                    'Get My Bible Plan on your device'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'ثبّت الموقع كتطبيق من غير متجر، وافتحه بعد كده من أيقونته مباشرة.',
                  'Install the website as an app without an app store, then open it from its icon.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  _deviceChoice('android', 'Android', Icons.android),
                  _deviceChoice('ios', 'iPhone / iPad', Icons.phone_iphone),
                  _deviceChoice(
                      'desktop', _t('كمبيوتر', 'Computer'), Icons.computer),
                ],
              ),
              const SizedBox(height: 20),
              for (final step in steps) _StepCard(data: step, t: _t),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lightbulb_outline, color: kGold),
                  title: Text(_t('مش ظاهر عندك خيار التثبيت؟',
                      'Can’t see an install option?')),
                  subtitle: Text(
                    _t(
                      'تأكد إنك فاتح الرابط في المتصفح المناسب ومتصّل بالإنترنت. على iPhone استخدم Safari، وعلى الكمبيوتر جرّب Chrome أو Edge.',
                      'Make sure you are using a supported browser and are online. On iPhone, use Safari; on a computer, try Chrome or Edge.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(_t('الرجوع إلى الموقع', 'Back to the website')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deviceChoice(String value, String label, IconData icon) => ChoiceChip(
        selected: _device == value,
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onSelected: (_) => setState(() => _device = value),
      );
}

class _StepData {
  const _StepData(
    this.number,
    this.arTitle,
    this.arBody,
    this.enTitle,
    this.enBody,
    this.picture,
  );
  final String number;
  final String arTitle;
  final String arBody;
  final String enTitle;
  final String enBody;
  final _Picture picture;
}

enum _Picture { browser, share, menu, home }

class _StepCard extends StatelessWidget {
  const _StepCard({required this.data, required this.t});
  final _StepData data;
  final String Function(String, String) t;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 570;
    final picture = _StepPicture(kind: data.picture);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.number}  ${t(data.arTitle, data.enTitle)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 7),
        Text(t(data.arBody, data.enBody)),
      ],
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 14), picture],
              )
            : Row(
                children: [
                  picture,
                  const SizedBox(width: 18),
                  Expanded(child: copy),
                ],
              ),
      ),
    );
  }
}

class _StepPicture extends StatelessWidget {
  const _StepPicture({required this.kind});
  final _Picture kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPhone = kind != _Picture.browser;
    return Container(
      width: isPhone ? 190 : 230,
      height: 118,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: switch (kind) {
        _Picture.browser => _browserArt(scheme),
        _Picture.share => _shareArt(scheme),
        _Picture.menu => _menuArt(scheme),
        _Picture.home => _homeArt(scheme),
      },
    );
  }

  Widget _browserArt(ColorScheme scheme) => Column(
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_back, size: 15),
              const SizedBox(width: 7),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('mybibleplan.web.app',
                      style: TextStyle(fontSize: 9)),
                ),
              ),
              const Icon(Icons.download_for_offline_outlined,
                  size: 18, color: kGold),
            ],
          ),
          const Spacer(),
          const Icon(Icons.auto_stories, size: 35, color: kGold),
          const SizedBox(height: 4),
          const Text('My Bible Plan',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const Spacer(),
        ],
      );

  Widget _shareArt(ColorScheme scheme) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Icon(Icons.phone_iphone, size: 48, color: kGold),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ios_share, color: scheme.primary),
              const SizedBox(height: 5),
              const Text('Share', style: TextStyle(fontSize: 10)),
              const Icon(Icons.arrow_downward, size: 17, color: kGold),
              const Text('Add to Home Screen', style: TextStyle(fontSize: 9)),
            ],
          ),
        ],
      );

  Widget _menuArt(ColorScheme scheme) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const Icon(Icons.more_vert, size: 35, color: kGold),
          Container(
            width: 122,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 8)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('New tab', style: TextStyle(fontSize: 9)),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: kGold.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.install_mobile, size: 13, color: kGold),
                      SizedBox(width: 4),
                      Expanded(
                          child: Text('Install app',
                              style: TextStyle(fontSize: 9))),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                const Text('Settings', style: TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ],
      );

  Widget _homeArt(ColorScheme scheme) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _appIcon(),
              const SizedBox(width: 16),
              Icon(Icons.calendar_month, size: 31, color: scheme.primary),
              const SizedBox(width: 16),
              Icon(Icons.photo_library, size: 31, color: scheme.tertiary),
            ],
          ),
          const SizedBox(height: 7),
          const Text('My Bible Plan', style: TextStyle(fontSize: 10)),
        ],
      );

  Widget _appIcon() => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: kGold.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.auto_stories, color: kGold),
      );
}

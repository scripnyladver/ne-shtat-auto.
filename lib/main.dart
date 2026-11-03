
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontFeature;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _bg = Color(0xFF080A0F);
const _panel = Color(0xFF171C26);
const _accentDefault = Color(0xFF8B7CFF);
const _media = MethodChannel('ru.neshtat.autocockpit/media');

void main() => runApp(const NeShtatApp());

class NeShtatApp extends StatefulWidget {
  const NeShtatApp({super.key});

  @override
  State<NeShtatApp> createState() => _NeShtatAppState();
}

class _NeShtatAppState extends State<NeShtatApp> {
  Color accent = _accentDefault;
  bool animations = true;
  bool showSplash = true;
  double glass = .72;
  String themeName = 'Purple Glass';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      accent = Color(p.getInt('accent') ?? _accentDefault.value);
      animations = p.getBool('animations') ?? true;
      showSplash = p.getBool('splash') ?? true;
      glass = p.getDouble('glass') ?? .72;
      themeName = p.getString('theme') ?? 'Purple Glass';
    });
  }

  Future<void> save(String key, Object value) async =>
      (await SharedPreferences.getInstance())
          .setString(key, value.toString());

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'НЕ ШТАТ Auto Cockpit',
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: _bg,
          colorScheme: ColorScheme.dark(
            primary: accent,
            secondary: accent,
          ),
        ),
        home: CockpitHome(
          accent: accent,
          animations: animations,
          glass: glass,
          themeName: themeName,
          onAccent: (v) async {
            setState(() => accent = v);
            final p = await SharedPreferences.getInstance();
            await p.setInt('accent', v.value);
          },
          onAnimations: (v) async {
            setState(() => animations = v);
            final p = await SharedPreferences.getInstance();
            await p.setBool('animations', v);
          },
          onGlass: (v) async {
            setState(() => glass = v);
            final p = await SharedPreferences.getInstance();
            await p.setDouble('glass', v);
          },
          onTheme: (v) async {
            setState(() => themeName = v);
            final p = await SharedPreferences.getInstance();
            await p.setString('theme', v);
          },
          showSplash: showSplash,
          onSplash: (v) async {
            setState(() => showSplash = v);
            final p = await SharedPreferences.getInstance();
            await p.setBool('splash', v);
          },
        ),
      );
}

class CockpitHome extends StatefulWidget {
  const CockpitHome({
    super.key,
    required this.accent,
    required this.animations,
    required this.glass,
    required this.themeName,
    required this.onAccent,
    required this.onAnimations,
    required this.onGlass,
    required this.onTheme,
    required this.showSplash,
    required this.onSplash,
  });

  final Color accent;
  final bool animations;
  final double glass;
  final String themeName;
  final bool showSplash;

  final ValueChanged<Color> onAccent;
  final ValueChanged<bool> onAnimations;
  final ValueChanged<double> onGlass;
  final ValueChanged<String> onTheme;
  final ValueChanged<bool> onSplash;

  @override
  State<CockpitHome> createState() => _CockpitHomeState();
}

class _CockpitHomeState extends State<CockpitHome>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  bool _splashDone = false;
  bool editing = false;
  int page = 0;

  String activeAssistant = 'Алиса';
  String track = 'Медиаплеер не подключён';
  String artist = 'Разреши доступ к медиасессиям';
  bool playing = false;

  List<String> widgets = [
    'clock',
    'weather',
    'music',
    'navigation',
    'battery',
  ];

  final Map<String, int> sizes = {
    'clock': 1,
    'weather': 2,
    'music': 2,
    'navigation': 1,
    'battery': 1,
  };

  Timer? _clock;
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();

    if (widget.showSplash) {
      _intro.forward().then((_) {
        if (mounted) setState(() => _splashDone = true);
      });
    } else {
      _splashDone = true;
    }

    _refreshMedia();
    _loadLayout();

    _clock = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _wiggle.dispose();
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _refreshMedia() async {
    try {
      final s = await _media.invokeMapMethod<String, dynamic>('state');

      if (!mounted || s == null) return;

      setState(() {
        track = (s['title'] as String?)?.isNotEmpty == true
            ? s['title'] as String
            : 'Нет активного трека';

        artist = (s['artist'] as String?) ??
            'Открой музыкальное приложение';

        playing = s['playing'] == true;
      });
    } on PlatformException {
      // Медиасессия пока недоступна.
    }
  }

  Future<void> _mediaAction(String action) async {
    try {
      await _media.invokeMethod(action);
      await Future.delayed(const Duration(milliseconds: 250));
      await _refreshMedia();
    } catch (_) {
      if (mounted) {
        _snack(
          'Нет доступной медиасессии. Открой Яндекс Музыку и разреши доступ.',
        );
      }
    }
  }

  void _snack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _panel,
      ),
    );
  }

  void _toggleEditing() {
    setState(() => editing = !editing);

    if (editing) {
      _wiggle.repeat(reverse: true);
    } else {
      _wiggle.stop();
      _wiggle.value = 0;
    }
  }

  Future<void> _openNavi() async {
    final uri = Uri.parse('yandexnavi://');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('Яндекс Навигатор не найден.');
    }
  }

  Future<void> _openMusic() async {
    try {
      await _media.invokeMethod('openMusic');
    } catch (_) {
      await launchUrl(
        Uri.parse('https://music.yandex.ru'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return _Splash(controller: _intro);
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final landscape = c.maxWidth > c.maxHeight;

            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-.8, -.9),
                        radius: 1.5,
                        colors: [
                          widget.accent.withOpacity(.16),
                          _bg,
                          _bg,
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    _topBar(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: widget.animations
                            ? const Duration(milliseconds: 300)
                            : Duration.zero,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(.025, 0),
                              end: Offset.zero,
                            ).animate(a),
                            child: child,
                          ),
                        ),
                        child: page == 0
                            ? _dashboard(landscape)
                            : page == 1
                                ? _musicPage()
                                : page == 2
                                    ? _settingsPage()
                                    : _themePage(),
                      ),
                    ),
                    _bottomBar(),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'НЕ ШТАТ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'AUTO COCKPIT',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 3,
                    color: widget.accent,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: _toggleEditing,
              icon: Icon(
                editing ? Icons.check : Icons.tune,
                color: widget.accent,
              ),
              tooltip: editing ? 'Завершить' : 'Редактировать экран',
            ),
            IconButton(
              onPressed: () => setState(() => page = 2),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      );

  Widget _bottomBar() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        child: Row(
          children: [
            _navIcon(Icons.grid_view_rounded, 0),
            _navIcon(Icons.music_note_rounded, 1),
            _navIcon(Icons.palette_outlined, 3),
            const Spacer(),
            Text(
              DateFormatLike.time(now),
              style: const TextStyle(
                color: Colors.white54,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );

  Widget _navIcon(IconData i, int p) => IconButton(
        onPressed: () => setState(() => page = p),
        icon: Icon(
          i,
          color: page == p ? widget.accent : Colors.white54,
        ),
      );

  Widget _dashboard(bool landscape) {
    final cols = landscape ? 3 : 2;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ТВОЙ КОКПИТ',
                style: TextStyle(
                  color: Colors.white.withOpacity(.5),
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              if (editing)
                Text(
                  'РЕЖИМ РЕДАКТИРОВАНИЯ',
                  style: TextStyle(
                    color: widget.accent,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth =
                  (constraints.maxWidth - 10 * (cols - 1)) / cols;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widgets.map((id) {
                  final size = sizes[id] ?? 1;
                  final wide = size >= 3;
                  final width = wide ? constraints.maxWidth : cellWidth;

                  final height = size == 1
                      ? 126.0
                      : size == 2
                          ? 154.0
                          : size == 3
                              ? 150.0
                              : 205.0;

                  return SizedBox(
                    width: width,
                    height: height,
                    child: LongPressDraggable<String>(
                      data: id,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: _widgetCard(id, true),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: .22,
                        child: _widgetCard(id, false),
                      ),
                      onDragStarted: () {
                        setState(() => editing = true);
                        if (!_wiggle.isAnimating) {
                          _wiggle.repeat(reverse: true);
                        }
                      },
                      child: DragTarget<String>(
                        onWillAcceptWithDetails: (d) => d.data != id,
                        onAcceptWithDetails: (d) {
                          setState(() {
                            final old = widgets.indexOf(d.data);
                            final target = widgets.indexOf(id);

                            if (old >= 0) {
                              widgets.removeAt(old);
                              widgets.insert(target, d.data);
                            }
                          });

                          _saveLayout();
                        },
                        builder: (c, can, rej) => _widgetCard(
                          id,
                          editing,
                          highlight: can.isNotEmpty,
                          onTap: () => _widgetTap(id),
                          onEdit: () => _editWidget(id),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (editing)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'Удерживай и перетаскивай карточки. '
                'Нажми на карандаш, чтобы изменить размер.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openNavi,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Навигация'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openMusic,
                  icon: const Icon(Icons.library_music),
                  label: const Text('Открыть музыку'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double cWidth(BuildContext c) => MediaQuery.of(c).size.width;

  Future<void> _loadLayout() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getStringList('widgets');
    final raw = p.getString('widgetSizes');

    if (mounted) {
      setState(() {
        if (saved != null && saved.isNotEmpty) {
          widgets = saved;
        }

        if (raw != null) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;

          for (final e in decoded.entries) {
            sizes[e.key] = (e.value as num).toInt();
          }
        }
      });
    }
  }

  Future<void> _saveLayout() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('widgets', widgets);
    await p.setString('widgetSizes', jsonEncode(sizes));
  }

  Widget _widgetCard(
    String id,
    bool wobble, {
    bool highlight = false,
    VoidCallback? onTap,
    VoidCallback? onEdit,
  }) {
    final child = Container(
      decoration: BoxDecoration(
        color: _panel.withOpacity(widget.glass),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlight
              ? widget.accent
              : Colors.white.withOpacity(.07),
          width: highlight ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accent.withOpacity(.07),
            blurRadius: 22,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: _widgetContent(id),
    );

    return AnimatedBuilder(
      animation: _wiggle,
      builder: (context, _) {
        final angle = wobble
            ? math.sin(_wiggle.value * math.pi * 2) * .012
            : 0.0;

        return Transform.rotate(
          angle: angle,
          child: GestureDetector(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned.fill(child: child),
                if (wobble)
                  Positioned(
                    right: 6,
                    top: 5,
                    child: IconButton(
                      icon: Icon(
                        Icons.edit,
                        size: 17,
                        color: widget.accent,
                      ),
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _widgetContent(String id) {
    switch (id) {
      case 'clock':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormatLike.time(now),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            Text(
              DateFormatLike.date(now),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        );

      case 'weather':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.cloud_outlined, size: 28),
            SizedBox(height: 5),
            Text(
              '--°',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Погода: настройка API',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        );

      case 'music':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
      

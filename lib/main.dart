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
      (await SharedPreferences.getInstance()).setString(key, value.toString());

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'НЕ ШТАТ Auto Cockpit',
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: _bg,
          colorScheme: ColorScheme.dark(primary: accent, secondary: accent),
        ),
        home: CockpitHome(
          accent: accent,
          animations: animations,
          glass: glass,
          themeName: themeName,
          onAccent: (v) async { setState(() => accent = v); final p = await SharedPreferences.getInstance(); await p.setInt('accent', v.value); },
          onAnimations: (v) async { setState(() => animations = v); final p = await SharedPreferences.getInstance(); await p.setBool('animations', v); },
          onGlass: (v) async { setState(() => glass = v); final p = await SharedPreferences.getInstance(); await p.setDouble('glass', v); },
          onTheme: (v) async { setState(() => themeName = v); final p = await SharedPreferences.getInstance(); await p.setString('theme', v); },
          showSplash: showSplash,
          onSplash: (v) async { setState(() => showSplash = v); final p = await SharedPreferences.getInstance(); await p.setBool('splash', v); },
        ),
      );
}

class CockpitHome extends StatefulWidget {
  const CockpitHome({super.key, required this.accent, required this.animations, required this.glass, required this.themeName, required this.onAccent, required this.onAnimations, required this.onGlass, required this.onTheme, required this.showSplash, required this.onSplash});
  final Color accent; final bool animations; final double glass; final String themeName; final bool showSplash;
  final ValueChanged<Color> onAccent; final ValueChanged<bool> onAnimations; final ValueChanged<double> onGlass; final ValueChanged<String> onTheme; final ValueChanged<bool> onSplash;
  @override State<CockpitHome> createState() => _CockpitHomeState();
}

class _CockpitHomeState extends State<CockpitHome> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _wiggle = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  bool _splashDone = false;
  bool editing = false;
  int page = 0;
  String activeAssistant = 'Алиса';
  String track = 'Медиаплеер не подключён';
  String artist = 'Разреши доступ к медиасессиям';
  bool playing = false;
  List<String> widgets = ['clock','weather','music','navigation','battery'];
  final Map<String,int> sizes = {'clock':1,'weather':2,'music':2,'navigation':1,'battery':1};
  Timer? _clock;
  DateTime now = DateTime.now();

  @override void initState() { super.initState(); if (widget.showSplash) { _intro.forward().then((_) { if(mounted) setState(()=>_splashDone=true); }); } else { _splashDone=true; } _refreshMedia(); _loadLayout(); _clock=Timer.periodic(const Duration(seconds:1),(_)=>setState(()=>now=DateTime.now())); }
  @override void dispose(){_intro.dispose();_wiggle.dispose();_clock?.cancel();super.dispose();}

  Future<void> _refreshMedia() async { try { final s=await _media.invokeMapMethod<String,dynamic>('state'); if(!mounted||s==null)return; setState(() { track = (s['title'] as String?)?.isNotEmpty == true ? s['title'] as String : 'Нет активного трека'; artist = (s['artist'] as String?) ?? 'Открой музыкальное приложение'; playing = s['playing'] == true; }); } on PlatformException { } }
  Future<void> _mediaAction(String action) async { try { await _media.invokeMethod(action); await Future.delayed(const Duration(milliseconds:250)); await _refreshMedia(); } catch (_) { if(mounted) _snack('Нет доступной медиасессии. Открой Яндекс Музыку и разреши доступ.'); } }
  void _snack(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),behavior:SnackBarBehavior.floating,backgroundColor:_panel));
  void _toggleEditing() { setState(() => editing = !editing); if (editing) { _wiggle.repeat(reverse: true); } else { _wiggle.stop(); _wiggle.value = 0; } }
  Future<void> _openNavi() async { final uri=Uri.parse('yandexnavi://'); if(await canLaunchUrl(uri)){await launchUrl(uri,mode:LaunchMode.externalApplication);}else{_snack('Яндекс Навигатор не найден.');} }
  Future<void> _openMusic() async { try { await _media.invokeMethod('openMusic'); } catch (_) { await launchUrl(Uri.parse('https://music.yandex.ru'), mode: LaunchMode.externalApplication); } }

  @override Widget build(BuildContext context){
    if(!_splashDone) return _Splash(controller:_intro);
    return Scaffold(body: SafeArea(child: LayoutBuilder(builder:(context,c){final landscape=c.maxWidth>c.maxHeight; return Stack(children:[
      Positioned.fill(child: DecoratedBox(decoration:BoxDecoration(gradient:RadialGradient(center:const Alignment(-.8,-.9),radius:1.5,colors:[widget.accent.withOpacity(.16),_bg,_bg])))),
      Column(children:[_topBar(),Expanded(child:AnimatedSwitcher(duration:widget.animations?const Duration(milliseconds:300):Duration.zero,transitionBuilder:(child,a)=>FadeTransition(opacity:a,child:SlideTransition(position:Tween(begin:const Offset(.025,0),end:Offset.zero).animate(a),child:child)),child:page==0?_dashboard(landscape):page==1?_musicPage():page==2?_settingsPage():_themePage())),_bottomBar()]),
    ]);} )));
  }
  Widget _topBar()=>Padding(padding:const EdgeInsets.fromLTRB(20,14,20,12),child:Row(children:[Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('НЕ ШТАТ',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,letterSpacing:2,color:Colors.white)),Text('AUTO COCKPIT',style:TextStyle(fontSize:9,letterSpacing:3,color:widget.accent))]),const Spacer(),IconButton(onPressed:_toggleEditing,icon:Icon(editing?Icons.check:Icons.tune,color:widget.accent),tooltip:editing?'Завершить':'Редактировать экран'),IconButton(onPressed:()=>setState(()=>page=2),icon:const Icon(Icons.settings_outlined))]));
  Widget _bottomBar()=>Padding(padding:const EdgeInsets.fromLTRB(18,8,18,10),child:Row(children:[_navIcon(Icons.grid_view_rounded,0),_navIcon(Icons.music_note_rounded,1),_navIcon(Icons.palette_outlined,3),const Spacer(),Text(DateFormatLike.time(now),style:TextStyle(color:Colors.white54,fontFeatures:const [FontFeature.tabularFigures()]))]));
  Widget _navIcon(IconData i,int p)=>IconButton(onPressed:()=>setState(()=>page=p),icon:Icon(i,color:page==p?widget.accent:Colors.white54));

  Widget _dashboard(bool landscape) {
    final cols = landscape ? 3 : 2;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('ТВОЙ КОКПИТ', style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 11, letterSpacing: 2)),
          const Spacer(),
          if (editing) Text('РЕЖИМ РЕДАКТИРОВАНИЯ', style: TextStyle(color: widget.accent, fontSize: 9, letterSpacing: 1)),
        ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final cellWidth = (constraints.maxWidth - 10 * (cols - 1)) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: widgets.map((id) {
            final size = sizes[id] ?? 1;
            final wide = size >= 3;
            final width = wide ? constraints.maxWidth : cellWidth;
            final height = size == 1 ? 126.0 : size == 2 ? 154.0 : size == 3 ? 150.0 : 205.0;
            return SizedBox(width: width, height: height, child: LongPressDraggable<String>(
              data: id,
              feedback: Material(color: Colors.transparent, child: SizedBox(width: width, height: height, child: _widgetCard(id, true))),
              childWhenDragging: Opacity(opacity: .22, child: _widgetCard(id, false)),
              onDragStarted: () { setState(() => editing = true); if (!_wiggle.isAnimating) _wiggle.repeat(reverse: true); },
              child: DragTarget<String>(
                onWillAcceptWithDetails: (d) => d.data != id,
                onAcceptWithDetails: (d) {
                  setState(() {
                    final old = widgets.indexOf(d.data);
                    final target = widgets.indexOf(id);
                    if (old >= 0) { widgets.removeAt(old); widgets.insert(target, d.data); }
                  });
                  _saveLayout();
                },
                builder: (c, can, rej) => _widgetCard(id, editing, highlight: can.isNotEmpty,
                  onTap: () => _widgetTap(id), onEdit: () => _editWidget(id)),
              ),
            ));
          }).toList());
        }),
        if (editing) Padding(padding: const EdgeInsets.only(top: 14), child: Text(
          'Удерживай и перетаскивай карточки. Нажми на карандаш, чтобы изменить размер.',
          style: TextStyle(color: Colors.white54, fontSize: 11))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _openNavi, icon: const Icon(Icons.navigation), label: const Text('Навигация'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: _openMusic, icon: const Icon(Icons.library_music), label: const Text('Открыть музыку'))),
        ]),
      ]),
    );
  }
  double cWidth(BuildContext c)=>MediaQuery.of(c).size.width;
  Future<void> _loadLayout() async { final p=await SharedPreferences.getInstance(); final saved=p.getStringList('widgets'); final raw=p.getString('widgetSizes'); if(mounted) setState(() { if(saved!=null && saved.isNotEmpty) widgets=saved; if(raw!=null) { final decoded=jsonDecode(raw) as Map<String,dynamic>; for(final e in decoded.entries) { sizes[e.key]=(e.value as num).toInt(); } } }); }
  Future<void> _saveLayout() async {final p=await SharedPreferences.getInstance();await p.setStringList('widgets',widgets);await p.setString('widgetSizes',jsonEncode(sizes));}
  Widget _widgetCard(String id,bool wobble,{bool highlight=false,VoidCallback? onTap,VoidCallback? onEdit}){final child=Container(decoration:BoxDecoration(color:_panel.withOpacity(widget.glass),borderRadius:BorderRadius.circular(22),border:Border.all(color:highlight?widget.accent:Colors.white.withOpacity(.07),width:highlight?2:1),boxShadow:[BoxShadow(color:widget.accent.withOpacity(.07),blurRadius:22)]),padding:const EdgeInsets.all(14),child:_widgetContent(id));return AnimatedBuilder(animation:_wiggle,builder:(context,_) { final angle = wobble ? math.sin(_wiggle.value * math.pi * 2) * .012 : 0.0; return Transform.rotate(angle:angle,child:GestureDetector(onTap:onTap,child:Stack(children:[Positioned.fill(child:child),if(wobble)Positioned(right:6,top:5,child:IconButton(icon:Icon(Icons.edit,size:17,color:widget.accent),onPressed:onEdit,visualDensity:VisualDensity.compact))]))); });}
  Widget _widgetContent(String id){switch(id){case'clock':return Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(DateFormatLike.time(now),style:const TextStyle(fontSize:30,fontWeight:FontWeight.w700,letterSpacing:-1)),Text(DateFormatLike.date(now),style:const TextStyle(color:Colors.white54,fontSize:11))]);case'weather':return Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.cloud_outlined,size:28),const SizedBox(height:5),const Text('--°',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold)),const Text('Погода: настройка API',style:TextStyle(color:Colors.white54,fontSize:10))]);case'music':return Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.graphic_eq,size:25),const SizedBox(height:4),Text(track,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w600)),Text(artist,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white54,fontSize:10)),const SizedBox(height:4),Row(children:[_mini(Icons.skip_previous,()=>_mediaAction('previous')),_mini(playing?Icons.pause:Icons.play_arrow,()=>_mediaAction('playPause')),_mini(Icons.skip_next,()=>_mediaAction('next'))])]);case'navigation':return InkWell(onTap:_openNavi,child:const Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.navigation_outlined,size:29),SizedBox(height:8),Text('Навигация',style:TextStyle(fontWeight:FontWeight.w600)),Text('Открыть Яндекс',style:TextStyle(color:Colors.white54,fontSize:10))]));default:return Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.battery_5_bar,size:28),const SizedBox(height:7),const Text('Батарея',style:TextStyle(fontWeight:FontWeight.w600)),const Text('Уровень телефона',style:TextStyle(color:Colors.white54,fontSize:10))]);}}
  Widget _mini(IconData i,VoidCallback f)=>IconButton(onPressed:f,icon:Icon(i,size:18,color:widget.accent),padding:EdgeInsets.zero,constraints:const BoxConstraints.tightFor(width:32,height:28));
  void _widgetTap(String id){if(id=='music')setState(()=>page=1);if(id=='navigation')_openNavi();}
  void _editWidget(String id) {
    showModalBottomSheet(
      context: context, backgroundColor: _panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Виджет: $id', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16), const Text('Размер'),
          Wrap(spacing: 8, children: [1, 2, 3, 4].map((v) => ChoiceChip(
            label: Text(['S', 'M', 'L', 'XL'][v - 1]), selected: (sizes[id] ?? 1) == v,
            onSelected: (_) { setState(() => sizes[id] = v); _saveLayout(); Navigator.pop(c); },
          )).toList()),
          const SizedBox(height: 10),
          TextButton.icon(onPressed: () { setState(() => widgets.remove(id)); _saveLayout(); Navigator.pop(c); },
            icon: const Icon(Icons.delete_outline), label: const Text('Удалить виджет')),
        ]),
      ),
    );
  }
  Widget _musicPage()=>SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('МУЗЫКА',style:TextStyle(letterSpacing:2,color:Colors.white54)),const SizedBox(height:24),Container(width:double.infinity,padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(28)),child:Column(children:[Container(width:170,height:170,decoration:BoxDecoration(color:widget.accent.withOpacity(.18),borderRadius:BorderRadius.circular(24)),child:Icon(Icons.album,size:90,color:widget.accent)),const SizedBox(height:22),Text(track,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold),textAlign:TextAlign.center),Text(artist,style:const TextStyle(color:Colors.white54),textAlign:TextAlign.center),const SizedBox(height:20),Row(mainAxisAlignment:MainAxisAlignment.center,children:[IconButton(onPressed:()=>_mediaAction('previous'),icon:const Icon(Icons.skip_previous,size:34)),IconButton(onPressed:()=>_mediaAction('playPause'),icon:Icon(playing?Icons.pause_circle:Icons.play_circle,size:60,color:widget.accent)),IconButton(onPressed:()=>_mediaAction('next'),icon:const Icon(Icons.skip_next,size:34))]),FilledButton.tonal(onPressed:()=>_media.invokeMethod('openAccess'),child:const Text('Разрешить управление музыкой')),TextButton(onPressed:_openMusic,child:const Text('Открыть Яндекс Музыку'))]))]));
  Widget _settingsPage()=>ListView(padding:const EdgeInsets.all(20),children:[const Text('НАСТРОЙКИ',style:TextStyle(letterSpacing:2,color:Colors.white54)),const SizedBox(height:14),SwitchListTile(title:const Text('Плавные анимации'),subtitle:const Text('Переходы и эффекты интерфейса'),value:widget.animations,onChanged:widget.onAnimations),SwitchListTile(title:const Text('Стартовая заставка'),value:widget.showSplash,onChanged:widget.onSplash),ListTile(title:const Text('Помощник'),subtitle:Text(activeAssistant),trailing:DropdownButton<String>(value:activeAssistant,items:['Алиса','ChatGPT'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(s)=>setState(()=>activeAssistant=s??'Алиса'))),ListTile(title:const Text('Яндекс Навигатор'),subtitle:const Text('Запуск установленного приложения'),trailing:IconButton(onPressed:_openNavi,icon:const Icon(Icons.open_in_new))),ListTile(title:const Text('Управление медиасессиями'),subtitle:const Text('Разрешение Android для кнопок музыки'),trailing:IconButton(onPressed:()=>_media.invokeMethod('openAccess'),icon:const Icon(Icons.open_in_new))),const Divider(),ListTile(title:const Text('О приложении'),subtitle:const Text('НЕ ШТАТ Auto Cockpit · 0.1.1'))]);
  Widget _themePage()=>ListView(padding:const EdgeInsets.all(20),children:[const Text('THEME STUDIO',style:TextStyle(letterSpacing:2,color:Colors.white54)),const SizedBox(height:20),const Text('Готовые темы'),Wrap(spacing:8,runSpacing:8,children:[('Purple Glass',_accentDefault),('Ice Blue',const Color(0xFF63C9FF)),('Cyber Red',const Color(0xFFFF526D)),('Graphite',const Color(0xFF9AA4B2))].map((e)=>ChoiceChip(label:Text(e.$1),selected:widget.themeName==e.$1,onSelected:(_){widget.onTheme(e.$1);widget.onAccent(e.$2);})).toList()),const SizedBox(height:24),const Text('Цвет акцента'),Wrap(spacing:12,children:[_accentDefault,const Color(0xFF63C9FF),const Color(0xFFFF526D),const Color(0xFF55D6A5),const Color(0xFFFFB45B),Colors.white].map((c)=>GestureDetector(onTap:()=>widget.onAccent(c),child:Container(width:38,height:38,decoration:BoxDecoration(color:c,shape:BoxShape.circle,border:Border.all(color:Colors.white24,width:2))))).toList()),const SizedBox(height:24),Text('Прозрачность стекла ${(widget.glass*100).round()}%'),Slider(value:widget.glass,min:.25,max:.95,onChanged:widget.onGlass),const SizedBox(height:12),const Text('Фон обложки и расширенная настройка градиентов появятся в следующем этапе интеграции.')]);
}

  class _Splash extends StatelessWidget {const _Splash({required this.controller});final AnimationController controller;@override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,body:Center(child:AnimatedBuilder(animation:controller,builder:(c,_){final t=Curves.easeInOutCubic.transform(controller.value);return Opacity(opacity:t,child:Column(mainAxisSize:MainAxisSize.min,children:[ShaderMask(shaderCallback:(r)=>LinearGradient(begin:Alignment(-1+2*controller.value,-1),end:Alignment(1,1),colors:const [Color(0xFF555B65),Color(0xFFFFFFFF),Color(0xFF8A929D),Color(0xFFFFFFFF),Color(0xFF4B515B)],stops:const [0,.3,.5,.7,1]).createShader(r),child:const Text('НЕ ШТАТ',style:TextStyle(fontSize:38,fontWeight:FontWeight.w900,letterSpacing:4,color:Colors.white))),const SizedBox(height:8),Opacity(opacity:(t*1.4).clamp(0,1),child:const Text('(AUTO)',style:TextStyle(color:Color(0xFFBFC5CF),fontSize:12,letterSpacing:6,fontWeight:FontWeight.w500)))]));})));}

class DateFormatLike {static String time(DateTime d)=>'${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';static String date(DateTime d)=>'${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';}

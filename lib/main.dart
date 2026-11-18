import '/custom_code/actions/index.dart' as actions;
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'auth/supabase_auth/supabase_user_provider.dart';
import 'auth/supabase_auth/auth_util.dart';

import '/backend/supabase/supabase.dart';
import '/flutter_flow/hulp_colors.dart';
import '/flutter_flow/hulp_text_styles.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/internationalization.dart';
import 'flutter_flow/nav/nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  // La app apunta a Android 15, que dibuja de borde a borde sin pedir
  // permiso: el contenido pasa por debajo de la barra de estado. Sin decirle
  // nada, la barra quedaba negra y no se veían ni la hora ni la batería.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  final environmentValues = FFDevEnvironmentValues();
  await environmentValues.initialize();

  // Start initial custom actions code
  await actions.initializeOneSignal();
  // End initial custom actions code

  await SupaFlow.initialize();

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  ThemeMode _themeMode = ThemeMode.system;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<BaseAuthUser> userStream;

  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = talentoHulpSupabaseUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
      });
    jwtTokenStream.listen((_) {});
    Future.delayed(
      Duration(milliseconds: 1000),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
  }

  void setLocale(String language) {
    safeSetState(() => _locale = createLocale(language));
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Talento Hulp',
      scrollBehavior: MyAppScrollBehavior(),
      localizationsDelegates: [
        FFLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      locale: _locale,
      supportedLocales: const [
        Locale('es'),
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
        primaryColor: HulpColors.brand,
        colorScheme: const ColorScheme.light(
          primary: HulpColors.brand,
          secondary: HulpColors.brand,
          surface: HulpColors.surface,
          error: HulpColors.error,
        ),
        scaffoldBackgroundColor: HulpColors.background,
        textTheme: HulpTextStyles.textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: HulpColors.background,
          foregroundColor: HulpColors.textPrimary,
          centerTitle: true,
          toolbarHeight: 72,
          leadingWidth: 56,
          iconTheme: IconThemeData(
            color: HulpColors.textPrimary,
            size: 24,
          ),
          actionsIconTheme: IconThemeData(
            color: HulpColors.textPrimary,
            size: 24,
          ),
          titleTextStyle: HulpTextStyles.header,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          ),
          shape: const Border(
            bottom: BorderSide(color: HulpColors.border),
          ),
        ),
        cardTheme: CardThemeData(
          color: HulpColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: HulpColors.border),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: HulpColors.border,
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: HulpColors.inputSurface,
          hintStyle: HulpTextStyles.help,
          helperStyle: HulpTextStyles.help,
          helperMaxLines: 2,
          errorStyle: HulpTextStyles.fieldError,
          errorMaxLines: 3,
          iconColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.error)) return HulpColors.error;
            if (states.contains(WidgetState.focused)) return HulpColors.brand;
            return HulpColors.textMuted;
          }),
          prefixIconColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.error)) return HulpColors.error;
            if (states.contains(WidgetState.focused)) return HulpColors.brand;
            return HulpColors.textMuted;
          }),
          suffixIconColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.error)) return HulpColors.error;
            if (states.contains(WidgetState.focused)) return HulpColors.brand;
            return HulpColors.textMuted;
          }),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: HulpColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: HulpColors.brand, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: HulpColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: HulpColors.error, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: HulpColors.brand,
            foregroundColor: HulpColors.surface,
            textStyle: HulpTextStyles.primaryAction,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: HulpColors.textPrimary,
            side: const BorderSide(color: HulpColors.borderStrong),
            textStyle: HulpTextStyles.secondaryAction,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: HulpColors.brand,
            textStyle: HulpTextStyles.secondaryAction,
          ),
        ),
      ),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}

import 'package:xobattle/helpers/demo_localization.dart';
import 'package:xobattle/firebase_options.dart';
import 'package:xobattle/routes/routes.dart';
import 'package:xobattle/screens/splash.dart';
import 'package:xobattle/widgets/life_cycle_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'helpers/color.dart';
import 'helpers/constant.dart';

/// [1.1.3] - GridWars
/// Compatible with Flutter [3.35.7]
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  if (Firebase.apps.isNotEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _MyAppState state = context.findAncestorStateOfType<_MyAppState>()!;
    state.setLocale(newLocale);
  }

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  setLocale(Locale locale) {
    if (mounted)
      setState(() {
        _locale = locale;
      });
  }

  @override
  void didChangeDependencies() {
    utils.getLocale().then((locale) {
      if (mounted)
        setState(() {
          this._locale = locale;
        });
    });
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return LifeCycleManager(
      child: MaterialApp(
        locale: _locale,
        supportedLocales: [
          Locale("en", "US"),
          Locale("es", "ES"),
          Locale("hi", "IN"),
          Locale("ar", "DZ"),
          Locale("ru", "RU"),
          Locale("ja", "JP"),
          Locale("de", "DE")
        ],
        localizationsDelegates: [
          DemoLocalization.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeResolutionCallback: (locale, supportedLocales) {
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale!.languageCode &&
                supportedLocale.countryCode == locale.countryCode) {
              return supportedLocale;
            }
          }
          return supportedLocales.first;
        },
        title: appName,
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
        onGenerateRoute: (settings) {
          final builder = Routes.data[settings.name];
          if (builder == null) return null;
          final isSplash = settings.name == '/splash';
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => isSplash
                ? builder(context)
                : Container(
                    color: primaryColor,
                    child: SafeArea(top: false, child: builder(context)),
                  ),
          );
        },
        theme: ThemeData(
          useMaterial3: false,
          fontFamily: 'Poppins',
          textTheme: TextTheme(
            bodyLarge: TextStyle(),
            bodyMedium: TextStyle(),
          ).apply(
            bodyColor: white,
            displayColor: white,
          ),
          appBarTheme: AppBarTheme(
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          primaryColor: primaryColor,
          colorScheme:
              ColorScheme.fromSwatch().copyWith(secondary: secondaryColor),
        ),
      ),
    );
  }
}

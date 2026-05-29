import 'package:xobattle/screens/arcade.dart';
import 'package:xobattle/screens/daily_challenge.dart';
import 'package:xobattle/screens/game_history.dart';
import 'package:xobattle/screens/home_screen.dart';
import 'package:xobattle/screens/leaderboard.dart';
import 'package:xobattle/screens/login.dart';
import 'package:xobattle/screens/private_room.dart';
import 'package:xobattle/screens/profile.dart';
import 'package:xobattle/screens/shop.dart';
import 'package:xobattle/screens/skins.dart';
import 'package:xobattle/screens/splash.dart';

class Routes {
  static final data = {
    "/authscreen":      (context) => Login(),
    "/home":            (context) => HomeScreenActivity(),
    "/splash":          (context) => SplashScreen(),
    "/leaderboard":     (context) => LeaderBoardScreen(),
    "/profile":         (context) => Profile(),
    "/shop":            (context) => ShopScreen(),
    "/skin":            (context) => Skins(),
    "/gamehistory":     (context) => GameHistory(),
    "/privateroom":     (context) => const PrivateRoomScreen(),
    "/dailychallenge":  (context) => const DailyChallengeScreen(),
    "/arcade":          (context) => const ArcadeScreen(),
  };
}

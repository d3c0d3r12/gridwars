import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/string.dart';
import '../helpers/theme_manager.dart';
import '../helpers/utils.dart';
import '../functions/dialoges.dart';
import '../functions/getCoin.dart';
import '../functions/playbgm.dart';
import '../main.dart';
import 'friends.dart';
import 'game_history.dart';
import 'how_to_play.dart';
import 'login_with_email.dart';
import 'privacy_policy.dart';
import 'splash.dart';
import 'tag_picker.dart';

// Free generated avatars (DiceBear PNG API — no key, no billing, no Storage).
const List<String> _presetAvatars = [
  'https://api.dicebear.com/9.x/fun-emoji/png?seed=Tiger&backgroundColor=b6e3f4',
  'https://api.dicebear.com/9.x/bottts/png?seed=Rocky&backgroundColor=c0aede',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Zoe&backgroundColor=ffd5dc',
  'https://api.dicebear.com/9.x/big-smile/png?seed=Max&backgroundColor=d1d4f9',
  'https://api.dicebear.com/9.x/micah/png?seed=Leo&backgroundColor=ffdfbf',
  'https://api.dicebear.com/9.x/thumbs/png?seed=Ace&backgroundColor=b6e3f4',
  'https://api.dicebear.com/9.x/lorelei/png?seed=Mia&backgroundColor=ffd5dc',
  'https://api.dicebear.com/9.x/notionists/png?seed=Sam&backgroundColor=c0aede',
  'https://api.dicebear.com/9.x/open-peeps/png?seed=Kai&backgroundColor=d1d4f9',
  'https://api.dicebear.com/9.x/avataaars/png?seed=Nova&backgroundColor=ffdfbf',
  'https://api.dicebear.com/9.x/personas/png?seed=Jin&backgroundColor=b6e3f4',
  'https://api.dicebear.com/9.x/fun-emoji/png?seed=Bolt&backgroundColor=ffd5dc',
  'https://api.dicebear.com/9.x/bottts/png?seed=Pixel&backgroundColor=d1d4f9',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Luna&backgroundColor=c0aede',
  'https://api.dicebear.com/9.x/big-smile/png?seed=Echo&backgroundColor=ffdfbf',
  'https://api.dicebear.com/9.x/micah/png?seed=Rio&backgroundColor=b6e3f4',
];

class Profile extends StatefulWidget {
  @override
  _ProfileBodyState createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<Profile>
    with SingleTickerProviderStateMixin {
  int? coin = 0;
  int? matchPlayedCount = 0;
  int? score = 0;
  int? matchWon = 0;
  int? selectedLanguage;
  bool sound = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final InAppReview _inAppReview = InAppReview.instance;
  Utils localValue = Utils();
  late String platform;
  String profilePic = guestProfilePic, username = "", name = "";

  List<String?> languageList = [];
  bool isLoading = false;
  final _nameFieldKey = GlobalKey<FormFieldState>();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) platform = "Android";
    if (Platform.isIOS) platform = "IOS";

    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    getSound();
    _loadFields();

    Future.delayed(Duration.zero, () {
      _getLanguageList();
      _getSavedLanguage();
    });
  }

  void _loadFields() {
    _getField("matchplayed", (e) => matchPlayedCount = e);
    _getField("coin", (e) => coin = e);
    _getField("score", (e) => score = e);
    _getField("matchwon", (e) => matchWon = e);
    _getField("profilePic", (e) => profilePic = e);
    _getField("username", (e) => username = e);
  }

  void _getField(String field, void Function(dynamic) cb) async {
    try {
      final ins = GetUserInfo();
      final init = await ins.getFieldValue(field);
      if (mounted) setState(() => cb(init));
      ins.detectChange(field, (val) {
        if (mounted) setState(() { isLoading = false; cb(val); });
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _openStoreListing() =>
      _inAppReview.openStoreListing(appStoreId: appStoreId);

  @override
  Widget build(BuildContext context) {
    _getLanguageList();
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) => music.play(click),
      child: Scaffold(
        backgroundColor: bgColor,
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(
                    color: xColor, strokeWidth: 2.5))
            : FadeTransition(
                opacity: _fadeAnim,
                child: ListView(
                  children: [
                    _buildTopBar(),
                    _buildProfileCard(),
                    _buildStatCards(),
                    const SizedBox(height: 24),
                    _buildSection('Appearance', [
                      ValueListenableBuilder<bool>(
                        valueListenable: ThemeManager.isDark,
                        builder: (_, dark, __) => _SettingsRow(
                          icon: dark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          iconColor: dark
                              ? const Color(0xFF9C27B0)
                              : const Color(0xFFFF9800),
                          title: dark ? 'Dark Mode' : 'Light Mode',
                          trailing: _Toggle(
                            on: dark,
                            onChange: (_) async {
                              await ThemeManager.toggle();
                              if (mounted) setState(() {});
                            },
                          ),
                          isLast: true,
                        ),
                      ),
                    ]),
                    _buildSection('Sound & Feel', [
                      _SettingsRow(
                        icon: Icons.volume_up_rounded,
                        iconColor: xColor,
                        title: 'Sound Effects',
                        trailing: _Toggle(
                          on: sound,
                          onChange: (v) async {
                            changeValue(v);
                            setState(() => sound = v);
                            if (v) {
                              if (Music.status != 'playing') {
                                await music.play(backMusic);
                              }
                            } else {
                              if (Music.status == 'playing') {
                                await music.stop();
                              }
                            }
                          },
                        ),
                      ),
                    ]),
                    if (!_auth.currentUser!.isAnonymous)
                      _buildSection('Social', [
                        _SettingsRow(
                          icon: Icons.people_rounded,
                          iconColor: xColor,
                          title: 'Friends',
                          onTap: () {
                            music.play(click);
                            Navigator.of(context).push(CupertinoPageRoute(
                                builder: (_) => const FriendsScreen()));
                          },
                        ),
                        _SettingsRow(
                          icon: Icons.tag_rounded,
                          iconColor: oColor,
                          title: 'My Game Tags',
                          onTap: () {
                            music.play(click);
                            Navigator.of(context).push(CupertinoPageRoute(
                                builder: (_) => const TagPickerScreen()));
                          },
                          isLast: true,
                        ),
                      ]),
                    _buildSection('Account', [
                      if (!_auth.currentUser!.isAnonymous) ...[
                        _SettingsRow(
                          icon: Icons.history_rounded,
                          iconColor: const Color(0xFF42B8B0),
                          title: utils.getTranslated(context, "history"),
                          onTap: () async {
                            music.play(click);
                            try {
                              await InternetAddress.lookup('google.com');
                              Navigator.of(context).push(CupertinoPageRoute(
                                  builder: (_) => GameHistory()));
                            } on SocketException {
                              Dialogue().error(context);
                            }
                          },
                        ),
                        _SettingsRow(
                          icon: Icons.shopping_bag_rounded,
                          iconColor: goldColor,
                          title: utils.getTranslated(context, "shop"),
                          onTap: () async {
                            music.play(click);
                            try {
                              await InternetAddress.lookup('google.com');
                              Navigator.pushNamed(context, "/shop");
                            } on SocketException {
                              Dialogue().error(context);
                            }
                          },
                        ),
                        _SettingsRow(
                          icon: Icons.style_rounded,
                          iconColor: xColor,
                          title: utils.getTranslated(context, "skin"),
                          onTap: () async {
                            music.play(click);
                            try {
                              await InternetAddress.lookup('google.com');
                              Navigator.pushNamed(context, "/skin");
                            } on SocketException {
                              Dialogue().error(context);
                            }
                          },
                        ),
                      ] else
                        _SettingsRow(
                          icon: Icons.login_rounded,
                          iconColor: goodColor,
                          title: utils.getTranslated(context, "signInNow"),
                          onTap: () {
                            music.play(click);
                            Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (_) => LoginWithEmail()));
                          },
                        ),
                    ]),
                    _buildSection('Appearance', [
                      _SettingsRow(
                        icon: Icons.language_rounded,
                        iconColor: ink2Color,
                        title: utils.getTranslated(context, "changeLanguage"),
                        onTap: () => openChangeLanguageBottomSheet(),
                      ),
                    ]),
                    _buildSection('More', [
                      _SettingsRow(
                        icon: Icons.help_outline_rounded,
                        iconColor: ink2Color,
                        title: utils.getTranslated(context, "howToPlayHeading"),
                        onTap: () {
                          music.play(click);
                          Navigator.push(context,
                              CupertinoPageRoute(builder: (_) => HowToPlay()));
                        },
                      ),
                      _SettingsRow(
                        icon: Icons.star_outline_rounded,
                        iconColor: goldColor,
                        title: utils.getTranslated(context, "rate"),
                        onTap: () => _openStoreListing(),
                      ),
                      _SettingsRow(
                        icon: Icons.share_rounded,
                        iconColor: xColor,
                        title: utils.getTranslated(context, "share"),
                        onTap: () {
                          final str =
                              "$appName\n\n$appFind$androidLink$packageName\n\n iOS:\n$iosLink$iosPackage";
                          SharePlus.instance.share(ShareParams(text: str));
                        },
                      ),
                      _SettingsRow(
                        icon: Icons.info_outline_rounded,
                        iconColor: ink2Color,
                        title: utils.getTranslated(context, "aboutUs"),
                        onTap: () {
                          music.play(click);
                          Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (_) => PrivacyPolicy(
                                      title: utils.getTranslated(
                                          context, "aboutUs"))));
                        },
                      ),
                      _SettingsRow(
                        icon: Icons.contact_support_outlined,
                        iconColor: ink2Color,
                        title: utils.getTranslated(context, "contactUs"),
                        onTap: () {
                          Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (_) => PrivacyPolicy(
                                      title: utils.getTranslated(
                                          context, "contactUs"))));
                        },
                      ),
                      _SettingsRow(
                        icon: Icons.description_outlined,
                        iconColor: ink2Color,
                        title: utils.getTranslated(context, "termCond"),
                        onTap: () {
                          music.play(click);
                          Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (_) => PrivacyPolicy(
                                      title: utils.getTranslated(
                                          context, "termCond"))));
                        },
                      ),
                      _SettingsRow(
                        icon: Icons.shield_outlined,
                        iconColor: goodColor,
                        title: utils.getTranslated(context, "privacy"),
                        isLast: true,
                        onTap: () {
                          music.play(click);
                          Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (_) => PrivacyPolicy(
                                      title: utils.getTranslated(
                                          context, "privacy"))));
                        },
                      ),
                    ]),
                    _buildSection('Danger Zone', [
                      _SettingsRow(
                        icon: Icons.logout_rounded,
                        iconColor: red,
                        title: utils.getTranslated(context, "logout"),
                        onTap: () => _confirmLogout(),
                      ),
                      _SettingsRow(
                        icon: Icons.delete_outline_rounded,
                        iconColor: red,
                        title: utils.getTranslated(context, "deleteAccount"),
                        isLast: true,
                        onTap: () => deleteAccount(context),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Center(
                      child: Text('Chill Zone · v1.1.3',
                          style:
                              TextStyle(fontSize: 12, color: ink3Color)),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                music.play(click);
                Navigator.pop(context);
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: lineColor),
                  boxShadow: [shadowSm],
                ),
                child: Icon(Icons.arrow_back_rounded,
                    color: inkColor, size: 20),
              ),
            ),
            const SizedBox(width: 14),
            Text('Settings',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: inkColor)),
          ],
        ),
      ),
    );
  }

  // ─── Profile card ─────────────────────────────────────────────────────────

  Widget _buildProfileCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: cardDecoration(radius: 22),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (!_auth.currentUser!.isAnonymous) {
                  openEditProfileBottomSheet();
                }
              },
              child: Stack(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(profilePic),
                    radius: 30,
                    backgroundColor: surface2Color,
                  ),
                  if (!_auth.currentUser!.isAnonymous)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: lineColor),
                        ),
                        child:
                            Icon(Icons.edit, size: 12, color: ink2Color),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(utils.limitChar(username),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: inkColor)),
                  if (_auth.currentUser!.email != null)
                    Text(_auth.currentUser!.email!,
                        style: TextStyle(
                            fontSize: 12, color: ink2Color)),
                  const SizedBox(height: 5),
                  _RankBadge(score: score ?? 0, size: 'sm'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stat cards ───────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _StatTile(
              label: 'Coins',
              value: '$coin',
              color: goldColor),
          const SizedBox(width: 10),
          _StatTile(
              label: 'Played',
              value: '$matchPlayedCount',
              color: xColor),
          const SizedBox(width: 10),
          _StatTile(
              label: 'Won',
              value: '$matchWon',
              color: goodColor),
        ],
      ),
    );
  }

  // ─── Section builder ──────────────────────────────────────────────────────

  Widget _buildSection(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: ink3Color)),
          const SizedBox(height: 10),
          Container(
            decoration: cardDecoration(radius: 18),
            clipBehavior: Clip.hardEdge,
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void changeUserNameInFirebase() async {
    Navigator.of(context).pop();
    final form = _nameFieldKey.currentState!;
    form.save();
    if (form.validate()) {
      var ins = GetUserInfo();
      await ins.setUsername(name);
    }
  }

  // Preset avatar picker — free generated-avatar URLs (no Firebase Storage /
  // Blaze plan needed). The whole app renders profilePic via NetworkImage,
  // so a chosen URL shows up everywhere automatically.
  void _pickAvatar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(
                color: lineColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Choose your avatar',
                style: TextStyle(color: inkColor, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 14),
            Flexible(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12,
                ),
                itemCount: _presetAvatars.length,
                itemBuilder: (_, i) {
                  final url = _presetAvatars[i];
                  final selected = profilePic == url;
                  return GestureDetector(
                    onTap: () => _setAvatar(url),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: surface2Color,
                        border: Border.all(
                          color: selected ? xColor : lineColor,
                          width: selected ? 3 : 1,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.network(url, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.person_rounded, color: ink3Color),
                          loadingBuilder: (_, child, prog) => prog == null
                              ? child
                              : Center(child: SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: xColor))),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _setAvatar(String url) async {
    Navigator.pop(context); // close avatar grid
    setState(() => profilePic = url);
    try {
      await GetUserInfo().setProfilePic(url);
      if (mounted) {
        utils.setSnackbar(context,
            utils.getTranslated(context, "ProfileUpdatedSuccessfully"));
      }
    } catch (e) {
      if (mounted) utils.setSnackbar(context, 'Could not update avatar.');
    }
  }

  changeValue(bool val) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setBool(appName + "SFX-ENABLED", val);
  }

  Future<void> getSound() async {
    sound = await utils.getSfxValue();
    setState(() {});
  }

  _getSavedLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String lang = prefs.getString(LAGUAGE_CODE) ?? "";
    selectedLanguage = langCode.indexOf(lang.isEmpty ? "en" : lang);
    if (mounted) setState(() {});
  }

  void _changeLan(String language, BuildContext ctx) async {
    Locale locale = await utils.setLocale(language);
    MyApp.setLocale(ctx, locale);
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: utils.getTranslated(context, "logout"),
        body: utils.getTranslated(context, "areYouSure"),
        confirmLabel: utils.getTranslated(context, "yes"),
        cancelLabel: utils.getTranslated(context, "no"),
        onConfirm: () async {
          var userID = FirebaseAuth.instance.currentUser!.uid;
          if (FirebaseAuth.instance.currentUser!.isAnonymous) {
            Dialogue.removeChild("users", userID);
          }
          localValue.setSkinValue("user_skin", "");
          localValue.setSkinValue("opponent_skin", "");
          await utils.setUserLoggedIn("isLoggedIn", false);
          final GoogleSignIn googleSignIn = GoogleSignIn.instance;
          await googleSignIn.initialize();
          await googleSignIn.signOut();
          await FirebaseAuth.instance.signOut();
          music.play(click);
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/authscreen', (Route<dynamic> route) => false);
        },
      ),
    );
  }

  void openChangeLanguageBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(999)),
            ),
            const SizedBox(height: 20),
            Text(utils.getTranslated(context, "changeLanguage"),
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: inkColor)),
            const SizedBox(height: 14),
            StatefulBuilder(
              builder: (ctx, setModalState) => Column(
                children: getLngList(ctx, setModalState),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void openEditProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(999)),
            ),
            const SizedBox(height: 20),
            Text(utils.getTranslated(context, "editProfile"),
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: inkColor)),
            const SizedBox(height: 20),
            StatefulBuilder(
              builder: (ctx, setModalState) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(profilePic),
                            radius: 40,
                            backgroundColor: surface2Color,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                  color: surfaceColor,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: lineColor)),
                              child: Icon(Icons.edit,
                                  size: 16, color: ink2Color),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: surface2Color,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: lineColor),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      child: TextFormField(
                        key: _nameFieldKey,
                        keyboardType: TextInputType.text,
                        style: TextStyle(
                            color: inkColor,
                            fontWeight: FontWeight.w500),
                        textInputAction: TextInputAction.done,
                        initialValue: username,
                        validator: (val) {
                          if (val!.isEmpty) {
                            return utils.getTranslated(
                                context, "usernameRequired");
                          }
                          return null;
                        },
                        onSaved: (v) => name = v ?? username,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                              Icons.account_circle_outlined,
                              color: ink3Color,
                              size: 20),
                          border: InputBorder.none,
                          hintText:
                              utils.getTranslated(context, "username"),
                          hintStyle:
                              TextStyle(color: ink3Color),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: xColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        minimumSize:
                            const Size(double.infinity, 48),
                        elevation: 0,
                      ),
                      onPressed: changeUserNameInFirebase,
                      child: Text(
                          utils.getTranslated(context, "save")),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> getLngList(BuildContext ctx, StateSetter setModalState) {
    return languageList
        .asMap()
        .map((index, element) => MapEntry(
            index,
            InkWell(
              onTap: () {
                if (mounted) {
                  selectedLanguage = index;
                  _changeLan(langCode[index], ctx);
                  setModalState(() {});
                  setState(() {});
                  Navigator.pop(context);
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selectedLanguage == index
                            ? xColor
                            : surface2Color,
                        border: Border.all(
                            color: selectedLanguage == index
                                ? xColor
                                : lineColor),
                      ),
                      child: Icon(Icons.check,
                          size: 14,
                          color: selectedLanguage == index
                              ? Colors.white
                              : Colors.transparent),
                    ),
                    const SizedBox(width: 14),
                    Text(languageList[index]!,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: inkColor)),
                  ],
                ),
              ),
            )))
        .values
        .toList();
  }

  void deleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: utils.getTranslated(context, "deleteAccount"),
        body: utils.getTranslated(context, "areYouSure"),
        confirmLabel: utils.getTranslated(context, "yes"),
        cancelLabel: utils.getTranslated(context, "no"),
        isDanger: true,
        onConfirm: () async {
          music.play(click);
          try {
            await FirebaseAuth.instance.currentUser!.delete();
            utils.setSnackbar(context,
                utils.getTranslated(context, 'accountDeletedSuccess'));
            localValue.setSkinValue("user_skin", "");
            localValue.setSkinValue("opponent_skin", "");
            await utils.setUserLoggedIn("isLoggedIn", false);
            Navigator.of(context).pushNamedAndRemoveUntil(
                '/authscreen', (Route<dynamic> route) => false);
          } catch (e) {
            Navigator.pop(context);
            if (e.toString().contains('requires-recent-login')) {
              utils.setSnackbar(context,
                  utils.getTranslated(context, 'loginAgainToDeleteAccount'));
            }
          }
        },
      ),
    );
  }

  void _getLanguageList() {
    languageList = [
      utils.getTranslated(context, 'ENGLISH_LAN'),
      utils.getTranslated(context, 'SPANISH_LAN'),
      utils.getTranslated(context, 'HINDI_LAN'),
      utils.getTranslated(context, 'ARABIC_LAN'),
      utils.getTranslated(context, 'RUSSIAN_LAN'),
      utils.getTranslated(context, 'JAPANISE_LAN'),
      utils.getTranslated(context, 'GERMAN_LAN'),
    ];
  }
}

// ── Settings row ──────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: inkColor)),
                ),
                trailing ??
                    (onTap != null
                        ? Icon(Icons.chevron_right_rounded,
                            color: ink3Color, size: 18)
                        : const SizedBox()),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, color: line2Color, indent: 62),
      ],
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lineColor),
          boxShadow: [shadowSm],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: color)),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(fontSize: 11, color: ink3Color)),
          ],
        ),
      ),
    );
  }
}

// ── Toggle ────────────────────────────────────────────────────────────────────

class _Toggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChange;
  const _Toggle({required this.on, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChange(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: on ? goodColor : lineColor,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 5,
                    offset: Offset(0, 2))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Rank badge ────────────────────────────────────────────────────────────────

class _RankBadge extends StatelessWidget {
  final int score;
  final String size;
  const _RankBadge({required this.score, this.size = 'md'});

  static const _tiers = [
    {'label': 'Diamond', 'min': 7000, 'color': 0xFF5C8DF6},
    {'label': 'Platinum', 'min': 3500, 'color': 0xFF42B8B0},
    {'label': 'Gold', 'min': 1500, 'color': 0xFFE0A92B},
    {'label': 'Silver', 'min': 500, 'color': 0xFF9AA3B2},
    {'label': 'Bronze', 'min': 0, 'color': 0xFFB0794B},
  ];

  Map<String, dynamic> get _tier {
    for (final t in _tiers) {
      if (score >= (t['min'] as int)) return t;
    }
    return _tiers.last;
  }

  @override
  Widget build(BuildContext context) {
    final t = _tier;
    final col = Color(t['color'] as int);
    final sm = size == 'sm';
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: sm ? 9 : 11, vertical: sm ? 4 : 6),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: sm ? 6 : 7,
              height: sm ? 6 : 7,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: col)),
          const SizedBox(width: 5),
          Text(t['label'] as String,
              style: TextStyle(
                  color: col,
                  fontWeight: FontWeight.w700,
                  fontSize: sm ? 11 : 12.5)),
        ],
      ),
    );
  }
}

// ── Confirm dialog ────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final bool isDanger;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: surfaceColor,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: inkColor)),
            const SizedBox(height: 10),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: ink2Color)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: lineColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(cancelLabel,
                        style: TextStyle(color: ink2Color)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDanger ? red : xColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: onConfirm,
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

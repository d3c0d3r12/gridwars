import 'package:xobattle/helpers/color.dart';
import 'package:xobattle/helpers/constant.dart';
import 'package:xobattle/screens/more_games.dart';
import 'package:xobattle/screens/splash.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../helpers/utils.dart';
import '../functions/advertisement.dart';

class MoreGamesListing extends StatefulWidget {
  MoreGamesListing({super.key});

  @override
  State<MoreGamesListing> createState() => _MoreGamesListingState();
}

class _MoreGamesListingState extends State<MoreGamesListing> {
  final List<Widget> gameListUI = [];

  List<HTMLGames> gamesList = [
    HTMLGames(
        gameImage: 'https://hextris.io/favicon.png',
        gameName: 'Hextris',
        gameURL: 'https://hextris.io/'),
    HTMLGames(
        gameImage:
            'https://raw.githubusercontent.com/ellisonleao/clumsy-bird/main/src/title/background.png',
        gameName: 'Clumsy Bird',
        gameURL: 'https://ellisonleao.github.io/clumsy-bird/'),
    HTMLGames(
        gameImage: 'https://pacman.platzh1rsch.ch/favicon.ico',
        gameName: 'Pacman',
        gameURL: 'https://pacman.platzh1rsch.ch/'),
  ];

  @override
  void initState() {
    Advertisement.loadAd();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.games,
              size: 20,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text("${utils.getTranslated(context, "playMoreGames")}"),
            ),
          ],
        ),
        backgroundColor: secondaryColor,
        elevation: 0,
      ),
      backgroundColor: secondaryColor,
      body: gamesList.isEmpty
          ? Center(
              child: Text(utils.getTranslated(context, "noMoreGamesFound")),
            )
          : showMoreGameList(context),
    );
  }

  Widget showMoreGameList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ListView(
        children: [...getMoreGameList(context)],
      ),
    );
  }

  getMoreGameList(BuildContext context) {
    gameListUI.clear();
    gamesList.forEach((element) {
      gameListUI.add(getGame(element, context));
    });
    return gameListUI;
  }

  Widget getGame(HTMLGames game, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              // padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              height: 70,
              decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10)),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.4),
                            spreadRadius: 2,
                            blurRadius: 4,
                            offset: Offset(4, 4), // changes position of shadow
                          ),
                        ],
                      ),
                      child: CachedNetworkImage(
                        height: 70,
                        width: 70,
                        fit: BoxFit.cover,
                        imageUrl: game.gameImage,
                        progressIndicatorBuilder: (context, url, progress) {
                          return getSvgImage(
                            imageName: 'dora_placeholder',
                            height: 70,
                            width: 70,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          game.gameName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 5,
          ),
          InkWell(
            child: Container(
                width: MediaQuery.of(context).size.width * 0.20,
                height: 70,
                padding: EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                    color: red,
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                child: Center(
                    child: Text(
                  utils.getTranslated(context, 'playNow'),
                ))),
            onTap: () async {
              music.play(click);
              Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => PlayGame(gameURL: game.gameURL),
                  ));
            },
          ),
        ],
      ),
    );
  }
}

class HTMLGames {
  final String gameName;
  final String gameImage;
  final String gameURL;

  HTMLGames(
      {required this.gameName, required this.gameImage, required this.gameURL});
}

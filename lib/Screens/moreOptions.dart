
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Helper/auth.dart';

class MoreOptions extends StatefulWidget {
  const MoreOptions({super.key});

  @override
  _MoreOptionsState createState() => _MoreOptionsState();
}

class _MoreOptionsState extends State<MoreOptions> {

  // late PackageInfo packageInfo;

  String appName='';
  String packageName='';
  String version='';
  String buildNumber='';

  @override
  void initState() {
    super.initState();
    if (kDebugMode) print ('----    In MoreOptions    ----');
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp
    ]);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _getPackageInfo());
  }

  _getPackageInfo() async {
    //packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      // appName = packageInfo.appName;
      // packageName = packageInfo.packageName;
      // version = packageInfo.version;
      // buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
        child: AppBar(
          title: Text('MORE OPTIONS', style: GoogleFonts.montserrat(textStyle: (TextStyle(color: Theme.of(context).colorScheme.onBackground))),),
          //backgroundColor: Theme.of(context).colorScheme.primary,
          leading: IconButton(icon: const Icon(Icons.arrow_back), color: Theme.of(context).colorScheme.onBackground, onPressed: () { Navigator.pop(context); },),
        ),
      ),
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.all(8.0),
          margin: EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Logged in as: ${Provider.of<CP>(context).getAppUser()?.email }'),
              Divider(),
//              Text('AppName: '+appName),
//              Text('Package: '+packageName),
//              Text('Version: '+version),
//              Text('Build: '+buildNumber),
              Container(
                child: GestureDetector(
                  onTap: () async {
                    Auth auth = Auth();
                    Provider.of<CP>(context, listen: false).resetVariables();
                    await auth.signOut(context);
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (Route<dynamic> route) => false);
                    },
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.all(Radius.circular(20.0))
                    ),
                    padding: const EdgeInsets.all(20.0),
                    margin: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0,bottom: 20.0),
                    width: double.infinity,
                    child: const Center(child: Text('SIGN OUT', style: TextStyle(color: Colors.white, fontSize: 20.0),)),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  showAboutDialog(
                    children: [
                      Image.asset('images/1024LowPoly.png',),
                      const Text('Contact developer on \'developer@eelevan.co.uk\''),
                    ],
                    context: context,
                    applicationName: appName,
                    applicationVersion: version.toString(),
                    //applicationIcon: Image.asset('images/1024LowPoly.png', scale: 5,),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                      color: activeBTN,
                      borderRadius: const BorderRadius.all(Radius.circular(20.0))
                  ),
                  padding: const EdgeInsets.all(20.0),
                  margin: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0,bottom: 20.0),
                  width: double.infinity,
                  child: const Center(child: Text('SHOW ABOUT INFO', style: TextStyle(color: Colors.white, fontSize: 20.0),)),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

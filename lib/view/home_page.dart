import 'dart:io';

import 'package:dpip/util/extension.dart';
import 'package:dpip/view/report_list.dart';
import 'package:dpip/view/weather_warning.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart';

import '../core/utils.dart';
import '../global.dart';
import '../model/earthquake_report.dart';
import '../model/partial_earthquake_report.dart';
import '../util/intensity_color.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePage();
}

class Areas {
  static List<String> getOptions() {
    return ['萬榮鄉', '壽豐鄉', '花蓮市']; // 鄉鎮列表
  }
}

class Cal {
  double percentToPixel(double percent, BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return percent / 100 * screenWidth;
  }
}

// class IntColor {
//   static const Map<int, Color> _colors = {
//     0: Color(0xff202020),
//     1: Color(0xff003264),
//     2: Color(0xff0064c8),
//     3: Color(0xff1e9632),
//     4: Color(0xffffc800),
//     5: Color(0xffff9600),
//     6: Color(0xffff6400),
//     7: Color(0xffff0000),
//     8: Color(0xffc00000),
//     9: Color(0xff9600c8),
//   };
//
//   Color intColor(int intensity) {
//     return _colors[intensity] ?? Color(0xFF202020);
//   }
// }

class TempColor {
  List<Color> tempColors = [
    const Color(0xFF006060),
    const Color(0xFF00AFAF),
    const Color(0xFF00FFFF),
    const Color(0xFF3AAA50),
    const Color(0xFFFFFF00),
    const Color(0xFFFF8A00),
    const Color(0xFFFF0000),
    const Color(0xFFFF00CA),
    const Color(0xFF6040B0),
  ];

  Color getColorForTemp(double temp) {
    const double minTemp = 0;
    const double maxTemp = 40;

    if (temp == -99.9) {
      return const Color(0xFF808080);
    } else if (temp <= minTemp) {
      return const Color(0xFF006060);
    } else if (temp >= maxTemp) {
      return const Color(0xFF6040B0);
    } else {
      double t = ((temp - minTemp) / (maxTemp - minTemp)).clamp(0.0, 1.0);
      int index = (t * (tempColors.length - 1)).floor();
      double localT = (t * (tempColors.length - 1)) - index;

      return Color.lerp(tempColors[index], tempColors[index + 1 < tempColors.length ? index + 1 : index], localT)!;
    }
  }
}

class EqInfo extends StatelessWidget {
  // final List eqReport;
  //
  // const EqInfo({Key? key, required this.eqReport}) : super(key: key);
  final PartialEarthquakeReport eqReport;

  EqInfo({super.key, required this.eqReport});

  Cal calculator = Cal();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: calculator.percentToPixel(90, context),
        // height: calculator.percentToPixel(25, context),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0x30808080),
        ),
        child: IntrinsicHeight(
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: calculator.percentToPixel(2, context),
                  decoration: BoxDecoration(
                    color: eqReport.hasNumber ? const Color(0xFFC09010) : const Color(0xFF20AAAA),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: calculator.percentToPixel(5, context),
                  right: calculator.percentToPixel(5, context),
                  top: calculator.percentToPixel(1, context),
                  bottom: calculator.percentToPixel(2, context),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eqReport.loc.substring(0, eqReport.loc.length - 1).split("位於")[1],
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                        Text(
                          DateFormat("yyyy/MM/dd HH:mm:ss").format(
                            TZDateTime.fromMillisecondsSinceEpoch(
                              getLocation("Asia/Taipei"),
                              eqReport.time,
                            ),
                          ),
                          style: const TextStyle(color: Color(0xFFc9c9c9), fontSize: 16),
                          textAlign: TextAlign.left,
                        ),
                        Text(
                          "規模${eqReport.mag}　深度${eqReport.depth}公里",
                          style: const TextStyle(fontSize: 18, letterSpacing: 2),
                        ),
                      ],
                    ),
                    Container(
                      alignment: Alignment.center,
                      width: calculator.percentToPixel(15, context),
                      height: calculator.percentToPixel(15, context),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: context.colors.intensity(eqReport.intensity),
                      ),
                      child: Text(
                        intensityToNumberString(eqReport.intensity),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: context.colors.onIntensity(eqReport.intensity),
                        ),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
      SizedBox(
        height: calculator.percentToPixel(2, context),
      ),
    ]);
  }
}

class _HomePage extends State<HomePage> {
  late String _selectedArea;
  List<PartialEarthquakeReport> reports = [];
  var weather = {
    'temp': "-99.9",
    'feel': "-99.9",
    'humidity': "-99.9",
    'precip': "-99.9",
  };
  List eqReport = [];
  bool weatherRefreshing = true;
  bool eqReportRefreshing = true;
  late Cal calculator;
  late TempColor tempToColor;

  void refreshWeather() async {
    weatherRefreshing = true;
    try {
      final weatherData = await Global.api.getWeatherRealtime("979");
      weather = {
        'temp': weatherData.temp.c.toString(),
        'feel': weatherData.feel.c.toString(),
        'humidity': weatherData.humidity.toString(),
        'precip': weatherData.precip.mm.toString(),
      };
    } catch (e) {
      print(e);
    }
    weatherRefreshing = false;
    setState(() {});
  }

  void refreshEqReport() async {
    eqReportRefreshing = true;
    try {
      final eqReportData = await Global.api.getReportList(limit: 3);
      eqReport = eqReportData;
    } catch (e) {
      print(e);
    }
    eqReportRefreshing = false;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    tempToColor = TempColor();
    calculator = Cal();
    refreshWeather();
    refreshEqReport();
    _selectedArea = Areas.getOptions().first; // 初始化時設定_selectedValue為列表的第一項
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return const SafeArea(
        child: Scaffold(
          body: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "首頁",
                style: TextStyle(fontSize: 30, color: Color(0xFFFF9000), letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    } else {
      return SafeArea(
        child: Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    "首頁",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  DropdownButton<String>(
                    value: _selectedArea, // 當前選中的值
                    icon: const Icon(Icons.navigate_next), // 下拉箭頭圖標
                    onChanged: (String? newArea) {
                      setState(() {
                        _selectedArea = newArea!;
                      });
                    },
                    items: Areas.getOptions().map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 20),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ),
            body: Column(
              children: [
                Stack(
                  children: [
                    // height: calculator.percentToPixel(60, context),

                    weatherRefreshing == true
                        ? const Positioned.fill(
                            child: Center(
                            child: CircularProgressIndicator(),
                          ))
                        : weather["temp"] == "-99.9"
                            ? const Positioned.fill(
                                child: Center(
                                child: Text("天氣取得失敗"),
                              ))
                            : Container(),
                    Opacity(
                      opacity: weatherRefreshing == true || weather["temp"] == "-99.9" ? 0 : 1,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          SizedBox(height: calculator.percentToPixel(45, context)),
                          Positioned(
                            bottom: calculator.percentToPixel(0, context),
                            right: 0,
                            left: 0,
                            child: Column(
                              children: [
                                Container(
                                  height: 30, //
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        tempToColor.getColorForTemp(double.parse(weather["temp"]!)),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: calculator.percentToPixel(6, context),
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                        bottom: calculator.percentToPixel(2, context),
                                        left: calculator.percentToPixel(5, context),
                                        right: calculator.percentToPixel(5, context)),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("", style: TextStyle(fontSize: 12)),
                                        Text(
                                          "天氣資料來自 weather.com",
                                          style: TextStyle(fontSize: 12),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(height: calculator.percentToPixel(3, context)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  SizedBox(width: calculator.percentToPixel(5, context)),
                                  Icon(
                                    Icons.cloud_outlined,
                                    size: calculator.percentToPixel(35, context),
                                  ),
                                  SizedBox(width: calculator.percentToPixel(0, context)),
                                  SizedBox(
                                    width: calculator.percentToPixel(55, context),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: calculator.percentToPixel(5, context),
                                            ),
                                            SizedBox(
                                                width: calculator.percentToPixel(50, context),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        const Text("降水量", style: TextStyle(fontSize: 20)),
                                                        Text("${weather["precip"]} mm",
                                                            style: const TextStyle(
                                                                fontSize: 20, fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        const Text("濕度", style: TextStyle(fontSize: 20)),
                                                        Text("${weather["humidity"]} %",
                                                            style: const TextStyle(
                                                                fontSize: 20, fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        const Text("體感", style: TextStyle(fontSize: 20)),
                                                        Text("${weather["feel"]} ℃",
                                                            style: const TextStyle(
                                                                fontSize: 20, fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  ],
                                                )),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text("${weather["temp"]?.split(".")[0]}",
                                                style: const TextStyle(
                                                    fontSize: 96, fontWeight: FontWeight.w900, letterSpacing: 5)),
                                            Column(
                                              children: [
                                                const Text("℃",
                                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                                Text(".${weather["temp"]?.split(".")[1]}",
                                                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
                                                SizedBox(height: calculator.percentToPixel(4.5, context)),
                                              ],
                                            )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: calculator.percentToPixel(5, context)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 1.5,
                  color: Colors.white,
                ),
                Padding(
                  padding: EdgeInsets.only(
                      left: calculator.percentToPixel(5, context),
                      right: calculator.percentToPixel(5, context),
                      top: calculator.percentToPixel(5, context)),
                  child: Column(
                    children: [
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //   children: [
                      //     const Text(
                      //       "天氣警特報",
                      //       style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
                      //     ),
                      //     TextButton(
                      //         onPressed: () {
                      //           Navigator.push(
                      //             context,
                      //             MaterialPageRoute(
                      //               builder: (context) => const WeatherWarning(),
                      //             ),
                      //           );
                      //         },
                      //         child: const Row(children: [
                      //           Text(
                      //             "詳細資訊",
                      //             style: TextStyle(fontSize: 20, letterSpacing: 2, color: Color(0xFFC9C9C9)),
                      //           ),
                      //           Icon(
                      //             Icons.navigate_next,
                      //             color: Color(0xfff9f9f9),
                      //           ),
                      //         ]))
                      //   ],
                      // ),
                      // const Row(
                      //   mainAxisAlignment: MainAxisAlignment.start,
                      //   children: [
                      //     Text(
                      //       "目前設定區域未發布天氣警特報",
                      //       style: TextStyle(fontSize: 16, letterSpacing: 2, color: Color(0xFFC9C9C9)),
                      //     ),
                      //   ],
                      // ),
                      // SizedBox(
                      //   height: calculator.percentToPixel(5, context),
                      // ),
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //   children: [
                      //     const Text(
                      //       "地震資訊",
                      //       style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
                      //     ),
                      //     TextButton(
                      //         onPressed: () {
                      //           Navigator.push(
                      //             context,
                      //             MaterialPageRoute(
                      //               builder: (context) => const ReportList(),
                      //             ),
                      //           );
                      //         },
                      //         child: const Row(children: [
                      //           Text(
                      //             "詳細資訊",
                      //             style: TextStyle(fontSize: 20, letterSpacing: 2, color: Color(0xFFC9C9C9)),
                      //           ),
                      //           Icon(
                      //             Icons.navigate_next,
                      //             color: Color(0xfff9f9f9),
                      //           ),
                      //         ]))
                      //   ],
                      // ),
                      eqReportRefreshing == false
                          ? eqReport.isEmpty
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      "近期設定區域無地震或警特報資訊",
                                      style: TextStyle(fontSize: 16, letterSpacing: 2, color: Color(0xFFC9C9C9)),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  itemCount: eqReport.length,
                                  itemBuilder: (context, index) {
                                    return EqInfo(eqReport: eqReport[index]);
                                  },
                                  shrinkWrap: true,
                                )
                          // ? Container(
                          //     width: calculator.percentToPixel(90, context),
                          //     // height: calculator.percentToPixel(25, context),
                          //     decoration: BoxDecoration(
                          //       borderRadius: BorderRadius.circular(10),
                          //       color: Color(0x30808080),
                          //     ),
                          //     child: IntrinsicHeight(
                          //       child: Stack(
                          //         children: <Widget>[
                          //           Align(
                          //             alignment: Alignment.topLeft,
                          //             child: Container(
                          //               width: calculator.percentToPixel(2, context),
                          //               decoration: BoxDecoration(
                          //                 color: Color(0xFF20AAAA),
                          //                 borderRadius: BorderRadius.only(
                          //                   topLeft: Radius.circular(10),
                          //                   bottomLeft: Radius.circular(10),
                          //                 ),
                          //               ),
                          //             ),
                          //           ),
                          //           Padding(
                          //             padding: EdgeInsets.only(
                          //               left: calculator.percentToPixel(5, context),
                          //               right: calculator.percentToPixel(5, context),
                          //               top: calculator.percentToPixel(1, context),
                          //               bottom: calculator.percentToPixel(2, context),
                          //             ),
                          //             child: Row(
                          //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          //               children: [
                          //                 Column(
                          //                   crossAxisAlignment: CrossAxisAlignment.start,
                          //                   children: [
                          //                     Text(
                          //                       eqReport[0].loc.substring(0, eqReport[0].loc.length - 1).split("位於")[1],
                          //                       style: const TextStyle(
                          //                           fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                          //                     ),
                          //                     Text(
                          //                       DateFormat("yyyy/MM/dd HH:mm:ss").format(
                          //                         TZDateTime.fromMillisecondsSinceEpoch(
                          //                           getLocation("Asia/Taipei"),
                          //                           eqReport[0].time,
                          //                         ),
                          //                       ),
                          //                       style: const TextStyle(color: Color(0xFFc9c9c9), fontSize: 16),
                          //                       textAlign: TextAlign.left,
                          //                     ),
                          //                     Text(
                          //                       "規模${eqReport[0].mag}　深度${eqReport[0].depth}公里",
                          //                       style: const TextStyle(fontSize: 18, letterSpacing: 2),
                          //                     ),
                          //                   ],
                          //                 ),
                          //                 Container(
                          //                   alignment: Alignment.center,
                          //                   width: calculator.percentToPixel(15, context),
                          //                   height: calculator.percentToPixel(15, context),
                          //                   decoration: BoxDecoration(
                          //                     borderRadius: BorderRadius.circular(10),
                          //                     color: context.colors.intensity(eqReport[0].intensity),
                          //                   ),
                          //                   child: Text(
                          //                     intensityToNumberString(eqReport[0].intensity),
                          //                     style: TextStyle(
                          //                       fontSize: 36,
                          //                       fontWeight: FontWeight.w900,
                          //                       color: context.colors.onIntensity(eqReport[0].intensity),
                          //                     ),
                          //                   ),
                          //                 )
                          //               ],
                          //             ),
                          //           )
                          //         ],
                          //       ),
                          //     ),
                          //   )
                          : const Center(child: CircularProgressIndicator())
                    ],
                  ),
                )
              ],
            )),
      );
    }
  }
}

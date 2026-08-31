import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel2;
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';


import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'login_screen.dart';
import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_messaging/firebase_messaging.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ============================================================
  // FIREBASE CLOUD MESSAGING
  // ============================================================

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ============================================================
  // FCM - ELŐTÉRBEN ÉRKEZŐ ÜZENETEK
  // ============================================================

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("FCM üzenet érkezett!");

    print("Cím: ${message.notification?.title}");
    print("Szöveg: ${message.notification?.body}");
  });

  runApp(const DinaApp());
}

/* ============================================================
   FIRESTORE - FELHASZNÁLÓ MENTÉSE + FCM TOKEN
   ============================================================ */

Future<void> saveUserToFirestore(User user) async {
  final userRef = FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid);

  final document = await userRef.get();

  // ============================================================
  // FELHASZNÁLÓ LÉTREHOZÁSA, HA MÉG NINCS
  // ============================================================

  if (!document.exists) {
    await userRef.set({
      "email": user.email ?? "",
      "name": user.displayName ?? "Felhasználó",
      "join_date": FieldValue.serverTimestamp(),
      "szabadsag": 0,
    });
  }

  // ============================================================
  // FCM TOKEN LEKÉRÉSE
  // ============================================================

  try {
    print("🔔 FCM: token lekérése indul...");

    final permission =
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print(
      "🔔 FCM engedély állapot: ${permission.authorizationStatus}",
    );

    print("🔔 FCM: getToken() indul...");

    final fcmToken =
    await FirebaseMessaging.instance.getToken(
      vapidKey:
      "BN9XgSDYTLOEt1CZe-jvIHup2YypPi7bRe3G3mgvtOrqypoXd2StHE-PZw4q0JEKfEM0VOXUrU6_wUD1X-TR1vE",
      serviceWorkerScriptPath:
      "firebase-messaging-sw.js",
    );

    print("🔔 FCM TOKEN: $fcmToken");

    if (fcmToken != null && fcmToken.isNotEmpty) {
      await userRef.set(
        {
          "fcmToken": fcmToken,
        },
        SetOptions(merge: true),
      );

      print("✅ FCM token elmentve Firestore-ba!");
    } else {
      print("❌ FCM TOKEN NULL vagy üres!");
    }
  } catch (e, stackTrace) {
    print("❌ FCM HIBA: $e");
    print("❌ STACK TRACE: $stackTrace");
  }
}

/* ============================================================
   APP
   ============================================================ */

class DinaApp extends StatelessWidget {
  const DinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "DINA'95 Jelenléti Rendszer",

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976E8),
        ),
      ),

      home: const AuthGate(),
    );
  }
}

/* ============================================================
   AUTH GATE
   ============================================================ */

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF101E2E),
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          return FutureBuilder(
            future: saveUserToFirestore(
              snapshot.data!,
            ),

            builder: (
                context,
                userSnapshot,
                ) {
              if (userSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF101E2E),
                  body: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                );
              }

              if (userSnapshot.hasError) {
                return Scaffold(
                  backgroundColor:
                  const Color(0xFF101E2E),

                  body: Center(
                    child: Padding(
                      padding:
                      const EdgeInsets.all(20),

                      child: Text(
                        "Hiba a felhasználó mentésekor:\n\n"
                            "${userSnapshot.error}",

                        textAlign:
                        TextAlign.center,

                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return const HomeScreen();
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}

/* ============================================================
   HOME SCREEN
   ============================================================ */

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {

  int selectedIndex = 0;

  bool isAdmin = false;
  bool isLoadingAdmin = true;

  @override
  void initState() {
    super.initState();

    _loadAdminStatus();
  }

  /* ============================================================
     ADMIN JOGOSULTSÁG LEKÉRÉSE
     ============================================================ */

  Future<void> _loadAdminStatus() async {

    try {

      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          isAdmin = false;
          isLoadingAdmin = false;
        });

        return;
      }

      final userDoc =
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final data =
      userDoc.data();

      setState(() {

        isAdmin =
            data?["admin"] == true;

        isLoadingAdmin = false;
      });

    } catch (e) {

      setState(() {

        isAdmin = false;
        isLoadingAdmin = false;

      });
    }
  }

  /* ============================================================
     KIJELENTKEZÉS
     ============================================================ */

  Future<void> logout() async {

    try {

      await FirebaseAuth.instance
          .signOut();

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(

        SnackBar(
          backgroundColor:
          Colors.red,

          content: Text(
            "Kijelentkezési hiba: $e",
          ),
        ),
      );
    }
  }

  /* ============================================================
     BUILD
     ============================================================ */

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      const Color(0xFFF5F7FA),

      body: SafeArea(

        bottom: false,

        child: IndexedStack(

          index: selectedIndex,

          children: [

            /* ==================================================
               0 - KEZDŐLAP
               ================================================== */

            DashboardPage(
              onLogout: logout,
            ),

            /* ==================================================
               1 - JELENLÉT
               ================================================== */

            const AttendancePage(),

            /* ==================================================
               2 - NAPTÁR
               ================================================== */

            const CalendarPage(),

            /* ==================================================
               3 - PROJEKTEK
               ================================================== */

            const ProjectsPage(),

            /* ==================================================
               4 - SZERSZÁMOK
               ================================================== */

            const ToolsPage(),

            /* ==================================================
               5 - TÖBB
               ================================================== */

            MorePage(
              onLogout: logout,
            ),

            /* ==================================================
               6 - ADMIN
               ================================================== */

            const AdminPage(),
          ],
        ),
      ),

      /* ========================================================
         ALSÓ NAVIGÁCIÓ
         ======================================================== */

      bottomNavigationBar:

      isLoadingAdmin

          ? const SizedBox(
        height: 72,
      )

          : _BottomNavigation(

        selectedIndex:
        selectedIndex,

        isAdmin:
        isAdmin,

        onSelected:
            (index) {

          setState(() {

            selectedIndex =
                index;

          });
        },
      ),
    );
  }
}

/* ============================================================
   DASHBOARD
   ============================================================ */

class DashboardPage extends StatefulWidget {
  final Future<void> Function() onLogout;

  const DashboardPage({
    super.key,
    required this.onLogout,
  });

  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState
    extends State<DashboardPage> {

  // Alapból a mai nap van kiválasztva.
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics:
      const BouncingScrollPhysics(),

      slivers: [
        SliverToBoxAdapter(
          child: _TopHeader(
            onLogout: widget.onLogout,
          ),
        ),

        SliverPadding(
          padding:
          const EdgeInsets.fromLTRB(
            16,
            20,
            16,
            0,
          ),

          sliver:
          const SliverToBoxAdapter(
            child: _WelcomeSection(),
          ),
        ),

        SliverPadding(
          padding:
          const EdgeInsets.fromLTRB(
            16,
            14,
            16,
            0,
          ),

          sliver:
          const SliverToBoxAdapter(
            child: _StatsGrid(),
          ),
        ),

        /* ====================================================
           NAPTÁR + NAPI ÁTTEKINTÉS
           ==================================================== */

        SliverPadding(
          padding:
          const EdgeInsets.fromLTRB(
            16,
            14,
            16,
            0,
          ),

          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Expanded(
                  child: _DailyOverview(
                    selectedDate:
                    selectedDate,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _CalendarCard(
                    selectedDate:
                    selectedDate,

                    onDateSelected:
                        (date) {
                      setState(() {
                        selectedDate =
                            date;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        /* ====================================================
           DOLGOZÓK + PROJEKTEK
           ==================================================== */

        SliverPadding(
          padding:
          const EdgeInsets.fromLTRB(
            16,
            14,
            16,
            0,
          ),

          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Expanded(
                  child: _EmployeesCard(
                    selectedDate:
                    selectedDate,
                  ),
                ),

                const SizedBox(width: 10),

                const Expanded(
                  child: _ProjectsCard(),
                ),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding:
          const EdgeInsets.fromLTRB(
            16,
            14,
            16,
            24,
          ),

          sliver:
          const SliverToBoxAdapter(
            child: _BottomBanner(),
          ),
        ),
      ],
    );
  }
}

/* ============================================================
   TOP HEADER
   ============================================================ */

class _TopHeader extends StatelessWidget {
  final Future<void> Function() onLogout;

  const _TopHeader({
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,

      padding:
      const EdgeInsets.symmetric(
        horizontal: 18,
      ),

      decoration:
      const BoxDecoration(
        color: Color(0xFF101E2E),
      ),

      child: Row(
        children: [
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor:
                Colors.white,

                shape:
                const RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),

                builder: (context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,

                      children: [
                        const SizedBox(
                            height: 10),

                        Container(
                          width: 40,
                          height: 4,

                          decoration:
                          BoxDecoration(
                            color: Colors
                                .grey
                                .shade300,

                            borderRadius:
                            BorderRadius
                                .circular(
                              10,
                            ),
                          ),
                        ),

                        const SizedBox(
                            height: 15),

                        ListTile(
                          leading:
                          const Icon(
                            Icons.logout,
                            color: Colors.red,
                          ),

                          title:
                          const Text(
                            "Kijelentkezés",

                            style:
                            TextStyle(
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),

                          onTap:
                              () async {
                            Navigator.pop(
                                context);

                            await onLogout();
                          },
                        ),

                        const SizedBox(
                            height: 10),
                      ],
                    ),
                  );
                },
              );
            },

            icon:
            const Icon(
              Icons.menu,
              color: Colors.white,
              size: 27,
            ),
          ),

          const Spacer(),

          Column(
            mainAxisAlignment:
            MainAxisAlignment.center,

            children: [
              RichText(
                text:
                const TextSpan(
                  children: [
                    TextSpan(
                      text: "DINA'",

                      style:
                      TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),

                    TextSpan(
                      text: "95",

                      style:
                      TextStyle(
                        color:
                        Color(0xFF2388F2),
                        fontSize: 25,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const Text(
                "JELENLÉTI RENDSZER",

                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  letterSpacing: 1,
                  fontWeight:
                  FontWeight.w500,
                ),
              ),
            ],
          ),

          const Spacer(),

          Stack(
            children: [
              IconButton(
                onPressed: () {},

                icon:
                const Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                  size: 27,
                ),
              ),

              Positioned(
                right: 10,
                top: 10,

                child: Container(
                  width: 7,
                  height: 7,

                  decoration:
                  const BoxDecoration(
                    color:
                    Color(0xFF1976E8),
                    shape:
                    BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   WELCOME
   ============================================================ */

class _WelcomeSection
    extends StatelessWidget {
  const _WelcomeSection();

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance
            .currentUser;

    final String userName =
    user?.displayName
        ?.isNotEmpty ==
        true
        ? user!.displayName!
        : "Felhasználó";

    return Container(
      height: 92,

      decoration:
      BoxDecoration(
        borderRadius:
        BorderRadius.circular(10),
        color: Colors.white,

        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              .04,
            ),
            blurRadius: 10,
            offset:
            const Offset(0, 2),
          ),
        ],
      ),

      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 150,

            child: ClipRRect(
              borderRadius:
              const BorderRadius
                  .only(
                topRight:
                Radius.circular(10),
                bottomRight:
                Radius.circular(10),
              ),

              child: Container(
                decoration:
                const BoxDecoration(
                  gradient:
                  LinearGradient(
                    colors: [
                      Color(0xFF596D7D),
                      Color(0xFF172A3B),
                    ],
                  ),
                ),

                child:
                const Icon(
                  Icons.construction,
                  color:
                  Colors.white24,
                  size: 60,
                ),
              ),
            ),
          ),

          Container(
            width: 250,

            padding:
            const EdgeInsets.only(
              left: 10,
              top: 15,
            ),

            decoration:
            BoxDecoration(
              gradient:
              LinearGradient(
                colors: [
                  Colors.white,
                  Colors.white
                      .withOpacity(.95),
                  Colors.transparent,
                ],
              ),
            ),

            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,

              children: [
                Text(
                  "Üdvözöljük, $userName!",

                  maxLines: 1,

                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  const TextStyle(
                    fontSize: 19,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    Color(0xFF20252B),
                  ),
                ),

                const SizedBox(
                    height: 5),

                const Text(
                  "Itt az összes fontos információ egy helyen.",

                  style:
                  TextStyle(
                    fontSize: 9.5,
                    color:
                    Color(0xFF8A9098),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   STATISTICS - FIRESTORE
   ============================================================ */

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  String get today {
    final now = DateTime.now();

    return "${now.year.toString().padLeft(4, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')}";
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();

    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    if (m == 0) {
      return "$h ó";
    }

    return "$h ó ${m.toString().padLeft(2, '0')} p";
  }

  int _timeToMinutes(String time) {
    final parts = time.split(":");

    if (parts.length < 2) {
      return 0;
    }

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return hour * 60 + minute;
  }

  double _calculateHours(
      String checkIn,
      String checkOut,
      ) {
    var start = _timeToMinutes(checkIn);
    var end = _timeToMinutes(checkOut);

    if (end < start) {
      end += 24 * 60;
    }

    return (end - start) / 60.0;
  }

  /* ============================================================
     AKTUÁLIS FELHASZNÁLÓ HAVI LEDOLGOZOTT ÓRÁI (TÚLÓRÁVAL EGYÜTT)
     ============================================================ */

  Future<double> _getMonthlyWorkedHours() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return 0;
    }

    final now = DateTime.now();

    final firstDay = DateTime(
      now.year,
      now.month,
      1,
    );

    final nextMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    );

    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("checkins")
        .get();

    int totalMinutes = 0;

    for (final document in snapshot.docs) {
      final data = document.data();

      /* ==========================================================
       DÁTUM ELLENŐRZÉSE
       ========================================================== */

      DateTime? date;

      try {
        final parts = document.id.split("-");

        if (parts.length != 3) {
          continue;
        }

        date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      } catch (_) {
        continue;
      }

      // Csak az aktuális hónapot számoljuk
      if (date.isBefore(firstDay) ||
          !date.isBefore(nextMonth)) {
        continue;
      }

      /* ==========================================================
       NORMÁL MUNKAIDŐ
       ========================================================== */

      final checkIn =
      data["checkInTime"]?.toString().trim();

      final checkOut =
      data["checkOutTime"]?.toString().trim();

      if (checkIn == null ||
          checkOut == null ||
          checkIn.isEmpty ||
          checkOut.isEmpty) {
        continue;
      }

      int normalStart =
      _timeToMinutes(checkIn);

      int normalEnd =
      _timeToMinutes(checkOut);

      if (normalEnd < normalStart) {
        normalEnd += 24 * 60;
      }

      final normalMinutes =
          normalEnd - normalStart;

      totalMinutes += normalMinutes;

      /* ==========================================================
       TÚLÓRA
       ========================================================== */

      final overtimeDecision =
      data["overtimeDecision"];

      final overtimeStart =
      data["overtimeStart"]?.toString().trim();

      final overtimeEnd =
      data["overtimeEnd"]?.toString().trim();

      /*
     * Csak akkor adjuk hozzá a túlórát,
     * ha a dolgozó túlórázott és
     * mindkét túlóra időpont rendelkezésre áll.
     */

      if (overtimeDecision == true &&
          overtimeStart != null &&
          overtimeEnd != null &&
          overtimeStart.isNotEmpty &&
          overtimeEnd.isNotEmpty) {
        int overtimeStartMinutes =
        _timeToMinutes(overtimeStart);

        int overtimeEndMinutes =
        _timeToMinutes(overtimeEnd);

        if (overtimeEndMinutes <
            overtimeStartMinutes) {
          overtimeEndMinutes += 24 * 60;
        }

        final overtimeMinutes =
            overtimeEndMinutes -
                overtimeStartMinutes;

        totalMinutes += overtimeMinutes;
      }
    }

    return totalMinutes / 60.0;
  }

  /* ============================================================
     AKTÍV PROJEKTEK SZÁMA
     ============================================================ */

  Future<int> _getActiveProjectCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection("projects")
        .get();

    int count = 0;

    for (final project in snapshot.docs) {
      if (project.id == "Szabi") {
        continue;
      }

      final data = project.data();

      final workers =
      (data["Munkások száma"] ?? 0) as num;

      if (workers > 0) {
        count++;
      }
    }

    return count;
  }

  /* ============================================================
     MA JELENLÉVŐ DOLGOZÓK SZÁMA
     ============================================================ */

  Future<int> _getTodayPresentCount() async {
    final users = await FirebaseFirestore.instance
        .collection("users")
        .get();

    int count = 0;

    for (final user in users.docs) {
      final checkin = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.id)
          .collection("checkins")
          .doc(today)
          .get();

      if (!checkin.exists) {
        continue;
      }

      final data = checkin.data();

      final project =
      data?["project"]?.toString();

      final checkIn =
      data?["checkInTime"]?.toString();

      final checkOut =
      data?["checkOutTime"]?.toString();

      if (project == "Szabi") {
        continue;
      }

      if (checkIn != null &&
          checkIn.isNotEmpty &&
          (checkOut == null || checkOut.isEmpty)) {
        count++;
      }
    }

    return count;
  }

  /* ============================================================
     BUILD
     ============================================================ */

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .snapshots(),

      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const SizedBox(
            height: 133,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1976E8),
              ),
            ),
          );
        }

        if (userSnapshot.hasError) {
          return const SizedBox(
            height: 133,
            child: Center(
              child: Text(
                "Nem sikerült betölteni a statisztikákat.",
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.red,
                ),
              ),
            ),
          );
        }

        final users =
            userSnapshot.data?.docs ?? [];

        final workerCount = users.length;

        return FutureBuilder<int>(
          future: _getTodayPresentCount(),

          builder: (context, presentSnapshot) {
            final presentCount =
                presentSnapshot.data ?? 0;

            final attendancePercentage =
            workerCount > 0
                ? presentCount / workerCount
                : 0.0;

            return FutureBuilder<double>(
              future: _getMonthlyWorkedHours(),

              builder: (context, hoursSnapshot) {
                final monthlyHours =
                    hoursSnapshot.data ?? 0;

                return FutureBuilder<int>(
                  future: _getActiveProjectCount(),

                  builder: (
                      context,
                      projectSnapshot,
                      ) {
                    final activeProjectCount =
                        projectSnapshot.data ?? 0;

                    return SizedBox(
                        width: double.infinity,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                        /* ==================================================
                           DOLGOZÓK
                           ================================================== */

                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const _AllEmployeesPage(
                                    onlyPresent: false,
                                  ),
                                ),
                              );
                            },

                            child: _StatCard(
                              icon: Icons.people_outline,

                              color:
                              const Color(0xFF1269DC),

                              title: "Dolgozók",

                              value:
                              "$workerCount fő",

                              subtitle:
                              "Összes dolgozó",

                              progress:
                              workerCount > 0
                                  ? 1.0
                                  : 0.0,
                            ),
                          ),
                        ),

                        const SizedBox(width: 7),

                        /* ==================================================
                           MAI JELENLÉT
                           ================================================== */

                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const _AllEmployeesPage(
                                    onlyPresent: true,
                                  ),
                                ),
                              );
                            },

                            child: _StatCard(
                              icon:
                              Icons.calendar_month_outlined,

                              color:
                              const Color(0xFF22A76A),

                              title:
                              "Mai jelenlét",

                              value:
                              "$presentCount fő",

                              subtitle:
                              "${(attendancePercentage * 100).round()}% jelenlét",

                              progress:
                              attendancePercentage
                                  .clamp(0.0, 1.0),
                            ),
                          ),
                        ),

                        const SizedBox(width: 7),

                        /* ==================================================
                           HAVI LEDOLGOZOTT ÓRÁK
                           ================================================== */

                        Expanded(
                          child: _StatCard(
                            icon:
                            Icons.access_time,

                            color:
                            const Color(0xFFF28A18),

                            title:
                            "Ledolgozott órák",

                            value:
                            _formatHours(
                              monthlyHours,
                            ),

                            subtitle:
                            "Ebben a hónapban",

                            progress:
                            monthlyHours > 0
                                ? (monthlyHours / 160)
                                .clamp(
                              0.0,
                              1.0,
                            )
                                : 0.0,
                          ),
                        ),

                        const SizedBox(width: 7),

                        /* ==================================================
                           AKTÍV PROJEKTEK
                           ================================================== */

                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const _ActiveProjectsPage(),
                                ),
                              );
                            },

                            child: _StatCard(
                              icon:
                              Icons.assignment_outlined,

                              color:
                              const Color(0xFF8543D8),

                              title:
                              "Aktív projektek",

                              value:
                              "$activeProjectCount db",

                              subtitle:
                              "Jelenleg dolgoznak rajta",

                              progress:
                              activeProjectCount > 0
                                  ? 1.0
                                  : 0.0,
                            ),
                          ),
                        ),
                      ],
                    )
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}


/* ============================================================
   ÖSSZES DOLGOZÓ / MA JELENLÉVŐ DOLGOZÓK
   ============================================================ */

class _AllEmployeesPage extends StatelessWidget {
  final bool onlyPresent;
  final DateTime? selectedDate;

  const _AllEmployeesPage({
    super.key,
    this.onlyPresent = false,
    this.selectedDate,
  });

  DateTime get _date => selectedDate ?? DateTime.now();

  String get selectedDateString {
    return "${_date.year.toString().padLeft(4, '0')}-"
        "${_date.month.toString().padLeft(2, '0')}-"
        "${_date.day.toString().padLeft(2, '0')}";
  }

  String get formattedDate {
    return "${_date.year}. "
        "${_date.month.toString().padLeft(2, '0')}. "
        "${_date.day.toString().padLeft(2, '0')}.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor: const Color(0xFF101E2E),
        foregroundColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: Text(
          onlyPresent
              ? "MAI JELENLÉT"
              : "ÖSSZES DOLGOZÓ",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),

        centerTitle: true,
      ),

      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .snapshots(),

          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1976E8),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Nem sikerült betölteni a dolgozókat:\n\n"
                        "${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                    ),
                  ),
                ),
              );
            }

            final allEmployees =
                snapshot.data?.docs ?? [];

            if (allEmployees.isEmpty) {
              return const Center(
                child: Text(
                  "Nincs dolgozó az adatbázisban.",
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A9098),
                  ),
                ),
              );
            }

            return FutureBuilder<
                List<QueryDocumentSnapshot<
                    Map<String, dynamic>>>>(
              future: _getEmployees(
                allEmployees,
              ),

              builder: (context, employeeSnapshot) {
                if (employeeSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1976E8),
                    ),
                  );
                }

                final employees =
                    employeeSnapshot.data ?? [];

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      color: Colors.white,

                      child: Row(
                        children: [
                          Icon(
                            onlyPresent
                                ? Icons.people_alt_outlined
                                : Icons.calendar_today,
                            size: 15,
                            color:
                            const Color(0xFF1976E8),
                          ),

                          const SizedBox(width: 8),

                          Text(
                            onlyPresent
                                ? "Ma jelenlévő dolgozók"
                                : "Összes dolgozó",
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF343A40),
                            ),
                          ),

                          const Spacer(),

                          Text(
                            "${employees.length} fő",
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1976E8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 1,
                      color: const Color(0xFFE5E9ED),
                    ),

                    if (employees.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            onlyPresent
                                ? "Jelenleg nincs becsekkolt dolgozó."
                                : "Nincs dolgozó.",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A9098),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          physics:
                          const BouncingScrollPhysics(),

                          padding:
                          const EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            24,
                          ),

                          itemCount: employees.length,

                          itemBuilder: (context, index) {
                            final employee =
                            employees[index];

                            return Container(
                              margin:
                              const EdgeInsets.only(
                                bottom: 6,
                              ),

                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),

                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                  const Color(0xFFE8ECF0),
                                ),
                              ),

                              child:
                              _FirestoreEmployeeRow(
                                employeeId:
                                employee.id,

                                employeeData:
                                employee.data(),

                                selectedDate:
                                selectedDateString,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<QueryDocumentSnapshot<
      Map<String, dynamic>>>> _getEmployees(
      List<QueryDocumentSnapshot<
          Map<String, dynamic>>>
      allEmployees,
      ) async {
    if (!onlyPresent) {
      return allEmployees;
    }

    final result =
    <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final employee in allEmployees) {
      final checkin = await FirebaseFirestore.instance
          .collection("users")
          .doc(employee.id)
          .collection("checkins")
          .doc(selectedDateString)
          .get();

      if (!checkin.exists) {
        continue;
      }

      final data = checkin.data();

      if (data == null) {
        continue;
      }

      final project =
      data["project"]?.toString();

      final checkInTime =
      data["checkInTime"]?.toString();

      // A Szabi nem számít jelenlévő dolgozónak.
      if (project == "Szabi") {
        continue;
      }

      if (checkInTime != null &&
          checkInTime.isNotEmpty) {
        result.add(employee);
      }
    }

    return result;
  }
}


/* ============================================================
   AKTÍV PROJEKTEK
   ============================================================ */

class _ActiveProjectsPage extends StatelessWidget {
  const _ActiveProjectsPage();

  Future<List<Map<String, dynamic>>> _loadActiveProjects() async {
    final snapshot = await FirebaseFirestore.instance
        .collection("projects")
        .get();

    final List<Map<String, dynamic>> projects = [];

    for (final document in snapshot.docs) {
      if (document.id == "Szabi") {
        continue;
      }

      final data = document.data();

      final workers = (data["Munkások száma"] ?? 0) as num;

      if (workers <= 0) {
        continue;
      }

      projects.add({
        "name": document.id,
        "workers": workers.toInt(),
      });
    }

    projects.sort(
          (a, b) => (b["workers"] as int).compareTo(
        a["workers"] as int,
      ),
    );

    return projects;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Aktív projektek",
        ),
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadActiveProjects(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Hiba történt:\n${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final projects = snapshot.data ?? [];

          if (projects.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "Jelenleg egyetlen projekten sem dolgoznak.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: projects.length,

            itemBuilder: (context, index) {
              final project = projects[index];

              final name =
                  project["name"]?.toString() ?? "";

              final workers =
              project["workers"] as int;

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 8,
                ),

                child: Padding(
                  padding: const EdgeInsets.all(12),

                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.center,

                    children: [
                      /* ==========================================
                         IKON
                         ========================================== */

                      const CircleAvatar(
                        radius: 22,
                        child: Icon(
                          Icons.assignment_outlined,
                        ),
                      ),

                      const SizedBox(width: 12),

                      /* ==========================================
                         PROJEKT INFORMÁCIÓ
                         ========================================== */

                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [
                            Text(
                              name,

                              maxLines: 2,

                              overflow:
                              TextOverflow.ellipsis,

                              style: const TextStyle(
                                fontWeight:
                                FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),

                            const SizedBox(height: 3),

                            const Text(
                              "Jelenleg dolgoznak rajta",

                              maxLines: 1,

                              overflow:
                              TextOverflow.ellipsis,

                              style: TextStyle(
                                fontSize: 12,
                                color:
                                Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      /* ==========================================
                         DOLGOZÓK SZÁMA
                         ========================================== */

                      Container(
                        constraints:
                        const BoxConstraints(
                          minWidth: 55,
                        ),

                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),

                        decoration: BoxDecoration(
                          borderRadius:
                          BorderRadius.circular(20),

                          color:
                          const Color(0xFF8543D8)
                              .withOpacity(0.1),
                        ),

                        child: FittedBox(
                          fit: BoxFit.scaleDown,

                          child: Text(
                            "$workers fő",

                            maxLines: 1,

                            style: const TextStyle(
                              fontWeight:
                              FontWeight.bold,

                              color:
                              Color(0xFF8543D8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;
  final double progress;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Nem használunk fix magasságot.
      // Így Androidon sem tud alul overflowolni.
      constraints: const BoxConstraints(
        minHeight: 125,
      ),

      padding: const EdgeInsets.all(9),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE8ECF0),
        ),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF454B52),
            ),
          ),

          const SizedBox(height: 1),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E252C),
              ),
            ),
          ),

          const SizedBox(height: 1),

          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              fontSize: 7.5,
              color: Color(0xFF9AA0A7),
            ),
          ),

          const SizedBox(height: 6),

          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: const Color(0xFFE9EDF1),
              valueColor: AlwaysStoppedAnimation<Color>(
                color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
NAPI ÁTTEKINTÉS
============================================================ */

class _DailyOverview extends StatelessWidget {
  final DateTime selectedDate;

  const _DailyOverview({
    required this.selectedDate,
  });

  String get dateString {
    return "${selectedDate.year.toString().padLeft(4, '0')}-"
        "${selectedDate.month.toString().padLeft(2, '0')}-"
        "${selectedDate.day.toString().padLeft(2, '0')}";
  }

  String get formattedDate {
    return "${selectedDate.year}. "
        "${selectedDate.month.toString().padLeft(2, '0')}. "
        "${selectedDate.day.toString().padLeft(2, '0')}.";
  }

  // ------------------------------------------------------------
  // IDŐ ÁTVÁLTÁSA PERCRE
  // ------------------------------------------------------------

  int _timeToMinutes(String time) {
    final parts = time.split(":");

    if (parts.length != 2) {
      return 0;
    }

    final hour =
        int.tryParse(parts[0]) ?? 0;

    final minute =
        int.tryParse(parts[1]) ?? 0;

    return hour * 60 + minute;
  }

  // ------------------------------------------------------------
  // LEDOLGOZOTT IDŐ KISZÁMÍTÁSA
  // ------------------------------------------------------------

  String _calculateWorkedTime(
      String startTime,
      String endTime,
      ) {
    final start =
    _timeToMinutes(startTime);

    var end =
    _timeToMinutes(endTime);

    if (end < start) {
      end += 24 * 60;
    }

    final difference =
        end - start;

    final hours =
        difference ~/ 60;

    final minutes =
        difference % 60;

    return "$hours óra "
        "${minutes.toString().padLeft(2, '0')} perc";
  }

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _SectionCard(
        title: "NAPI ÁTTEKINTÉS",
        subtitle: formattedDate,
        child: const Center(
          child: Text(
            "Nincs bejelentkezett felhasználó.",
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFF8A9098),
            ),
          ),
        ),
      );
    }

    final checkinRef =
    FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("checkins")
        .doc(dateString);

    return _SectionCard(
      title: "NAPI ÁTTEKINTÉS",
      subtitle: formattedDate,

      child: FutureBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        future: checkinRef.get(),

        builder: (context, snapshot) {

          // --------------------------------------------------
          // BETÖLTÉS
          // --------------------------------------------------

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const SizedBox(
              height: 120,

              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1976E8),
                ),
              ),
            );
          }

          // --------------------------------------------------
          // HIBA
          // --------------------------------------------------

          if (snapshot.hasError) {
            return const SizedBox(
              height: 120,

              child: Center(
                child: Text(
                  "Nem sikerült betölteni az adatokat.",
                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.red,
                  ),
                ),
              ),
            );
          }

          // --------------------------------------------------
          // NINCS ADAT
          // --------------------------------------------------

          if (!snapshot.hasData ||
              !snapshot.data!.exists) {
            return const SizedBox(
              height: 120,

              child: Center(
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,

                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 30,
                      color: Color(0xFF9AA0A7),
                    ),

                    SizedBox(height: 8),

                    Text(
                      "Nincs munkavégzés rögzítve.",

                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF8A9098),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // --------------------------------------------------
          // FIRESTORE ADATOK
          // --------------------------------------------------

          final data =
              snapshot.data!.data() ?? {};

          final project =
              data["project"]
                  ?.toString() ??
                  "";

          final checkIn =
          data["checkInTime"]
              ?.toString();

          final checkOut =
          data["checkOutTime"]
              ?.toString();

          // --------------------------------------------------
          // SZABADSÁG
          // --------------------------------------------------

          if (project == "Szabi") {
            return Column(
              children: [
                _InfoRow(
                  icon: Icons.beach_access,

                  iconColor:
                  const Color(0xFF8151D8),

                  title: "Állapot",

                  value: "Szabadság",
                ),

                const SizedBox(
                  height: 10,
                ),

                const Text(
                  "Ezen a napon szabadságon voltál.",

                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF8A9098),
                  ),
                ),
              ],
            );
          }

          // --------------------------------------------------
          // LEDOLGOZOTT IDŐ
          // --------------------------------------------------

          String workedTime =
              "Folyamatban";

          if (checkIn != null &&
              checkOut != null) {
            workedTime =
                _calculateWorkedTime(
                  checkIn,
                  checkOut,
                );
          }

          // --------------------------------------------------
          // TÚLÓRA ADATOK
          // --------------------------------------------------

          final hasOvertime =
              data["overtimeDecision"] == true;

          final overtimeStart =
          data["overtimeStart"]
              ?.toString();

          final overtimeEnd =
          data["overtimeEnd"]
              ?.toString();

          String overtimeWorkedTime =
              "Nincs";

          if (hasOvertime &&
              overtimeStart != null &&
              overtimeEnd != null &&
              overtimeStart.isNotEmpty &&
              overtimeEnd.isNotEmpty) {

            overtimeWorkedTime =
                _calculateWorkedTime(
                  overtimeStart,
                  overtimeEnd,
                );
          }

          // --------------------------------------------------
          // NAPI ADATOK
          // --------------------------------------------------

          return Column(
            children: [

              // ------------------------------------------------
              // LEDOLGOZOTT ÓRÁK
              // ------------------------------------------------

              _InfoRow(
                icon: Icons.access_time,

                iconColor:
                const Color(0xFF1676E8),

                title: "Ledolgozott órák",

                value: workedTime,
              ),

              // ------------------------------------------------
              // BECSSEKKOLÁS
              // ------------------------------------------------

              _InfoRow(
                icon: Icons.login,

                iconColor:
                const Color(0xFF22B573),

                title: "Becsekkolás",

                value: checkIn ?? "-",
              ),

              // ------------------------------------------------
              // KICSEKKOLÁS
              // ------------------------------------------------

              _InfoRow(
                icon: Icons.logout,

                iconColor:
                const Color(0xFFF09A19),

                title: "Kicsekkolás",

                value:
                checkOut ??
                    "Még dolgozik",
              ),

              // ------------------------------------------------
              // TÚLÓRA KEZDETE
              // ------------------------------------------------

              _InfoRow(
                icon: Icons.play_arrow,

                iconColor:
                const Color(0xFFE85D04),

                title: "Túlóra kezdete",

                value:
                hasOvertime &&
                    overtimeStart != null &&
                    overtimeStart.isNotEmpty
                    ? overtimeStart
                    : "-",
              ),

              // ------------------------------------------------
              // TÚLÓRA VÉGE
              // ------------------------------------------------

              _InfoRow(
                icon: Icons.stop,

                iconColor:
                const Color(0xFFD64545),

                title: "Túlóra vége",

                value:
                hasOvertime
                    ? overtimeEnd ??
                    "Még dolgozik"
                    : "-",
              ),

              // ------------------------------------------------
              // LEDOLGOZOTT TÚLÓRA
              // ------------------------------------------------

              _InfoRow(
                icon: Icons.more_time,

                iconColor:
                const Color(0xFFE85D04),

                title: "Ledolgozott túlóra",

                value: overtimeWorkedTime,
              ),

              // ------------------------------------------------
              // PROJEKT
              // ------------------------------------------------

              _InfoRow(
                icon:
                Icons.business_outlined,

                iconColor:
                const Color(0xFF8151D8),

                title: "Projekt",

                value: project.isNotEmpty
                    ? project
                    : "-",
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow
    extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,

      decoration:
      const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
            Color(0xFFECEFF2),
          ),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,

            decoration:
            BoxDecoration(
              color:
              iconColor.withOpacity(.12),
              shape:
              BoxShape.circle,
            ),

            child: Icon(
              icon,
              color: iconColor,
              size: 13,
            ),
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Text(
              title,

              style:
              const TextStyle(
                fontSize: 8.5,
                color:
                Color(0xFF4B525A),
              ),
            ),
          ),

          Flexible(
            child: Text(
              value,

              maxLines: 1,

              overflow:
              TextOverflow.ellipsis,

              style: TextStyle(
                fontSize: 8.5,
                fontWeight:
                FontWeight.w700,
                color: iconColor,
              ),
            ),
          ),

          const Icon(
            Icons.chevron_right,
            size: 14,
            color:
            Color(0xFF9AA0A7),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   NAPTÁR
   ============================================================ */

class _CalendarCard
    extends StatefulWidget {
  final DateTime selectedDate;

  final ValueChanged<DateTime>
  onDateSelected;

  const _CalendarCard({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<_CalendarCard> createState() =>
      _CalendarCardState();
}

class _CalendarCardState
    extends State<_CalendarCard> {

  late DateTime currentMonth;

  @override
  void initState() {
    super.initState();

    currentMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      1,
    );
  }

  String monthName(int month) {
    const months = [
      "Január",
      "Február",
      "Március",
      "Április",
      "Május",
      "Június",
      "Július",
      "Augusztus",
      "Szeptember",
      "Október",
      "November",
      "December",
    ];

    return months[month - 1];
  }

  void previousMonth() {
    setState(() {
      currentMonth = DateTime(
        currentMonth.year,
        currentMonth.month - 1,
        1,
      );
    });
  }

  void nextMonth() {
    setState(() {
      currentMonth = DateTime(
        currentMonth.year,
        currentMonth.month + 1,
        1,
      );
    });
  }

  List<DateTime>
  generateCalendarDays() {
    final firstDayOfMonth =
    DateTime(
      currentMonth.year,
      currentMonth.month,
      1,
    );

    final lastDayOfMonth =
    DateTime(
      currentMonth.year,
      currentMonth.month + 1,
      0,
    );

    final firstWeekday =
        firstDayOfMonth.weekday;

    final daysInMonth =
        lastDayOfMonth.day;

    final List<DateTime> days = [];

    // Előző hónap napjai
    for (
    int i = firstWeekday - 1;
    i > 0;
    i--
    ) {
      days.add(
        DateTime(
          currentMonth.year,
          currentMonth.month,
          1 - i,
        ),
      );
    }

    // Aktuális hónap napjai
    for (
    int i = 1;
    i <= daysInMonth;
    i++
    ) {
      days.add(
        DateTime(
          currentMonth.year,
          currentMonth.month,
          i,
        ),
      );
    }

    // Következő hónap napjai
    int nextDay = 1;

    while (days.length < 42) {
      days.add(
        DateTime(
          currentMonth.year,
          currentMonth.month + 1,
          nextDay,
        ),
      );

      nextDay++;
    }

    return days;
  }

  bool isSelected(
      DateTime date) {
    return date.year ==
        widget.selectedDate.year &&
        date.month ==
            widget.selectedDate.month &&
        date.day ==
            widget.selectedDate.day;
  }

  bool isToday(DateTime date) {
    final now =
    DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool isCurrentMonth(
      DateTime date) {
    return date.month ==
        currentMonth.month &&
        date.year ==
            currentMonth.year;
  }

  void selectDate(
      DateTime date) {

    widget.onDateSelected(date);

    if (!isCurrentMonth(date)) {
      setState(() {
        currentMonth = DateTime(
          date.year,
          date.month,
          1,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final days =
    generateCalendarDays();

    const weekDays = [
      "H",
      "K",
      "Sze",
      "Cs",
      "P",
      "Szo",
      "V",
    ];

    return _SectionCard(
      title: "NAPTÁR",

      subtitle:
      "${monthName(currentMonth.month)} "
          "${currentMonth.year}",

      headerAction: Row(
        children: [
          IconButton(
            onPressed:
            previousMonth,

            icon:
            const Icon(
              Icons.chevron_left,
              size: 16,
            ),

            padding:
            EdgeInsets.zero,

            constraints:
            const BoxConstraints(),
          ),

          const SizedBox(width: 12),

          IconButton(
            onPressed:
            nextMonth,

            icon:
            const Icon(
              Icons.chevron_right,
              size: 16,
            ),

            padding:
            EdgeInsets.zero,

            constraints:
            const BoxConstraints(),
          ),
        ],
      ),

      child: Column(
        children: [
          Row(
            children:
            weekDays.map(
                  (day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,

                      style:
                      const TextStyle(
                        fontSize: 6.5,
                        color:
                        Color(
                          0xFF89919A,
                        ),
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ).toList(),
          ),

          const SizedBox(
              height: 5),

          ...List.generate(
            (days.length / 7)
                .ceil(),

                (weekIndex) {
              final week = days
                  .skip(
                weekIndex * 7,
              )
                  .take(7)
                  .toList();

              return SizedBox(
                height: 23,

                child: Row(
                  children:
                  week.map(
                        (date) {
                      final selected =
                      isSelected(
                        date,
                      );

                      final current =
                      isCurrentMonth(
                        date,
                      );

                      return Expanded(
                        child:
                        GestureDetector(
                          behavior:
                          HitTestBehavior
                              .opaque,

                          onTap: () {
                            selectDate(
                              date,
                            );
                          },

                          child: Center(
                            child:
                            AnimatedContainer(
                              duration:
                              const Duration(
                                milliseconds:
                                150,
                              ),

                              width:
                              selected
                                  ? 22
                                  : 20,

                              height:
                              selected
                                  ? 22
                                  : 20,

                              alignment:
                              Alignment
                                  .center,

                              decoration:
                              BoxDecoration(
                                color:
                                selected
                                    ? const Color(
                                  0xFF2378E8,
                                )
                                    : Colors
                                    .transparent,

                                shape:
                                BoxShape
                                    .circle,

                                border:
                                isToday(
                                  date,
                                ) &&
                                    !selected
                                    ? Border.all(
                                  color:
                                  const Color(
                                    0xFF2378E8,
                                  ),
                                  width:
                                  1.2,
                                )
                                    : null,
                              ),

                              child: Text(
                                "${date.day}",

                                style:
                                TextStyle(
                                  fontSize: 7,

                                  color: selected
                                      ? Colors
                                      .white
                                      : current
                                      ? const Color(
                                    0xFF343A40,
                                  )
                                      : const Color(
                                    0xFFB8BEC5,
                                  ),

                                  fontWeight:
                                  selected
                                      ? FontWeight
                                      .bold
                                      : FontWeight
                                      .normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   DOLGOZÓK
   ============================================================ */

class _EmployeesCard extends StatelessWidget {
  final DateTime selectedDate;

  const _EmployeesCard({
    required this.selectedDate,
  });

  String get selectedDateString {
    return "${selectedDate.year.toString().padLeft(4, '0')}-"
        "${selectedDate.month.toString().padLeft(2, '0')}-"
        "${selectedDate.day.toString().padLeft(2, '0')}";
  }

  String get formattedDate {
    return "${selectedDate.year}. "
        "${selectedDate.month.toString().padLeft(2, '0')}. "
        "${selectedDate.day.toString().padLeft(2, '0')}.";
  }

  /* ============================================================
     ÖSSZES DOLGOZÓ MEGNYITÁSA
     ============================================================ */

  void openAllEmployees(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return _AllEmployeesPage(
            selectedDate: selectedDate,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: "DOLGOZÓK JELENLÉTE",
      subtitle: formattedDate,

      child: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1976E8),
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 20,
              ),
              child: Text(
                "Nem sikerült betölteni a dolgozókat:\n"
                    "${snapshot.error}",

                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.red,
                ),
              ),
            );
          }

          final employees =
              snapshot.data?.docs ?? [];

          if (employees.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 20,
              ),
              child: Center(
                child: Text(
                  "Nincs dolgozó az adatbázisban.",

                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF8A9098),
                  ),
                ),
              ),
            );
          }

          /* ----------------------------------------------------
             A FŐOLDALON CSAK 5 DOLGOZÓ
             ---------------------------------------------------- */

          final visibleEmployees =
          employees.take(5).toList();

          return Column(
            children: [
              ...visibleEmployees.map(
                    (employee) {
                  return _FirestoreEmployeeRow(
                    employeeId: employee.id,
                    employeeData: employee.data(),
                    selectedDate: selectedDateString,
                  );
                },
              ),

              const SizedBox(height: 3),

              /* ------------------------------------------------
                 ÖSSZES DOLGOZÓ GOMB
                 ------------------------------------------------ */

              TextButton(
                onPressed: () {
                  openAllEmployees(context);
                },

                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,

                  minimumSize: const Size(
                    double.infinity,
                    28,
                  ),
                ),

                child: const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,

                  children: [
                    Text(
                      "ÖSSZES DOLGOZÓ MEGTEKINTÉSE",

                      style: TextStyle(
                        color: Color(0xFF1976E8),
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(width: 12),

                    Icon(
                      Icons.arrow_forward,
                      color: Color(0xFF1976E8),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ============================================================
   FIRESTORE DOLGOZÓ SOR
   ============================================================ */

class _FirestoreEmployeeRow
    extends StatelessWidget {
  final String employeeId;

  final Map<String, dynamic>
  employeeData;

  final String selectedDate;

  const _FirestoreEmployeeRow({
    required this.employeeId,
    required this.employeeData,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final String name =
    employeeData["name"]
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? employeeData["name"].toString()
        : "Ismeretlen dolgozó";

    final String? photoUrl =
    employeeData["photoURL"]?.toString();

    return FutureBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection("users")
          .doc(employeeId)
          .collection("checkins")
          .doc(selectedDate)
          .get(),

      builder: (context, snapshot) {
        String role =
            "Nincs becsekkolva";

        String time =
            "Hiányzik";

        Color color =
        const Color(0xFFE44E4E);

        IconData icon =
            Icons.person;

        /* ====================================================
           BETÖLTÉS
           ==================================================== */

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          role = "Betöltés...";
          time = "";

          color =
          const Color(0xFF9AA0A7);

          icon =
              Icons.person;
        }

        /* ====================================================
           VAN JELENLÉTI ADAT
           ==================================================== */

        if (snapshot.hasData &&
            snapshot.data!.exists) {
          final data =
          snapshot.data!.data();

          final String? project =
          data?["project"]?.toString();

          final String? checkInTime =
          data?["checkInTime"]?.toString();

          final String? checkOutTime =
          data?["checkOutTime"]?.toString();

          /* ==================================================
             SZABADSÁG
             ================================================== */

          if (project == "Szabi") {
            role =
            "Szabadságon";

            time =
            "Szabi";

            color =
            const Color(0xFF8051D8);

            icon =
                Icons.beach_access;
          }

          /* ==================================================
             JELENLEG DOLGOZIK
             ================================================== */

          else if (
          checkInTime != null &&
              checkOutTime == null) {
            role =
            project != null &&
                project.isNotEmpty
                ? project
                : "Dolgozik";

            time =
                checkInTime;

            color =
            const Color(0xFF21B573);

            icon =
                Icons.engineering;
          }

          /* ==================================================
             KICSEKKOLT
             ================================================== */

          else if (
          checkInTime != null &&
              checkOutTime != null) {
            role =
            project != null &&
                project.isNotEmpty
                ? project
                : "Kicsekkolt";

            time =
                checkOutTime;

            color =
            const Color(0xFFF09A19);

            icon =
                Icons.done_all;
          }
        }

        return _EmployeeRowFromFirestore(
          name: name,
          role: role,
          time: time,
          color: color,
          icon: icon,
          photoUrl: photoUrl,
        );
      },
    );
  }
}


/* ============================================================
   FIRESTORE DOLGOZÓ UI
   ============================================================ */

class _EmployeeRowFromFirestore
    extends StatelessWidget {
  final String name;

  final String role;

  final String time;

  final Color color;

  final IconData icon;

  final String? photoUrl;

  const _EmployeeRowFromFirestore({
    required this.name,
    required this.role,
    required this.time,
    required this.color,
    required this.icon,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 43,

      decoration:
      const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFECEFF2),
          ),
        ),
      ),

      child: Row(
        children: [
          /* ==================================================
             PROFILKÉP / IKON
             ================================================== */

          Container(
            width: 29,
            height: 29,

            decoration:
            BoxDecoration(
              shape: BoxShape.circle,

              color:
              const Color(0xFFDCE4EC),

              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),

            child:
            photoUrl != null &&
                photoUrl!.isNotEmpty
                ? ClipOval(
              child: Image.network(
                photoUrl!,

                width: 29,
                height: 29,

                fit: BoxFit.cover,

                errorBuilder:
                    (
                    context,
                    error,
                    stackTrace,
                    ) {
                  return Icon(
                    icon,
                    color:
                    const Color(
                      0xFF526171,
                    ),
                    size: 17,
                  );
                },
              ),
            )
                : Icon(
              icon,
              color:
              const Color(
                0xFF526171,
              ),
              size: 17,
            ),
          ),

          const SizedBox(width: 7),

          /* ==================================================
             NÉV + ÁLLAPOT
             ================================================== */

          Expanded(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,

                      decoration:
                      BoxDecoration(
                        color: color,
                        shape:
                        BoxShape.circle,
                      ),
                    ),

                    const SizedBox(
                        width: 4),

                    Flexible(
                      child: Text(
                        name,

                        overflow:
                        TextOverflow
                            .ellipsis,

                        style:
                        const TextStyle(
                          fontSize: 8.5,

                          fontWeight:
                          FontWeight.w700,

                          color:
                          Color(
                            0xFF343A40,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                    height: 2),

                Text(
                  role,

                  maxLines: 1,

                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  const TextStyle(
                    fontSize: 6.5,

                    color:
                    Color(
                      0xFF8B929A,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /* ==================================================
             IDŐ
             ================================================== */

          if (time.isNotEmpty)
            Text(
              time,

              style: TextStyle(
                fontSize: 7.5,

                color: color,

                fontWeight:
                FontWeight.w600,
              ),
            ),

          const Icon(
            Icons.chevron_right,

            size: 14,

            color:
            Color(0xFFA4AAB1),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   PROJECTS
   ============================================================ */

class _ProjectsCard
    extends StatelessWidget {
  const _ProjectsCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title:
      "AKTUÁLIS PROJEKTEK",
      subtitle:
      "Top 5 projekt",

      child: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream: FirebaseFirestore
            .instance
            .collection("projects")
            .snapshots(),

        builder:
            (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const SizedBox(
              height: 180,

              child: Center(
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                  Color(0xFF1976E8),
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return SizedBox(
              height: 180,

              child: Center(
                child: Text(
                  "Nem sikerült betölteni a projekteket:\n"
                      "${snapshot.error}",

                  textAlign:
                  TextAlign.center,

                  style:
                  const TextStyle(
                    fontSize: 9,
                    color: Colors.red,
                  ),
                ),
              ),
            );
          }

          final documents =
              snapshot.data?.docs ??
                  [];

          final projects =
          documents
              .where(
                (doc) =>
            doc.id != "Szabi",
          )
              .toList();

          projects.sort(
                (a, b) {
              final dataA =
              a.data();

              final dataB =
              b.data();

              final workersA =
              (dataA[
              "Munkások száma"] ??
                  0)
              as num;

              final workersB =
              (dataB[
              "Munkások száma"] ??
                  0)
              as num;

              return workersB.compareTo(
                workersA,
              );
            },
          );

          final topProjects =
          projects.take(5).toList();

          if (topProjects.isEmpty) {
            return const SizedBox(
              height: 120,

              child: Center(
                child: Text(
                  "Nincs aktuális projekt.",

                  style:
                  TextStyle(
                    fontSize: 10,
                    color:
                    Color(0xFF8A9098),
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              ...topProjects.map(
                    (project) {
                  final data =
                  project.data();

                  final projectName =
                      project.id;

                  final workers =
                      data[
                      "Munkások száma"] ??
                          0;

                  return _ProjectRow(
                    projectName:
                    projectName,
                    workers:
                    workers,
                  );
                },
              ),

              const SizedBox(height: 3),

              TextButton(
                onPressed: () {},

                style:
                TextButton.styleFrom(
                  padding:
                  EdgeInsets.zero,

                  minimumSize:
                  const Size(
                    double.infinity,
                    28,
                  ),
                ),

                child:
                const Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,

                  children: [
                    Text(
                      "ÖSSZES PROJEKT MEGTEKINTÉSE",

                      style:
                      TextStyle(
                        color:
                        Color(
                          0xFF1976E8,
                        ),
                        fontSize: 7.5,
                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),

                    SizedBox(width: 12),

                    Icon(
                      Icons.arrow_forward,
                      color:
                      Color(
                        0xFF1976E8,
                      ),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectRow
    extends StatelessWidget {
  final String projectName;
  final dynamic workers;

  const _ProjectRow({
    required this.projectName,
    required this.workers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,

      decoration:
      const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
            Color(0xFFECEFF2),
          ),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,

            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFF2679E8,
              ).withOpacity(.12),

              borderRadius:
              BorderRadius
                  .circular(6),
            ),

            child:
            const Icon(
              Icons.business_outlined,
              color:
              Color(0xFF2679E8),
              size: 17,
            ),
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment
                  .center,

              crossAxisAlignment:
              CrossAxisAlignment
                  .start,

              children: [
                Text(
                  projectName,

                  maxLines: 1,

                  overflow:
                  TextOverflow
                      .ellipsis,

                  style:
                  const TextStyle(
                    fontSize: 8.5,
                    fontWeight:
                    FontWeight
                        .w700,
                    color:
                    Color(
                      0xFF343A40,
                    ),
                  ),
                ),

                const SizedBox(
                    height: 4),

                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 11,
                      color:
                      Color(
                        0xFF8A9098,
                      ),
                    ),

                    const SizedBox(
                        width: 3),

                    Text(
                      "$workers fő dolgozik rajta",

                      style:
                      const TextStyle(
                        fontSize: 7,
                        color:
                        Color(
                          0xFF9299A1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 7,
              vertical: 4,
            ),

            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFF2679E8,
              ).withOpacity(.10),

              borderRadius:
              BorderRadius
                  .circular(5),
            ),

            child: Text(
              "$workers fő",

              style:
              const TextStyle(
                fontSize: 8,
                fontWeight:
                FontWeight.bold,
                color:
                Color(0xFF2679E8),
              ),
            ),
          ),

          const SizedBox(width: 3),

          const Icon(
            Icons.chevron_right,
            size: 14,
            color:
            Color(0xFFA4AAB1),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   SECTION CARD
   ============================================================ */

class _SectionCard
    extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? headerAction;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        10,
        10,
        10,
        7,
      ),

      decoration:
      BoxDecoration(
        color: Colors.white,

        borderRadius:
        BorderRadius.circular(8),

        border: Border.all(
          color:
          const Color(0xFFE6EAEF),
        ),
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,

        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,

            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    Text(
                      title,

                      style:
                      const TextStyle(
                        fontSize: 9.5,
                        fontWeight:
                        FontWeight
                            .w800,
                        color:
                        Color(
                          0xFF30363C,
                        ),
                      ),
                    ),

                    const SizedBox(
                        height: 3),

                    Text(
                      subtitle,

                      style:
                      const TextStyle(
                        fontSize: 7,
                        color:
                        Color(
                          0xFF9BA1A8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (headerAction !=
                  null)
                headerAction!,
            ],
          ),

          const SizedBox(height: 5),

          child,
        ],
      ),
    );
  }
}

/* ============================================================
   BOTTOM BANNER
   ============================================================ */

class _BottomBanner
    extends StatelessWidget {
  const _BottomBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,

      decoration:
      BoxDecoration(
        borderRadius:
        BorderRadius.circular(9),

        gradient:
        const LinearGradient(
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,

          colors: [
            Color(0xFF1D2D3D),
            Color(0xFF0C1825),
          ],
        ),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black
                .withOpacity(.08),
            blurRadius: 8,
          ),
        ],
      ),

      child: Stack(
        children: [
          Positioned(
            right: 20,
            top: 10,

            child: Icon(
              Icons.factory,
              color:
              Colors.white
                  .withOpacity(.12),
              size: 80,
            ),
          ),

          Padding(
            padding:
            const EdgeInsets
                .fromLTRB(
              16,
              12,
              16,
              10,
            ),

            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,

              children: [
                const Text(
                  "Profi légtechnikai kivitelezés",

                  style:
                  TextStyle(
                    color:
                    Colors.white,
                    fontSize: 12,
                    fontWeight:
                    FontWeight
                        .w800,
                  ),
                ),

                const SizedBox(
                    height: 3),

                const Text(
                  "Minőség. Megbízhatóság. Határidőre.",

                  style:
                  TextStyle(
                    color:
                    Colors.white70,
                    fontSize: 7.5,
                  ),
                ),

                const Spacer(),

                SizedBox(
                  height: 25,

                  child:
                  ElevatedButton(
                    onPressed: () {},

                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      const Color(
                        0xFF1478ED,
                      ),

                      foregroundColor:
                      Colors.white,

                      elevation: 0,

                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 13,
                      ),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          5,
                        ),
                      ),
                    ),

                    child:
                    const Row(
                      mainAxisSize:
                      MainAxisSize
                          .min,

                      children: [
                        Text(
                          "TOVÁBB A PROJEKTEKHEZ",

                          style:
                          TextStyle(
                            fontSize: 7,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),

                        SizedBox(
                            width: 10),

                        Icon(
                          Icons
                              .arrow_forward,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   BOTTOM NAVIGATION
   ============================================================ */

class _BottomNavigation
    extends StatelessWidget {

  final int selectedIndex;
  final Function(int) onSelected;
  final bool isAdmin;

  const _BottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {

    final List<Map<String, dynamic>> items = [

      {
        "icon": Icons.home_rounded,
        "label": "Kezdőlap",
      },

      {
        "icon": Icons.access_time,
        "label": "Jelenlét",
      },

      {
        "icon": Icons.calendar_month_outlined,
        "label": "Naptár",
      },

      {
        "icon": Icons.business_outlined,
        "label": "Projektek",
      },

      {
        "icon": Icons.build_outlined,
        "label": "Szerszámok",
      },

      {
        "icon": Icons.more_horiz,
        "label": "Több",
      },
    ];

    // ============================================================
    // ADMIN FÜL
    // ============================================================

    if (isAdmin) {
      items.add({
        "icon": Icons.admin_panel_settings_outlined,
        "label": "Admin",
      });
    }

    return Container(
      height: 72,

      decoration: const BoxDecoration(
        color: Color(0xFF101E2E),
      ),

      child: Row(
        children: List.generate(
          items.length,
              (index) {

            final selected =
                selectedIndex == index;

            return Expanded(
              child: GestureDetector(
                behavior:
                HitTestBehavior.opaque,

                onTap: () =>
                    onSelected(index),

                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,

                  children: [

                    Icon(
                      items[index]["icon"]
                      as IconData,

                      size: 21,

                      color: selected
                          ? const Color(
                        0xFF1680F5,
                      )
                          : const Color(
                        0xFF8E9AA8,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      items[index]["label"]
                      as String,

                      style: TextStyle(
                        fontSize: 7,

                        color: selected
                            ? const Color(
                          0xFF1680F5,
                        )
                            : const Color(
                          0xFF8E9AA8,
                        ),

                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/* ============================================================
   JELENLÉT
   ============================================================ */


class AttendancePage extends StatefulWidget {
  const AttendancePage({
    super.key,
  });

  @override
  State<AttendancePage> createState() =>
      _AttendancePageState();
}

class _AttendancePageState
    extends State<AttendancePage> {

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool isLoading = true;

  bool isCheckedIn = false;
  bool isCheckedOut = false;

  // ============================================================
  // SZABADSÁG
  // ============================================================

  bool isHoliday = false;

  bool holidayWorkerCountAdded = false;

  bool holidayWorkerCountRemoved = false;

  // ============================================================
  // JELENLÉT
  // ============================================================

  String? selectedProject;

  String? checkInTime;

  String? checkOutTime;

  List<String> projects = [];

  // ============================================================
  // TÚLÓRA
  // ============================================================

  bool overtimeDecision = false;

  bool overtimePromptShown = false;

  String? overtimeStart;

  String? overtimeEnd;

  Timer? overtimeTimer;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    loadAttendance();
    loadProjects();

    // 10 másodpercenként ellenőrizzük,
    // hogy elérkezett-e a 16:00.
    overtimeTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) {
        checkOvertimeTime();
      },
    );
  }

  @override
  void dispose() {
    overtimeTimer?.cancel();

    super.dispose();
  }

  // ============================================================
  // MAI DÁTUM
  // ============================================================

  String get today {
    final now = DateTime.now();

    return "${now.year.toString().padLeft(4, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')}";
  }

  // ============================================================
  // AKTUÁLIS IDŐ
  // ============================================================

  String get currentTime {
    final now = DateTime.now();

    return "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}";
  }

  /// ============================================================
// TÚLÓRA IDŐ ELLENŐRZÉSE
// ============================================================

  Future<void> checkOvertimeTime() async {
    if (!mounted) return;

    if (isHoliday) return;

    if (!isCheckedIn) return;

    if (overtimeDecision) return;

    final now = DateTime.now();

    final currentMinutes =
        now.hour * 60 + now.minute;

    // ----------------------------------------------------------
    // 15:45 ELŐTT NINCS KÉRDÉS
    // ----------------------------------------------------------

    const overtimeQuestionTime =
        15 * 60 + 45; // 15:45

    // ----------------------------------------------------------
    // 16:00
    // ----------------------------------------------------------

    const overtimeDeadline =
        16 * 60; // 16:00

    // ----------------------------------------------------------
    // 15:45 ÉS 16:00 KÖZÖTT
    // ----------------------------------------------------------

    if (currentMinutes >= overtimeQuestionTime &&
        currentMinutes < overtimeDeadline) {

      if (!overtimePromptShown) {
        await askOvertime();
      }

      return;
    }

    // ----------------------------------------------------------
    // 16:00 UTÁN
    //
    // Ha még nem döntött, automatikusan lezárjuk.
    // ----------------------------------------------------------

    if (currentMinutes >= overtimeDeadline) {

      // Ha már lezártuk, nincs további teendő.
      if (isCheckedOut) return;

      await finishNormalWorkday();
    }
  }

  // ============================================================
// TÚLÓRA KÉRDÉS
// ============================================================

  Future<void> askOvertime() async {
    if (!mounted) return;

    if (isHoliday) return;

    if (!isCheckedIn) return;

    if (overtimePromptShown) return;

    // ----------------------------------------------------------
    // Kérdés már megjelent
    // ----------------------------------------------------------

    setState(() {
      overtimePromptShown = true;
    });

    bool decisionMade = false;

    // ----------------------------------------------------------
    // 15 perc után automatikus lezárás
    // ----------------------------------------------------------

    final autoCloseTimer = Timer(
      const Duration(minutes: 15),
          () async {
        if (!mounted) return;

        if (decisionMade) return;

        decisionMade = true;

        // Bezárjuk a túlóra ablakot.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(false);
        }

        // Automatikusan lezárjuk a munkanapot.
        await finishNormalWorkday();
      },
    );

    // ----------------------------------------------------------
    // DIALÓGUS
    // ----------------------------------------------------------

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Túlóra",
          ),

          content: const Text(
            "Szeretnél ma túlórázni?\n\n"
                "15:45-től 16:00-ig van időd eldönteni.\n\n"
                "Ha 16:00-ig nem választasz, "
                "a munkanap automatikusan lezárul.",
          ),

          actions: [

            // --------------------------------------------------
            // NEM
            // --------------------------------------------------

            TextButton(
              onPressed: () {
                if (decisionMade) return;

                decisionMade = true;

                Navigator.of(context).pop(false);
              },

              child: const Text(
                "Nem, kicsekkolok",
              ),
            ),

            // --------------------------------------------------
            // IGEN
            // --------------------------------------------------

            ElevatedButton(
              onPressed: () {
                if (decisionMade) return;

                decisionMade = true;

                Navigator.of(context).pop(true);
              },

              child: const Text(
                "Igen, túlórázom",
              ),
            ),
          ],
        );
      },
    );

    // ----------------------------------------------------------
    // TIMER LEÁLLÍTÁSA
    // ----------------------------------------------------------

    autoCloseTimer.cancel();

    if (!mounted) return;

    // ----------------------------------------------------------
    // DÖNTÉS
    // ----------------------------------------------------------

    if (result == true) {

      await startOvertime();

    } else if (result == false) {

      // Csak akkor zárjuk le,
      // ha nem az automatikus 16:00 lezárás történt.

      if (!isCheckedOut) {
        await finishNormalWorkday();
      }
    }
  }

  // ============================================================
  // TÚLÓRA ELINDÍTÁSA
  // ============================================================

  Future<void> startOvertime() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final checkinRef = _firestore
          .collection("users")
          .doc(user.uid)
          .collection("checkins")
          .doc(today);

      await checkinRef.update({
        // Nagyon fontos:
        // túlóránál a checkoutTime 16:00 marad.
        "checkOutTime": "16:00",

        "overtimeDecision": true,

        "overtimeStart": "16:00",

        // A tényleges kicsekkolásig null.
        "overtimeEnd": null,

        "overtimePromptShown": true,
      });

      if (mounted) {
        setState(() {
          overtimeDecision = true;

          overtimeStart = "16:00";

          overtimeEnd = null;

          // Továbbra is dolgozik.
          isCheckedIn = true;

          isCheckedOut = false;

          // Ez szándékosan 16:00.
          checkOutTime = "16:00";
        });
      }

      showMessage(
        "A túlóra elindult. Kicsekkoláskor rögzítjük a tényleges időt.",
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          overtimePromptShown = false;
        });
      }

      showError(
        "Nem sikerült elindítani a túlórát: $e",
      );
    }
  }

  // ============================================================
  // NORMÁL MUNKANAP LEZÁRÁSA 16:00-KOR
  // ============================================================

  Future<void> finishNormalWorkday() async {
    final user = _auth.currentUser;

    if (user == null) return;

    if (selectedProject == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final checkinRef = _firestore
          .collection("users")
          .doc(user.uid)
          .collection("checkins")
          .doc(today);

      await checkinRef.update({
        "checkOutTime": "16:00",

        "overtimeDecision": false,

        "overtimePromptShown": true,
      });

      // --------------------------------------------------------
      // PROJEKT -1
      // --------------------------------------------------------

      await removeWorkerFromProject(
        selectedProject!,
      );

      if (mounted) {
        setState(() {
          checkOutTime = "16:00";

          isCheckedIn = false;

          isCheckedOut = true;

          overtimeDecision = false;

          overtimePromptShown = true;
        });
      }

      showMessage(
        "Munkanap lezárva. Kicsekkolás: 16:00",
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          overtimePromptShown = false;
        });
      }

      showError(
        "Nem sikerült lezárni a munkanapot: $e",
      );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ============================================================
  // PROJEKT DOLGOZÓ -1
  // ============================================================

  Future<void> removeWorkerFromProject(
      String projectName,
      ) async {

    final projectRef = _firestore
        .collection("projects")
        .doc(projectName);

    await _firestore.runTransaction(
          (transaction) async {
        final snapshot =
        await transaction.get(
          projectRef,
        );

        if (snapshot.exists) {
          final data =
          snapshot.data();

          final currentWorkers =
          (data?["Munkások száma"] ?? 0)
          as num;

          final newCount =
          currentWorkers > 0
              ? currentWorkers - 1
              : 0;

          transaction.update(
            projectRef,
            {
              "Munkások száma":
              newCount,
            },
          );
        }
      },
    );
  }

  // ============================================================
  // JELENLÉT BETÖLTÉSE
  // ============================================================

  Future<void> loadAttendance() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      return;
    }

    try {
      final document = await _firestore
          .collection("users")
          .doc(user.uid)
          .collection("checkins")
          .doc(today)
          .get();

      if (document.exists) {
        final data = document.data()!;

        final project =
        data["project"]?.toString();

        final checkIn =
        data["checkInTime"]?.toString();

        final checkOut =
        data["checkOutTime"]?.toString();

        final workerCountAdded =
            data["workerCountAdded"] == true;

        final workerCountRemoved =
            data["workerCountRemoved"] == true;

        final overtime =
            data["overtimeDecision"] == true;

        final overtimePrompt =
            data["overtimePromptShown"] == true;

        final overtimeStartValue =
        data["overtimeStart"]?.toString();

        final overtimeEndValue =
        data["overtimeEnd"]?.toString();

        if (mounted) {
          setState(() {
            selectedProject = project;

            checkInTime = checkIn;

            checkOutTime = checkOut;

            overtimeDecision = overtime;

            overtimePromptShown =
                overtimePrompt;

            overtimeStart =
                overtimeStartValue;

            overtimeEnd =
                overtimeEndValue;

            // --------------------------------------------------
            // SZABADSÁG
            // --------------------------------------------------

            isHoliday =
                project == "Szabi";

            holidayWorkerCountAdded =
                workerCountAdded;

            holidayWorkerCountRemoved =
                workerCountRemoved;

            // --------------------------------------------------
            // JELENLÉT
            // --------------------------------------------------
            //
            // Ha túlórázik:
            //
            // checkOutTime = 16:00
            // overtimeEnd = null
            //
            // Ettől még továbbra is becsekkolva van.
            //

            if (overtime &&
                overtimeEndValue == null) {

              isCheckedIn = true;

              isCheckedOut = false;

            } else {

              isCheckedIn =
                  checkIn != null &&
                      checkOut == null;

              isCheckedOut =
                  checkOut != null &&
                      (!overtime ||
                          overtimeEndValue != null);
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            selectedProject = null;

            checkInTime = null;

            checkOutTime = null;

            isCheckedIn = false;

            isCheckedOut = false;

            isHoliday = false;

            holidayWorkerCountAdded = false;

            holidayWorkerCountRemoved = false;

            overtimeDecision = false;

            overtimePromptShown = false;

            overtimeStart = null;

            overtimeEnd = null;
          });
        }
      }
    } catch (e) {
      showError(
        "Nem sikerült betölteni a jelenlétet: $e",
      );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ============================================================
  // PROJEKTEK BETÖLTÉSE
  // ============================================================

  Future<void> loadProjects() async {
    try {
      final snapshot = await _firestore
          .collection("projects")
          .get();

      final loadedProjects =
      snapshot.docs
          .map(
            (doc) => doc.id,
      )
          .where(
            (name) => name != "Szabi",
      )
          .toList();

      if (mounted) {
        setState(() {
          projects = loadedProjects;
        });
      }
    } catch (e) {
      showError(
        "Nem sikerült betölteni a projekteket: $e",
      );
    }
  }

  // ============================================================
  // BECSSEKKOLÁS
  // ============================================================

  Future<void> checkIn() async {
    final user = _auth.currentUser;

    if (user == null) {
      showError(
        "Nincs bejelentkezett felhasználó.",
      );

      return;
    }

    // ----------------------------------------------------------
    // SZABADSÁG ELLENŐRZÉS
    // ----------------------------------------------------------

    if (isHoliday) {
      showError(
        "Ma szabadságon vagy, ezért nem tudsz becsekkolni.",
      );

      return;
    }

    // ----------------------------------------------------------
    // FIRESTORE ELLENŐRZÉS
    // ----------------------------------------------------------

    try {
      final checkinRef = _firestore
          .collection("users")
          .doc(user.uid)
          .collection("checkins")
          .doc(today);

      final existingDocument =
      await checkinRef.get();

      if (existingDocument.exists) {
        final data =
        existingDocument.data();

        final project =
        data?["project"]?.toString();

        // ------------------------------------------------------
        // SZABADSÁG
        // ------------------------------------------------------

        if (project == "Szabi") {
          if (mounted) {
            setState(() {
              isHoliday = true;

              selectedProject = "Szabi";

              holidayWorkerCountAdded =
                  data?["workerCountAdded"] == true;

              holidayWorkerCountRemoved =
                  data?["workerCountRemoved"] == true;
            });
          }

          showError(
            "Ma szabadságon vagy, ezért nem tudsz becsekkolni.",
          );

          return;
        }

        final existingCheckIn =
        data?["checkInTime"];

        final existingCheckOut =
        data?["checkOutTime"];

        final existingOvertime =
            data?["overtimeDecision"] == true;

        final existingOvertimeEnd =
        data?["overtimeEnd"];

        // ------------------------------------------------------
        // TÚLÓRÁZIK
        // ------------------------------------------------------

        if (existingOvertime &&
            existingOvertimeEnd == null) {
          showError(
            "Már túlórázol.",
          );

          await loadAttendance();

          return;
        }

        // ------------------------------------------------------
        // MÁR BE VAN CSSEKKOLVA
        // ------------------------------------------------------

        if (existingCheckIn != null &&
            existingCheckOut == null) {

          showError(
            "Már be vagy csekkolva.",
          );

          await loadAttendance();

          return;
        }

        // ------------------------------------------------------
        // MÁR KICSEKKOLT
        // ------------------------------------------------------

        if (existingCheckOut != null) {
          showError(
            "Ma már kicsekkoltál.",
          );

          await loadAttendance();

          return;
        }
      }
    } catch (e) {
      showError(
        "Nem sikerült ellenőrizni a mai jelenlétet: $e",
      );

      return;
    }

    // ----------------------------------------------------------
    // PROJEKT ELLENŐRZÉS
    // ----------------------------------------------------------

    if (selectedProject == null ||
        selectedProject!.isEmpty) {

      showError(
        "Először válassz projektet!",
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final now = DateTime.now();

      final time =
          "${now.hour.toString().padLeft(2, '0')}:"
          "${now.minute.toString().padLeft(2, '0')}";

      final checkinRef = _firestore
          .collection("users")
          .doc(user.uid)
          .collection("checkins")
          .doc(today);

      // --------------------------------------------------------
      // CHECKIN
      // --------------------------------------------------------

      await checkinRef.set({
        "project": selectedProject,

        "checkInTime": time,

        "checkOutTime": null,

        "overtimeDecision": false,

        "overtimePromptShown": false,

        "overtimeStart": null,

        "overtimeEnd": null,

        "workerCountAdded": true,

        "workerCountRemoved": false,
      });

      // --------------------------------------------------------
      // PROJEKT +1
      // --------------------------------------------------------

      final projectRef = _firestore
          .collection("projects")
          .doc(selectedProject);

      await _firestore.runTransaction(
            (transaction) async {

          final snapshot =
          await transaction.get(
            projectRef,
          );

          if (snapshot.exists) {

            final data =
            snapshot.data();

            final currentWorkers =
            (data?["Munkások száma"] ?? 0)
            as num;

            transaction.update(
              projectRef,
              {
                "Munkások száma":
                currentWorkers + 1,
              },
            );
          }
        },
      );

      // --------------------------------------------------------
      // UI
      // --------------------------------------------------------

      if (mounted) {
        setState(() {
          checkInTime = time;

          checkOutTime = null;

          isCheckedIn = true;

          isCheckedOut = false;

          isHoliday = false;

          holidayWorkerCountAdded = false;

          holidayWorkerCountRemoved = false;

          overtimeDecision = false;

          overtimePromptShown = false;

          overtimeStart = null;

          overtimeEnd = null;
        });
      }

      showMessage(
        "Sikeres becsekkolás!",
      );
    } catch (e) {

      showError(
        "Becsekkolási hiba: $e",
      );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ============================================================
  // KICSEKKOLÁS
  // ============================================================

  Future<void> checkOut() async {
    final user = _auth.currentUser;

    if (user == null) {
      showError(
        "Nincs bejelentkezett felhasználó.",
      );

      return;
    }

    // ----------------------------------------------------------
    // SZABADSÁG
    // ----------------------------------------------------------

    if (isHoliday) {
      showError(
        "Szabadságon vagy, ezért nincs mit kicsekkolnod.",
      );

      return;
    }

    if (selectedProject == null) {
      showError(
        "Nincs kiválasztott projekt.",
      );

      return;
    }

    // ----------------------------------------------------------
    // HA 16:00 UTÁN VAN ÉS MÉG NINCS DÖNTÉS
    // ----------------------------------------------------------

    final now = DateTime.now();

    if (now.hour >= 16 &&
        !overtimeDecision &&
        !overtimePromptShown &&
        isCheckedIn) {

      await askOvertime();

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final time = currentTime;

      final checkinRef = _firestore
          .collection("users")
          .doc(user.uid)
          .collection("checkins")
          .doc(today);

      // ========================================================
      // TÚLÓRA KICSEKKOLÁS
      // ========================================================

      if (overtimeDecision) {

        await checkinRef.update({

          // FONTOS:
          // túlóránál ez továbbra is 16:00!
          "checkOutTime": "16:00",

          // A tényleges kicsekkolás ideje ide kerül.
          "overtimeEnd": time,

          "overtimeDecision": true,

          "overtimeStart": "16:00",

          "overtimePromptShown": true,
        });

        // ------------------------------------------------------
        // PROJEKT -1
        // ------------------------------------------------------

        await removeWorkerFromProject(
          selectedProject!,
        );

        if (mounted) {
          setState(() {

            // A normál munkaidő vége.
            checkOutTime = "16:00";

            // Tényleges túlóra vége.
            overtimeEnd = time;

            isCheckedIn = false;

            isCheckedOut = true;
          });
        }

        showMessage(
          "Sikeres kicsekkolás! Túlóra vége: $time",
        );

      } else {

        // ======================================================
        // NORMÁL KICSEKKOLÁS
        // ======================================================

        await checkinRef.update({
          "checkOutTime": time,

          "overtimeDecision": false,

          "overtimePromptShown":
          overtimePromptShown,
        });

        // ------------------------------------------------------
        // PROJEKT -1
        // ------------------------------------------------------

        await removeWorkerFromProject(
          selectedProject!,
        );

        if (mounted) {
          setState(() {

            checkOutTime = time;

            isCheckedIn = false;

            isCheckedOut = true;
          });
        }

        showMessage(
          "Sikeres kicsekkolás!",
        );
      }

    } catch (e) {

      showError(
        "Kicsekkolási hiba: $e",
      );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ============================================================
  // ÜZENET
  // ============================================================

  void showMessage(
      String message,
      ) {

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
        Text(message),
      ),
    );
  }

  // ============================================================
  // HIBA
  // ============================================================

  void showError(
      String message,
      ) {

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        backgroundColor:
        Colors.red,

        content:
        Text(message),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {

    final user =
        _auth.currentUser;

    return Scaffold(
      backgroundColor:
      const Color(
        0xFFF5F7FA,
      ),

      appBar:
      AppBar(
        backgroundColor:
        const Color(
          0xFF101E2E,
        ),

        foregroundColor:
        Colors.white,

        title:
        const Text(
          "Jelenlét",
        ),

        centerTitle:
        true,
      ),

      body:
      isLoading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        padding:
        const EdgeInsets.all(
          18,
        ),

        child:
        Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            // ==================================================
            // FELHASZNÁLÓ
            // ==================================================

            Container(
              width:
              double.infinity,

              padding:
              const EdgeInsets.all(
                18,
              ),

              decoration:
              BoxDecoration(
                color:
                Colors.white,

                borderRadius:
                BorderRadius.circular(
                  12,
                ),

                border:
                Border.all(
                  color:
                  const Color(
                    0xFFE6EAEF,
                  ),
                ),
              ),

              child:
              Row(
                children: [

                  CircleAvatar(
                    radius:
                    28,

                    backgroundImage:
                    user?.photoURL !=
                        null
                        ? NetworkImage(
                      user!.photoURL!,
                    )
                        : null,

                    child:
                    user?.photoURL ==
                        null
                        ? const Icon(
                      Icons.person,
                      size: 30,
                    )
                        : null,
                  ),

                  const SizedBox(
                    width:
                    14,
                  ),

                  Expanded(
                    child:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [

                        Text(
                          user?.displayName ??
                              "Felhasználó",

                          style:
                          const TextStyle(
                            fontSize:
                            18,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height:
                          4,
                        ),

                        Text(
                          user?.email ??
                              "",

                          style:
                          const TextStyle(
                            fontSize:
                            12,
                            color:
                            Color(
                              0xFF8A9098,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height:
              18,
            ),

            // ==================================================
            // MAI JELENLÉT
            // ==================================================

            const Text(
              "MAI JELENLÉT",

              style:
              TextStyle(
                fontSize:
                12,
                fontWeight:
                FontWeight.w800,
                color:
                Color(
                  0xFF30363C,
                ),
              ),
            ),

            const SizedBox(
              height:
              8,
            ),

            Text(
              today,

              style:
              const TextStyle(
                fontSize:
                12,
                color:
                Color(
                  0xFF8A9098,
                ),
              ),
            ),

            const SizedBox(
              height:
              18,
            ),

            // ==================================================
            // SZABADSÁG
            // ==================================================

            if (isHoliday)
              Container(
                width:
                double.infinity,

                padding:
                const EdgeInsets.all(
                  20,
                ),

                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFFFF3CD,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),

                  border:
                  Border.all(
                    color:
                    const Color(
                      0xFFFFD666,
                    ),
                  ),
                ),

                child:
                Column(
                  children: [

                    const Icon(
                      Icons.beach_access,

                      size:
                      50,

                      color:
                      Color(
                        0xFFD99A00,
                      ),
                    ),

                    const SizedBox(
                      height:
                      10,
                    ),

                    const Text(
                      "Ma szabadságon vagy",

                      style:
                      TextStyle(
                        fontSize:
                        20,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    const Text(
                      "Ezen a napon nem tudsz becsekkolni.",

                      textAlign:
                      TextAlign.center,

                      style:
                      TextStyle(
                        fontSize:
                        14,
                      ),
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    Text(
                      holidayWorkerCountAdded
                          ? "A Szabi projekt létszámába már beleszámítasz."
                          : "A Szabi projekt létszámába még nem kerültél bele.",

                      textAlign:
                      TextAlign.center,

                      style:
                      const TextStyle(
                        fontSize:
                        12,
                        color:
                        Color(
                          0xFF777777,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ==================================================
            // NORMÁL JELENLÉT
            // ==================================================

            if (!isHoliday) ...[

              const Text(
                "PROJEKT",

                style:
                TextStyle(
                  fontSize:
                  11,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  Color(
                    0xFF30363C,
                  ),
                ),
              ),

              const SizedBox(
                height:
                7,
              ),

              DropdownButtonFormField<
                  String>(
                initialValue:
                selectedProject,

                decoration:
                InputDecoration(
                  filled:
                  true,

                  fillColor:
                  Colors.white,

                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),

                    borderSide:
                    const BorderSide(
                      color:
                      Color(
                        0xFFE1E6EB,
                      ),
                    ),
                  ),
                ),

                hint:
                const Text(
                  "Válassz projektet",
                ),

                items:
                projects.map(
                      (project) {

                    return
                      DropdownMenuItem<
                          String>(
                        value:
                        project,

                        child:
                        Text(
                          project,
                        ),
                      );
                  },
                ).toList(),

                onChanged:
                isCheckedIn ||
                    isCheckedOut
                    ? null
                    : (value) {

                  setState(
                        () {

                      selectedProject =
                          value;
                    },
                  );
                },
              ),

              const SizedBox(
                height:
                25,
              ),

              // ==================================================
              // TÚLÓRA ÁLLAPOT
              // ==================================================

              if (overtimeDecision &&
                  !isCheckedOut)
                Container(
                  width:
                  double.infinity,

                  margin:
                  const EdgeInsets.only(
                    bottom:
                    15,
                  ),

                  padding:
                  const EdgeInsets.all(
                    18,
                  ),

                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFFFFF3CD,
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),

                    border:
                    Border.all(
                      color:
                      const Color(
                        0xFFFFD666,
                      ),
                    ),
                  ),

                  child:
                  Column(
                    children: [

                      const Icon(
                        Icons
                            .access_time_filled,

                        size:
                        40,

                        color:
                        Color(
                          0xFFD99A00,
                        ),
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      const Text(
                        "Túlórázol",

                        style:
                        TextStyle(
                          fontSize:
                          20,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height:
                        6,
                      ),

                      const Text(
                        "A normál munkaidő vége: 16:00",

                        textAlign:
                        TextAlign.center,
                      ),

                      const SizedBox(
                        height:
                        4,
                      ),

                      const Text(
                        "A tényleges kicsekkoláskor rögzítjük a túlóra végét.",

                        textAlign:
                        TextAlign.center,

                        style:
                        TextStyle(
                          fontSize:
                          12,
                          color:
                          Color(
                            0xFF777777,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ==================================================
              // JELENLÉTI KÁRTYA
              // ==================================================

              Container(
                width:
                double.infinity,

                padding:
                const EdgeInsets.all(
                  20,
                ),

                decoration:
                BoxDecoration(
                  color:
                  isCheckedIn
                      ? const Color(
                    0xFFE8F7EF,
                  )
                      : isCheckedOut
                      ? const Color(
                    0xFFEAF1FF,
                  )
                      : Colors.white,

                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),

                  border:
                  Border.all(
                    color:
                    isCheckedIn
                        ? const Color(
                      0xFF21B573,
                    )
                        : isCheckedOut
                        ? const Color(
                      0xFF1976E8,
                    )
                        : const Color(
                      0xFFE6EAEF,
                    ),
                  ),
                ),

                child:
                Column(
                  children: [

                    Icon(
                      isCheckedIn
                          ? Icons.check_circle
                          : isCheckedOut
                          ? Icons.done_all
                          : Icons.access_time,

                      size:
                      48,

                      color:
                      isCheckedIn
                          ? const Color(
                        0xFF21B573,
                      )
                          : isCheckedOut
                          ? const Color(
                        0xFF1976E8,
                      )
                          : const Color(
                        0xFF8A9098,
                      ),
                    ),

                    const SizedBox(
                      height:
                      10,
                    ),

                    Text(
                      overtimeDecision &&
                          !isCheckedOut
                          ? "Túlórázol"
                          : isCheckedIn
                          ? "Jelenleg dolgozol"
                          : isCheckedOut
                          ? "Már kicsekkoltál"
                          : "Nincs becsekkolva",

                      style:
                      const TextStyle(
                        fontSize:
                        20,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                      15,
                    ),

                    if (checkInTime !=
                        null)
                      Text(
                        "Becsekkolás: "
                            "$checkInTime",

                        style:
                        const TextStyle(
                          fontSize:
                          14,
                        ),
                      ),

                    if (checkOutTime !=
                        null)
                      Padding(
                        padding:
                        const EdgeInsets.only(
                          top:
                          5,
                        ),

                        child:
                        Text(
                          "Kicsekkolás: "
                              "$checkOutTime",

                          style:
                          const TextStyle(
                            fontSize:
                            14,
                          ),
                        ),
                      ),

                    if (overtimeDecision &&
                        overtimeEnd != null)
                      Padding(
                        padding:
                        const EdgeInsets.only(
                          top:
                          5,
                        ),

                        child:
                        Text(
                          "Túlóra vége: "
                              "$overtimeEnd",

                          style:
                          const TextStyle(
                            fontSize:
                            14,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                20,
              ),

              // ==================================================
              // BE / KICSEKKOLÁS
              // ==================================================

              SizedBox(
                width:
                double.infinity,

                height:
                55,

                child:
                ElevatedButton(

                  onPressed:
                  isCheckedOut
                      ? null
                      : isCheckedIn
                      ? checkOut
                      : checkIn,

                  style:
                  ElevatedButton.styleFrom(

                    backgroundColor:
                    isCheckedIn
                        ? const Color(
                      0xFFE34D4D,
                    )
                        : const Color(
                      0xFF1976E8,
                    ),

                    foregroundColor:
                    Colors.white,

                    disabledBackgroundColor:
                    const Color(
                      0xFFBFC5CB,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),

                  child:
                  Text(

                    isCheckedOut
                        ? "MÁR KICSEKKOLTÁL"
                        : isCheckedIn
                        ? overtimeDecision
                        ? "TÚLÓRA KICSEKKOLÁS"
                        : "KICSEKKOLÁS"
                        : "BECSSEKKOLÁS",

                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      fontSize:
                      14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   OTHER PAGES
   ============================================================ */

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  final Set<DateTime> _selectedDays = {};

  Set<String> _existingCheckins = {};
  int _remainingHolidayDays = 0;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCalendarData();
  }

  // ------------------------------------------------------------
  // ADATOK BETÖLTÉSE
  // ------------------------------------------------------------

  Future<void> _loadCalendarData() async {
    final user = _auth.currentUser;

    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final userRef = _firestore
          .collection('users')
          .doc(user.uid);

      final userSnapshot = await userRef.get();

      if (userSnapshot.exists) {
        final data = userSnapshot.data();

        final szabadsag = data?['szabadsag'];

        if (szabadsag is num) {
          _remainingHolidayDays = szabadsag.toInt();
        }
      }

      // Meglévő checkinek lekérése
      final checkinsSnapshot = await userRef
          .collection('checkins')
          .get();

      final existing = <String>{};

      for (final document in checkinsSnapshot.docs) {
        existing.add(document.id);
      }

      if (!mounted) return;

      setState(() {
        _existingCheckins = existing;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hiba az adatok betöltésekor: $e',
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // DÁTUM FORMÁZÁSA
  // ------------------------------------------------------------

  String _dateId(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ------------------------------------------------------------
  // MA
  // ------------------------------------------------------------

  DateTime get _today {
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  // ------------------------------------------------------------
  // VAN-E MÁR CHECKIN AZ ADOTT NAPON?
  // ------------------------------------------------------------

  bool _hasCheckin(DateTime date) {
    return _existingCheckins.contains(
      _dateId(date),
    );
  }

  // ------------------------------------------------------------
  // NAP KIVÁLASZTÁSA
  // ------------------------------------------------------------

  void _selectDay(DateTime date) {
    final day = DateTime(
      date.year,
      date.month,
      date.day,
    );

    // Múltbeli nap tiltása
    if (day.isBefore(_today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Már elmúlt napra nem lehet szabadságot kivenni.',
          ),
        ),
      );

      return;
    }

    // Már létező checkin
    if (_hasCheckin(day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erre a napra már van bejegyzés.',
          ),
        ),
      );

      return;
    }

    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  // ------------------------------------------------------------
  // KIVÁLASZTOTT NAPOK SZÁMA
  // ------------------------------------------------------------

  int get _selectedDaysCount {
    return _selectedDays.length;
  }

  // ------------------------------------------------------------
  // SZABADSÁG KIVÉTELE
  // ------------------------------------------------------------

  Future<void> _takeHoliday() async {
    final user = _auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nincs bejelentkezett felhasználó.',
          ),
        ),
      );

      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Válassz ki legalább egy napot.',
          ),
        ),
      );

      return;
    }

    // Biztonsági ellenőrzés
    if (_selectedDaysCount > _remainingHolidayDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nincs elegendő szabadságod. '
                'Rendelkezésre álló napok: $_remainingHolidayDays.',
          ),
        ),
      );

      return;
    }

    // Ellenőrizzük újra, hogy egyik kiválasztott napra
    // sem került-e közben checkin.
    for (final day in _selectedDays) {
      if (_hasCheckin(day)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A(z) ${_dateId(day)} napra már van bejegyzés.',
            ),
          ),
        );

        return;
      }

      if (day.isBefore(_today)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Már elmúlt napra nem lehet szabadságot kivenni.',
            ),
          ),
        );

        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userRef = _firestore
          .collection('users')
          .doc(user.uid);

      final userSnapshot = await userRef.get();

      if (!userSnapshot.exists) {
        throw Exception(
          'A felhasználói dokumentum nem található.',
        );
      }

      final userData = userSnapshot.data();

      final currentHolidayValue =
      userData?['szabadsag'];

      int currentHolidayDays = 0;

      if (currentHolidayValue is num) {
        currentHolidayDays =
            currentHolidayValue.toInt();
      }

      // Újra ellenőrizzük a Firebase aktuális értékét
      if (_selectedDaysCount > currentHolidayDays) {
        throw Exception(
          'Nincs elegendő szabadság.',
        );
      }

      // Batch használata:
      // vagy minden módosítás megtörténik,
      // vagy egyik sem.
      final batch = _firestore.batch();

      // --------------------------------------------------------
      // CHECKINS LÉTREHOZÁSA
      // --------------------------------------------------------

      for (final day in _selectedDays) {
        final dateId = _dateId(day);

        final checkinRef = userRef
            .collection('checkins')
            .doc(dateId);

        batch.set(
          checkinRef,
          {
            'project': 'Szabi',
            'checkInTime': null,
            'checkOutTime': null,
          },
        );
      }

      final holidayNotificationRef =
      _firestore.collection('holidayNotifications').doc();

      final selectedDates = _selectedDays
          .map((day) => _dateId(day))
          .toList()
        ..sort();

      final userName =
          userData?['name']?.toString() ?? 'Dolgozó';

      batch.set(
        holidayNotificationRef,
        {
          'userId': user.uid,
          'name': userName,
          'dates': selectedDates,
          'sent': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      // --------------------------------------------------------
      // SZABADSÁG KERET CSÖKKENTÉSE
      // --------------------------------------------------------

      final newHolidayBalance =
          currentHolidayDays - _selectedDaysCount;

      batch.update(
        userRef,
        {
          'szabadsag': newHolidayBalance,
        },
      );

      // --------------------------------------------------------
      // MINDEN MENTÉSE
      // --------------------------------------------------------

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _remainingHolidayDays =
            newHolidayBalance;

        for (final day in _selectedDays) {
          _existingCheckins.add(
            _dateId(day),
          );
        }

        _selectedDays.clear();
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sikeresen kivettél '
                '$_selectedDaysCount nap szabadságot.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hiba a szabadság kivételekor: $e',
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // ELŐZŐ HÓNAP
  // ------------------------------------------------------------

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month - 1,
      );

      _selectedDays.clear();
    });
  }

  // ------------------------------------------------------------
  // KÖVETKEZŐ HÓNAP
  // ------------------------------------------------------------

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + 1,
      );

      _selectedDays.clear();
    });
  }

  // ------------------------------------------------------------
  // HÓNAP NEVE
  // ------------------------------------------------------------

  String _monthName(int month) {
    const months = [
      'Január',
      'Február',
      'Március',
      'Április',
      'Május',
      'Június',
      'Július',
      'Augusztus',
      'Szeptember',
      'Október',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  // ------------------------------------------------------------
  // NAPTÁR FELÉPÍTÉSE
  // ------------------------------------------------------------

  List<DateTime?> _generateCalendarDays() {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );

    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;

    // Hétfő = 1, vasárnap = 7
    final firstWeekday =
        firstDayOfMonth.weekday;

    final List<DateTime?> days = [];

    // Üres helyek a hónap elején
    for (int i = 1; i < firstWeekday; i++) {
      days.add(null);
    }

    // Napok
    for (int day = 1; day <= daysInMonth; day++) {
      days.add(
        DateTime(
          _currentMonth.year,
          _currentMonth.month,
          day,
        ),
      );
    }

    return days;
  }

  // ------------------------------------------------------------
  // NAP CELLÁJA
  // ------------------------------------------------------------

  Widget _buildDayCell(DateTime? date) {
    if (date == null) {
      return const SizedBox();
    }

    final isPast = date.isBefore(_today);

    final isSelected =
    _selectedDays.contains(date);

    final hasCheckin =
    _hasCheckin(date);

    final isToday =
        date.year == _today.year &&
            date.month == _today.month &&
            date.day == _today.day;

    return GestureDetector(
      onTap: isPast || hasCheckin
          ? null
          : () => _selectDay(date),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue
              : hasCheckin
              ? Colors.orange.withOpacity(0.8)
              : isToday
              ? Colors.blue.withOpacity(0.15)
              : Colors.transparent,
          borderRadius:
          BorderRadius.circular(10),
          border: isToday && !isSelected
              ? Border.all(
            color: Colors.blue,
            width: 1.5,
          )
              : null,
        ),
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
              isToday || isSelected
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: isSelected
                  ? Colors.white
                  : isPast
                  ? Colors.grey
                  : hasCheckin
                  ? Colors.white
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final calendarDays =
    _generateCalendarDays();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Szabadság'),
        centerTitle: true,
      ),

      body: Column(
        children: [

          // ------------------------------------------------------
          // SZABADSÁG KERET
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              8,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius:
              BorderRadius.circular(14),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
            ),
            child: Row(
              children: [

                const Icon(
                  Icons.beach_access,
                  size: 30,
                ),

                const SizedBox(width: 12),

                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    const Text(
                      'Hátralévő szabadság',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '$_remainingHolidayDays nap',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // HÓNAP VÁLTÓ
          // ------------------------------------------------------

          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [

                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(
                    Icons.chevron_left,
                  ),
                ),

                Text(
                  '${_monthName(_currentMonth.month)} '
                      '${_currentMonth.year}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(
                    Icons.chevron_right,
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // HÉT NAPJAI
          // ------------------------------------------------------

          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            child: Row(
              children: const [
                _WeekDay('H'),
                _WeekDay('K'),
                _WeekDay('Sze'),
                _WeekDay('Cs'),
                _WeekDay('P'),
                _WeekDay('Szo'),
                _WeekDay('V'),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ------------------------------------------------------
          // NAPTÁR
          // ------------------------------------------------------

          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: GridView.builder(
                itemCount: calendarDays.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemBuilder:
                    (context, index) {
                  return _buildDayCell(
                    calendarDays[index],
                  );
                },
              ),
            ),
          ),

          // ------------------------------------------------------
          // KIVÁLASZTOTT NAPOK
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16,
            ),
            child: Column(
              children: [

                Text(
                  'Kiválasztott napok: '
                      '$_selectedDaysCount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed:
                    _isSaving ||
                        _selectedDays.isEmpty
                        ? null
                        : _takeHoliday,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.beach_access,
                    ),
                    label: Text(
                      _isSaving
                          ? 'Mentés...'
                          : 'Szabadság kivétele',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// HÉT NAPJA
// ------------------------------------------------------------

class _WeekDay extends StatelessWidget {
  final String text;

  const _WeekDay(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   PROJEKTEK OLDAL
   ============================================================ */

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor: const Color(0xFF101E2E),
        foregroundColor: Colors.white,

        title: const Text(
          "Projektek",
        ),

        centerTitle: true,
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("projects")
            .snapshots(),

        builder: (context, snapshot) {

          // ==================================================
          // BETÖLTÉS
          // ==================================================

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1976E8),
              ),
            );
          }

          // ==================================================
          // HIBA
          // ==================================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Text(
                  "Nem sikerült betölteni a projekteket:\n\n"
                      "${snapshot.error}",

                  textAlign: TextAlign.center,

                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }

          // ==================================================
          // PROJEKTEK
          // ==================================================

          final documents =
              snapshot.data?.docs ?? [];

          // ==================================================
          // MINDEN PROJEKT MEGJELENIK
          //
          // A "Szabi" IS BENNE VAN
          // ==================================================

          final projects =
          documents.toList();

          // ==================================================
          // NINCS PROJEKT
          // ==================================================

          if (projects.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 60,
                    color: Color(0xFF1976E8),
                  ),

                  SizedBox(height: 15),

                  Text(
                    "Nincs projekt az adatbázisban.",

                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF8A9098),
                    ),
                  ),
                ],
              ),
            );
          }

          // ==================================================
          // PROJEKTEK LISTÁJA
          // ==================================================

          return ListView.builder(
            physics:
            const BouncingScrollPhysics(),

            padding: const EdgeInsets.all(16),

            itemCount: projects.length,

            itemBuilder: (context, index) {
              final project =
              projects[index];

              final data =
              project.data();

              final projectName =
                  project.id;

              final workers =
                  data["Munkások száma"] ?? 0;

              return _ProjectListCard(
                projectName: projectName,
                workers: workers,
              );
            },
          );
        },
      ),
    );
  }
}


/* ============================================================
   PROJEKT KÁRTYA
   ============================================================ */

class _ProjectListCard extends StatelessWidget {
  final String projectName;
  final dynamic workers;

  const _ProjectListCard({
    required this.projectName,
    required this.workers,
  });

  @override
  Widget build(BuildContext context) {

    // A Szabi külön ikont és színt kap
    final bool isHoliday =
        projectName == "Szabi";

    final Color projectColor =
    isHoliday
        ? const Color(0xFF8051D8)
        : const Color(0xFF2679E8);

    final IconData projectIcon =
    isHoliday
        ? Icons.beach_access
        : Icons.business_outlined;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
        BorderRadius.circular(12),

        border: Border.all(
          color: const Color(0xFFE3E8ED),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(.03),

            blurRadius: 8,

            offset:
            const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        children: [

          // ==================================================
          // IKON
          // ==================================================

          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color:
              projectColor.withOpacity(.10),

              borderRadius:
              BorderRadius.circular(10),
            ),

            child: Icon(
              projectIcon,

              color:
              projectColor,

              size: 25,
            ),
          ),

          const SizedBox(width: 14),

          // ==================================================
          // PROJEKT ADATAI
          // ==================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  projectName,

                  maxLines: 1,

                  overflow:
                  TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 16,

                    fontWeight:
                    FontWeight.w700,

                    color:
                    Color(0xFF30363C),
                  ),
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,

                      size: 15,

                      color:
                      Color(0xFF8A9098),
                    ),

                    const SizedBox(width: 5),

                    Text(
                      "$workers fő dolgozik rajta",

                      style:
                      const TextStyle(
                        fontSize: 12,

                        color:
                        Color(0xFF8A9098),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ==================================================
          // DOLGOZÓK SZÁMA
          // ==================================================

          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),

            decoration: BoxDecoration(
              color:
              projectColor.withOpacity(.10),

              borderRadius:
              BorderRadius.circular(8),
            ),

            child: Column(
              children: [
                Text(
                  "$workers",

                  style: TextStyle(
                    fontSize: 17,

                    fontWeight:
                    FontWeight.w800,

                    color:
                    projectColor,
                  ),
                ),

                Text(
                  "fő",

                  style: TextStyle(
                    fontSize: 9,

                    color:
                    projectColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 5),

          const Icon(
            Icons.chevron_right,

            size: 22,

            color:
            Color(0xFFA4AAB1),
          ),
        ],
      ),
    );
  }
}

class MorePage extends StatelessWidget {
  final Future<void> Function()? onLogout;

  const MorePage({
    super.key,
    this.onLogout,
  });

  // ============================================================
  // HÓNAP KIVÁLASZTÁSA
  // ============================================================

  Future<void> _selectMonth(BuildContext context) async {
    final now = DateTime.now();

    int selectedYear = now.year;
    int selectedMonth = now.month;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                "Ledolgozott órák",
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Válaszd ki a letölteni kívánt hónapot.",
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      // ------------------------------------------------
                      // ÉV
                      // ------------------------------------------------

                      DropdownButton<int>(
                        value: selectedYear,

                        items: List.generate(
                          10,
                              (index) {
                            final year =
                                now.year - 5 + index;

                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text(
                                year.toString(),
                              ),
                            );
                          },
                        ),

                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedYear = value;
                          });
                        },
                      ),

                      const SizedBox(
                        width: 15,
                      ),

                      // ------------------------------------------------
                      // HÓNAP
                      // ------------------------------------------------

                      DropdownButton<int>(
                        value: selectedMonth,

                        items: List.generate(
                          12,
                              (index) {
                            final month = index + 1;

                            return DropdownMenuItem<int>(
                              value: month,
                              child: Text(
                                "$month. hónap",
                              ),
                            );
                          },
                        ),

                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedMonth = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },

                  child: const Text(
                    "Mégse",
                  ),
                ),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(
                      DateTime(
                        selectedYear,
                        selectedMonth,
                      ),
                    );
                  },

                  icon: const Icon(
                    Icons.download,
                  ),

                  label: const Text(
                    "Excel készítése",
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    await _generateExcel(
      context,
      result.year,
      result.month,
    );
  }

  // ============================================================
  // IDŐ → PERC
  // ============================================================

  int _timeToMinutes(String? time) {
    if (time == null || time.isEmpty) {
      return 0;
    }

    final parts = time.split(":");

    if (parts.length != 2) {
      return 0;
    }

    final hour =
        int.tryParse(parts[0]) ?? 0;

    final minute =
        int.tryParse(parts[1]) ?? 0;

    return hour * 60 + minute;
  }

  // ============================================================
  // PERC → ÓRA:PP
  // ============================================================

  String _minutesToTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    return "$hours:${mins.toString().padLeft(2, '0')}";
  }

  // ============================================================
  // IDŐKÜLÖNBSÉG
  // ============================================================

  int _calculateMinutes(
      String? start,
      String? end,
      ) {
    if (start == null ||
        end == null ||
        start.isEmpty ||
        end.isEmpty) {
      return 0;
    }

    final startMinutes =
    _timeToMinutes(start);

    var endMinutes =
    _timeToMinutes(end);

    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60;
    }

    return endMinutes - startMinutes;
  }

  // ============================================================
  // EXCEL GENERÁLÁSA
  // ============================================================

  Future<void> _generateExcel(
      BuildContext context,
      int year,
      int month,
      ) async {
    final firestore =
        FirebaseFirestore.instance;

    try {
      // ----------------------------------------------------------
      // BETÖLTÉS JELZÉSE
      // ----------------------------------------------------------

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),

                SizedBox(
                  width: 20,
                ),

                Expanded(
                  child: Text(
                    "Excel készítése...",
                  ),
                ),
              ],
            ),
          );
        },
      );

      // ----------------------------------------------------------
      // DOLGOZÓK
      // ----------------------------------------------------------

      final usersSnapshot =
      await firestore
          .collection("users")
          .get();

      final users =
      usersSnapshot.docs.toList();

      if (users.isEmpty) {
        if (context.mounted) {
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                "Nincs dolgozó az adatbázisban.",
              ),
            ),
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // EXCEL
      // ----------------------------------------------------------

      final excel = excel2.Excel.createExcel();

      final sheet =
      excel["Munkaidő"];

      // ----------------------------------------------------------
      // DOLGOZÓK RENDEZÉSE
      // ----------------------------------------------------------

      users.sort(
            (a, b) {
          final nameA =
          (a.data()["name"] ??
              a.data()["displayName"] ??
              a.data()["email"] ??
              "")
              .toString();

          final nameB =
          (b.data()["name"] ??
              b.data()["displayName"] ??
              b.data()["email"] ??
              "")
              .toString();

          return nameA.compareTo(nameB);
        },
      );

      // ----------------------------------------------------------
      // FEJLÉC
      // ----------------------------------------------------------

      final headerRow =
      <excel2.CellValue>[];

      headerRow.add(
        excel2.TextCellValue(
          "Dátum",
        ),
      );

      for (final user in users) {
        final data =
        user.data();

        final name =
        (data["name"] ??
            data["displayName"] ??
            data["email"] ??
            "Ismeretlen")
            .toString();

        headerRow.add(
          excel2.TextCellValue(
            "$name - Projekt",
          ),
        );

        headerRow.add(
          excel2.TextCellValue(
            "$name - Rendes idő",
          ),
        );

        headerRow.add(
          excel2.TextCellValue(
            "$name - Túlóra",
          ),
        );
      }

      sheet.appendRow(
        headerRow,
      );

      // ----------------------------------------------------------
// OSZLOPSZÉLESSÉGEK
// ----------------------------------------------------------

// Dátum oszlop
      sheet.setColumnWidth(
        0,
        15,
      );

// Minden dolgozóhoz 3 oszlop
      for (int i = 0; i < users.length; i++) {
        final baseColumn = 1 + (i * 3);

        // Projekt
        sheet.setColumnWidth(
          baseColumn,
          25,
        );

        // Rendes idő
        sheet.setColumnWidth(
          baseColumn + 1,
          18,
        );

        // Túlóra
        sheet.setColumnWidth(
          baseColumn + 2,
          15,
        );
      }

      // ----------------------------------------------------------
      // HÓNAP NAPJAI
      // ----------------------------------------------------------

      final daysInMonth =
          DateTime(
            year,
            month + 1,
            0,
          ).day;

      // ----------------------------------------------------------
      // ÖSSZESÍTŐK
      // ----------------------------------------------------------

      final normalTotals =
      List<int>.filled(
        users.length,
        0,
      );

      final overtimeTotals =
      List<int>.filled(
        users.length,
        0,
      );

      // ----------------------------------------------------------
      // MINDEN NAP
      // ----------------------------------------------------------

      for (int day = 1;
      day <= daysInMonth;
      day++) {
        final date =
        DateTime(
          year,
          month,
          day,
        );

        final dateString =
            "${year.toString().padLeft(4, '0')}-"
            "${month.toString().padLeft(2, '0')}-"
            "${day.toString().padLeft(2, '0')}";

        final row =
        <excel2.CellValue>[];

        row.add(
          excel2.TextCellValue(
            dateString,
          ),
        );

        // --------------------------------------------------------
        // MINDEN DOLGOZÓ
        // --------------------------------------------------------

        for (int i = 0;
        i < users.length;
        i++) {
          final user =
          users[i];

          final checkinSnapshot =
          await firestore
              .collection("users")
              .doc(user.id)
              .collection("checkins")
              .doc(dateString)
              .get();

          if (!checkinSnapshot.exists) {
            row.add(
              excel2.TextCellValue("-"),
            );

            row.add(
              excel2.TextCellValue("0:00"),
            );

            row.add(
              excel2.TextCellValue("0:00"),
            );

            continue;
          }

          final data =
              checkinSnapshot.data() ?? {};

          final project =
              data["project"]
                  ?.toString() ??
                  "";

          final checkIn =
          data["checkInTime"]
              ?.toString();

          final checkOut =
          data["checkOutTime"]
              ?.toString();

          final overtimeDecision =
              data["overtimeDecision"] == true;

          final overtimeStart =
          data["overtimeStart"]
              ?.toString();

          final overtimeEnd =
          data["overtimeEnd"]
              ?.toString();

          // ------------------------------------------------------
          // SZABADSÁG
          // ------------------------------------------------------

          if (project == "Szabi") {
            row.add(
              excel2.TextCellValue(
                "SZABADSÁG",
              ),
            );

            row.add(
              excel2.TextCellValue(
                "0:00",
              ),
            );

            row.add(
              excel2.TextCellValue(
                "0:00",
              ),
            );

            continue;
          }

          // ------------------------------------------------------
          // TÚLÓRA KEZDŐDIK 16:00-KOR
          // ------------------------------------------------------

          int overtimeMinutes = 0;

          if (overtimeDecision &&
              overtimeStart != null &&
              overtimeEnd != null) {
            overtimeMinutes =
                _calculateMinutes(
                  overtimeStart,
                  overtimeEnd,
                );
          }

          // ------------------------------------------------------
          // RENDES MUNKAIDŐ
          // ------------------------------------------------------

          int normalMinutes = 0;

          if (checkIn != null &&
              checkOut != null) {
            normalMinutes =
                _calculateMinutes(
                  checkIn,
                  checkOut,
                );
          }

          normalTotals[i] +=
              normalMinutes;

          overtimeTotals[i] +=
              overtimeMinutes;

          // ------------------------------------------------------
          // PROJEKT
          // ------------------------------------------------------

          row.add(
            excel2.TextCellValue(
              project.isNotEmpty
                  ? project
                  : "-",
            ),
          );

          // ------------------------------------------------------
          // RENDES IDŐ
          // ------------------------------------------------------

          row.add(
            excel2.TextCellValue(
              _minutesToTime(
                normalMinutes,
              ),
            ),
          );

          // ------------------------------------------------------
          // TÚLÓRA
          // ------------------------------------------------------

          row.add(
            excel2.TextCellValue(
              _minutesToTime(
                overtimeMinutes,
              ),
            ),
          );
        }

        sheet.appendRow(
          row,
        );
      }

      // ----------------------------------------------------------
      // ÜRES SOR
      // ----------------------------------------------------------

      sheet.appendRow(
        [],
      );

      // ----------------------------------------------------------
      // ÖSSZESÍTŐ
      // ----------------------------------------------------------

      final totalRow =
      <excel2.CellValue>[];

      totalRow.add(
        excel2.TextCellValue(
          "ÖSSZESEN",
        ),
      );

      for (int i = 0;
      i < users.length;
      i++) {
        totalRow.add(
          excel2.TextCellValue(
            "",
          ),
        );

        totalRow.add(
          excel2.TextCellValue(
            _minutesToTime(
              normalTotals[i],
            ),
          ),
        );

        totalRow.add(
          excel2.TextCellValue(
            _minutesToTime(
              overtimeTotals[i],
            ),
          ),
        );
      }

      sheet.appendRow(
        totalRow,
      );

      // ----------------------------------------------------------
// EXCEL FÁJL LETÖLTÉSE CHROME-BAN
// ----------------------------------------------------------

      final bytes = excel.encode();

      if (bytes == null) {
        throw Exception(
          "Nem sikerült létrehozni az Excel fájlt.",
        );
      }

      final fileName =
          "munkaido_${year}_"
          "${month.toString().padLeft(2, '0')}.xlsx";

      // ----------------------------------------------------------
// EXCEL FÁJL MENTÉSE - WEB / ANDROID / IOS
// ----------------------------------------------------------

      final savedFile = await FileSaver.instance.saveFile(
        name: "munkaido_${year}_"
            "${month.toString().padLeft(2, '0')}",
        bytes: Uint8List.fromList(bytes),
        fileExtension: "xlsx",
        mimeType: MimeType.microsoftExcel,
      );

      if (savedFile.isEmpty) {
        throw Exception(
          "A fájl mentése megszakadt vagy nem sikerült.",
        );
      }

// ----------------------------------------------------------
// BETÖLTŐ ABLAK BEZÁRÁSA
// ----------------------------------------------------------

      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              "Az Excel sikeresen letöltődött: $fileName",
            ),
          ),
        );
      }

    } catch (e) {
      // --------------------------------------------------------
      // HIBA
      // --------------------------------------------------------

      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            backgroundColor:
            Colors.red,

            content: Text(
              "Nem sikerült elkészíteni az Excelt: $e",
            ),
          ),
        );
      }
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor:
        const Color(0xFF101E2E),

        foregroundColor:
        Colors.white,

        title: const Text(
          "Több",
        ),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            const Icon(
              Icons.more_horiz,
              size: 60,
              color: Color(0xFF1976E8),
            ),

            const SizedBox(
              height: 15,
            ),

            const Text(
              "Több",

              style: TextStyle(
                fontSize: 24,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            // ==================================================
            // LEDOLGOZOTT ÓRÁK
            // ==================================================

            SizedBox(
              width: 260,
              height: 52,

              child: ElevatedButton.icon(
                onPressed: () {
                  _selectMonth(
                    context,
                  );
                },

                icon: const Icon(
                  Icons.download,
                ),

                label: const Text(
                  "Ledolgozott órák",
                ),

                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(
                    0xFF1976E8,
                  ),

                  foregroundColor:
                  Colors.white,

                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            // ==================================================
            // KIJELENTKEZÉS
            // ==================================================

            ElevatedButton.icon(
              onPressed:
              onLogout == null
                  ? null
                  : () async {
                await onLogout!();
              },

              icon: const Icon(
                Icons.logout,
              ),

              label: const Text(
                "Kijelentkezés",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   SIMPLE PAGE
   ============================================================ */

class _SimplePage extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SimplePage({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor:
        const Color(0xFF101E2E),

        foregroundColor:
        Colors.white,

        title: Text(title),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 60,
              color: const Color(
                0xFF1976E8,
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            Text(
              title,

              style: const TextStyle(
                fontSize: 24,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   SZERSZÁMOK
   ============================================================ */

/* ============================================================
   SZERSZÁMOK
   ============================================================ */

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() =>
      _ToolsPageState();
}

class _ToolsPageState
    extends State<ToolsPage> {

  Map<String, dynamic>? toolData;
  String? scannedCode;
  bool isLoading = false;

  Future<void> scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const QRScannerPage(),
      ),
    );

    if (result == null) return;

    final String qrCode = result.toString();

    setState(() {
      scannedCode = qrCode;
      toolData = null;
      isLoading = true;
    });

    try {
      // ============================================================
      // BEJELENTKEZETT FELHASZNÁLÓ
      // ============================================================

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          "Nincs bejelentkezett felhasználó.",
        );
      }

      // ============================================================
      // FELHASZNÁLÓ NEVÉNEK LEKÉRÉSE
      // ============================================================

      final userSnapshot =
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final userData =
      userSnapshot.data();

      final String userName =
          userData?["name"]?.toString() ??
              userData?["név"]?.toString() ??
              user.displayName ??
              user.email ??
              "Ismeretlen felhasználó";

      // ============================================================
      // SZERSZÁM KERESÉSE QR KÓD ALAPJÁN
      // ============================================================

      final snapshot =
      await FirebaseFirestore.instance
          .collection("tools")
          .where(
        "QR code",
        isEqualTo: qrCode,
      )
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          toolData = null;
          isLoading = false;
        });

        return;
      }

      // ============================================================
      // SZERSZÁM
      // ============================================================

      final toolDoc = snapshot.docs.first;

      // ============================================================
      // AKTUÁLIS DÁTUM ÉS IDŐ
      // ============================================================

      final now = DateTime.now();

      final String formattedDateTime =
          "${now.year}."
          "${now.month.toString().padLeft(2, '0')}."
          "${now.day.toString().padLeft(2, '0')} "
          "${now.hour.toString().padLeft(2, '0')}:"
          "${now.minute.toString().padLeft(2, '0')}";

      // ============================================================
      // FIRESTORE FRISSÍTÉSE
      // ============================================================

      if (userName == "Varga Dávid") {
        // Varga Dávid a szerszámot visszateszi a raktárba
        await toolDoc.reference.update({
          "Használó": "",
          "kivette": "",
        });
      } else {
        // Normál dolgozó kiveszi a szerszámot
        await toolDoc.reference.update({
          "Használó": userName,
          "kivette": formattedDateTime,
        });
      }

      // ============================================================
      // FRISS ADATOK MEGJELENÍTÉSE
      // ============================================================

      final updatedSnapshot =
      await toolDoc.reference.get();

      setState(() {
        toolData =
            updatedSnapshot.data();

        isLoading = false;
      });

      // ============================================================
      // SIKERES ÜZENET
      // ============================================================

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            userName == "Varga Dávid"
                ? "A szerszám visszakerült a raktárba."
                : "A szerszám kiadva: $userName",
          ),
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Hiba a szerszám kiadásakor: $e",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F7FA),

      appBar: AppBar(
        title: const Text(
          "Szerszámok",
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("tools")
            .snapshots(),

        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                "Hiba a szerszámok betöltésekor.",
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
              CircularProgressIndicator(),
            );
          }

          final tools =
              snapshot.data?.docs ?? [];

          // Csak azok a szerszámok,
          // amelyek jelenleg valakinél vannak.
          final issuedTools =
          tools.where((doc) {
            final data =
            doc.data()
            as Map<String, dynamic>;

            final user =
            data["Használó"];

            return user != null &&
                user
                    .toString()
                    .trim()
                    .isNotEmpty;
          }).toList();

          return ListView(
            padding:
            const EdgeInsets.all(20),

            children: [

              const SizedBox(height: 20),

              /* ==================================================
                 QR KÓD BEOLVASÁSA
                 ================================================== */

              SizedBox(
                width: double.infinity,

                child:
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : scanQRCode,

                  icon: const Icon(
                    Icons.qr_code_scanner,
                  ),

                  label: const Text(
                    "QR-kód beolvasása",
                  ),
                ),
              ),

              /* ==================================================
                 BETÖLTÉS
                 ================================================== */

              if (isLoading) ...[
                const SizedBox(height: 30),

                const Center(
                  child:
                  CircularProgressIndicator(),
                ),
              ],

              /* ==================================================
                 NINCS TALÁLAT
                 ================================================== */

              if (!isLoading &&
                  scannedCode != null &&
                  toolData == null) ...[
                const SizedBox(height: 30),

                const Card(
                  child: Padding(
                    padding:
                    EdgeInsets.all(20),

                    child: Column(
                      children: [

                        Icon(
                          Icons
                              .error_outline,
                          size: 45,
                          color: Colors.red,
                        ),

                        SizedBox(height: 10),

                        Text(
                          "Nincs ilyen szerszám az adatbázisban.",
                          textAlign:
                          TextAlign.center,

                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              /* ==================================================
                 BEOLVASOTT SZERSZÁM
                 ================================================== */

              if (!isLoading &&
                  toolData != null) ...[
                const SizedBox(height: 30),

                _ToolInfoCard(
                  toolData: toolData!,
                  scannedCode:
                  scannedCode!,
                ),
              ],

              const SizedBox(height: 30),

              /* ==================================================
                 KIADOTT SZERSZÁMOK CÍM
                 ================================================== */

              const Row(
                children: [

                  Icon(
                    Icons.inventory_2_outlined,
                    size: 24,
                  ),

                  SizedBox(width: 10),

                  Text(
                    "Kiadott szerszámok",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /* ==================================================
                 NINCS KIADOTT SZERSZÁM
                 ================================================== */

              if (issuedTools.isEmpty)
                const Card(
                  child: Padding(
                    padding:
                    EdgeInsets.all(20),

                    child: Text(
                      "Jelenleg nincs kiadott szerszám.",
                      textAlign:
                      TextAlign.center,
                    ),
                  ),
                ),

              /* ==================================================
                 KIADOTT SZERSZÁMOK LISTÁJA
                 ================================================== */

              ...issuedTools.map((doc) {
                final data =
                doc.data()
                as Map<String, dynamic>;

                final String toolName =
                    doc.id;

                final String user =
                    data["Használó"]
                        ?.toString() ??
                        "Ismeretlen";

                final String takenAt =
                    data["kivette"]
                        ?.toString() ??
                        "Nincs adat";

                return Card(
                  margin:
                  const EdgeInsets.only(
                    bottom: 10,
                  ),

                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.build,
                      ),
                    ),

                    title: Text(
                      toolName,

                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    subtitle:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                      children: [

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          "Használó: $user",
                        ),

                        Text(
                          "Kivette: $takenAt",
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}


/* ============================================================
   SZERSZÁM ADATOK
   ============================================================ */

class _ToolInfoCard
    extends StatelessWidget {

  final Map<String, dynamic> toolData;
  final String scannedCode;

  const _ToolInfoCard({
    required this.toolData,
    required this.scannedCode,
  });

  @override
  Widget build(
      BuildContext context) {

    return Card(
      elevation: 2,

      child: Padding(
        padding:
        const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            const Row(
              children: [

                Icon(
                  Icons.build,
                  size: 28,
                ),

                SizedBox(width: 10),

                Text(
                  "Szerszám adatai",

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _ToolDataRow(
              label: "Használó",
              value:
              toolData["Használó"]
                  ?.toString() ??
                  "Nincs adat",
            ),

            _ToolDataRow(
              label: "Kivette",
              value:
              toolData["kivette"]
                  ?.toString() ??
                  "Nincs adat",
            ),
          ],
        ),
      ),
    );
  }
}


/* ============================================================
   SZERSZÁM ADAT SOR
   ============================================================ */

class _ToolDataRow
    extends StatelessWidget {

  final String label;
  final String value;

  const _ToolDataRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context) {

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 12,
      ),

      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          SizedBox(
            width: 85,

            child: Text(
              "$label:",

              style: const TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   QR-KÓD OLVASÓ
   ============================================================ */

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() =>
      _QRScannerPageState();
}

class _QRScannerPageState
    extends State<QRScannerPage> {

  bool alreadyScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,

        title: const Text(
          "QR-kód beolvasása",
        ),
      ),

      body: MobileScanner(
        onDetect: (capture) {
          if (alreadyScanned) return;

          final List<Barcode> barcodes =
              capture.barcodes;

          for (final barcode in barcodes) {
            final String? code =
                barcode.rawValue;

            if (code != null &&
                code.isNotEmpty) {

              alreadyScanned = true;

              Navigator.pop(
                context,
                code,
              );

              break;
            }
          }
        },
      ),
    );
  }
}

/* ============================================================
   ADMIN PAGE
   ============================================================ */

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() =>
      _AdminPageState();
}

class _AdminPageState
    extends State<AdminPage> {

  final TextEditingController toolNameController =
  TextEditingController();

  String? scannedQRCode;

  bool isScanning = false;
  bool isSaving = false;

  /* ============================================================
     QR-KÓD BEOLVASÁSA
     ============================================================ */

  Future<void> scanToolQRCode() async {

    if (isScanning) return;

    setState(() {
      isScanning = true;
    });

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const QRScannerPage(),
      ),
    );

    if (!mounted) return;

    setState(() {
      isScanning = false;
    });

    if (result == null) return;

    final String qrCode =
    result.toString().trim();

    if (qrCode.isEmpty) return;

    setState(() {
      scannedQRCode = qrCode;
    });
  }

  /* ============================================================
     SZERSZÁM MENTÉSE
     ============================================================ */

  Future<void> saveTool() async {

    if (isSaving) return;

    final String toolName =
    toolNameController.text.trim();

    final String? qrCode =
        scannedQRCode;

    /* ==========================================================
       ELLENŐRZÉSEK
       ========================================================== */

    if (qrCode == null ||
        qrCode.isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Először olvasd be a QR-kódot!",
          ),
        ),
      );

      return;
    }

    if (toolName.isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Add meg a szerszám nevét!",
          ),
        ),
      );

      return;
    }

    setState(() {
      isSaving = true;
    });

    try {

      final toolsCollection =
      FirebaseFirestore.instance
          .collection("tools");

      /* ========================================================
         ELLENŐRIZZÜK, HOGY A QR-KÓD NEM LÉTEZIK-E
         ======================================================== */

      final qrSnapshot =
      await toolsCollection
          .where(
        "QR code",
        isEqualTo: qrCode,
      )
          .limit(1)
          .get();

      if (qrSnapshot.docs.isNotEmpty) {

        setState(() {
          isSaving = false;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              "Ez a QR-kód már hozzá van rendelve egy szerszámhoz!",
            ),
          ),
        );

        return;
      }

      /* ========================================================
         ELLENŐRIZZÜK, HOGY A SZERSZÁM NEM LÉTEZIK-E
         ======================================================== */

      final toolDocument =
      toolsCollection.doc(toolName);

      final existingTool =
      await toolDocument.get();

      if (existingTool.exists) {

        setState(() {
          isSaving = false;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              "Már létezik ilyen nevű szerszám!",
            ),
          ),
        );

        return;
      }

      /* ========================================================
         ÚJ SZERSZÁM LÉTREHOZÁSA
         ======================================================== */

      await toolDocument.set({

        "QR code": qrCode,

        "Használó": "",

        "kivette": "",

      });

      /* ========================================================
         MEZŐK TÖRLÉSE
         ======================================================== */

      toolNameController.clear();

      setState(() {

        scannedQRCode = null;

        isSaving = false;

      });

      if (!mounted) return;

      /* ========================================================
         SIKERES ÜZENET
         ======================================================== */

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,

          content: Text(
            "A(z) $toolName szerszám sikeresen hozzáadva!",
          ),
        ),
      );

    } catch (e) {

      setState(() {
        isSaving = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,

          content: Text(
            "Hiba a szerszám mentésekor: $e",
          ),
        ),
      );
    }
  }

  /* ============================================================
     SZERSZÁM FELVITELI KÁRTYA
     ============================================================ */

  Widget buildAddToolCard() {

    return Card(

      elevation: 2,

      child: Padding(

        padding:
        const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            /* ==================================================
               CÍM
               ================================================== */

            const Row(

              children: [

                Icon(
                  Icons.add_box_outlined,
                  size: 28,
                ),

                SizedBox(
                  width: 10,
                ),

                Text(
                  "Új szerszám hozzáadása",

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 25,
            ),

            /* ==================================================
               QR KÓD
               ================================================== */

            const Text(
              "QR-kód",

              style: TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Container(

              width:
              double.infinity,

              padding:
              const EdgeInsets.all(15),

              decoration:
              BoxDecoration(

                border:
                Border.all(
                  color:
                  Colors.grey.shade300,
                ),

                borderRadius:
                BorderRadius.circular(
                  10,
                ),
              ),

              child: Row(

                children: [

                  Icon(
                    scannedQRCode == null
                        ? Icons.qr_code_2
                        : Icons.check_circle,

                    color:
                    scannedQRCode == null
                        ? Colors.grey
                        : Colors.green,

                    size: 28,
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(

                    child: Text(

                      scannedQRCode ??
                          "Nincs QR-kód beolvasva",

                      style:
                      TextStyle(

                        color:
                        scannedQRCode == null
                            ? Colors.grey
                            : Colors.black,

                        fontWeight:
                        scannedQRCode == null
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            /* ==================================================
               QR OLVASÓ GOMB
               ================================================== */

            SizedBox(

              width:
              double.infinity,

              child:
              ElevatedButton.icon(

                onPressed:
                isScanning ||
                    isSaving
                    ? null
                    : scanToolQRCode,

                icon:
                const Icon(
                  Icons.qr_code_scanner,
                ),

                label:
                Text(
                  isScanning
                      ? "QR-kód olvasása..."
                      : "QR-kód beolvasása",
                ),
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            /* ==================================================
               SZERSZÁM NEVE
               ================================================== */

            const Text(
              "Szerszám neve",

              style: TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            TextField(

              controller:
              toolNameController,

              enabled:
              !isSaving,

              decoration:
              InputDecoration(

                hintText:
                "pl. Fúrógép",

                prefixIcon:
                const Icon(
                  Icons.build_outlined,
                ),

                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            /* ==================================================
               MENTÉS
               ================================================== */

            SizedBox(

              width:
              double.infinity,

              height: 50,

              child:
              ElevatedButton.icon(

                onPressed:
                isSaving
                    ? null
                    : saveTool,

                icon:

                isSaving

                    ? const SizedBox(
                  width: 20,
                  height: 20,

                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )

                    : const Icon(
                  Icons.save_outlined,
                ),

                label:

                Text(
                  isSaving
                      ? "Mentés..."
                      : "Szerszám hozzáadása",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ============================================================
     BUILD
     ============================================================ */

  @override
  Widget build(
      BuildContext context) {

    return Scaffold(

      backgroundColor:
      const Color(0xFFF5F7FA),

      appBar: AppBar(

        title:
        const Text(
          "Admin",
        ),
      ),

      body:

      SingleChildScrollView(

        padding:
        const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            /* ==================================================
               ADMIN FEJLÉC
               ================================================== */

            const Row(

              children: [

                Icon(
                  Icons.admin_panel_settings,
                  size: 30,
                ),

                SizedBox(
                  width: 10,
                ),

                Text(
                  "Adminisztráció",

                  style: TextStyle(
                    fontSize: 24,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              "Itt kezelheted a rendszer szerszámait.",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            /* ==================================================
               SZERSZÁM HOZZÁADÁSA
               ================================================== */

            buildAddToolCard(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {

    toolNameController.dispose();

    super.dispose();
  }
}
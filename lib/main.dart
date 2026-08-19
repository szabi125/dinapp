import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'login_screen.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const DinaApp());
}

/* ============================================================
   FIRESTORE - FELHASZNÁLÓ MENTÉSE
   ============================================================ */

Future<void> saveUserToFirestore(User user) async {
  final userRef = FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid);

  final document = await userRef.get();

  if (!document.exists) {
    await userRef.set({
      "email": user.email ?? "",
      "name": user.displayName ?? "Felhasználó",
      "join_date": FieldValue.serverTimestamp(),
      "szabadsag": 0,
    });
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

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Kijelentkezési hiba: $e",
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

      body: SafeArea(
        bottom: false,

        child: IndexedStack(
          index: selectedIndex,

          children: [
            DashboardPage(
              onLogout: logout,
            ),

            const AttendancePage(),

            const CalendarPage(),

            const ProjectsPage(),

            MorePage(
              onLogout: logout,
            ),
          ],
        ),
      ),

      bottomNavigationBar:
      _BottomNavigation(
        selectedIndex: selectedIndex,

        onSelected: (index) {
          setState(() {
            selectedIndex = index;
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

  // ------------------------------------------------------------
  // IDŐ KÜLÖNBSÉG ÓRÁBAN
  // ------------------------------------------------------------

  double calculateHours(
      String checkIn,
      String checkOut,
      ) {
    try {
      final inParts = checkIn.split(":");
      final outParts = checkOut.split(":");

      final inMinutes =
          int.parse(inParts[0]) * 60 +
              int.parse(inParts[1]);

      final outMinutes =
          int.parse(outParts[0]) * 60 +
              int.parse(outParts[1]);

      int difference =
          outMinutes - inMinutes;

      // Ha esetleg éjfél után történt a kicsekkolás
      if (difference < 0) {
        difference += 24 * 60;
      }

      return difference / 60.0;
    } catch (e) {
      return 0;
    }
  }

  // ------------------------------------------------------------
  // ÖSSZES MAI LEDOLGOZOTT ÓRA
  // ------------------------------------------------------------

  Future<double> getTodayWorkedHours(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
      ) async {
    double totalHours = 0;

    final futures = users.map((user) async {
      final checkin = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.id)
          .collection("checkins")
          .doc(today)
          .get();

      if (!checkin.exists) {
        return 0.0;
      }

      final data = checkin.data();

      final checkInTime =
      data?["checkInTime"]?.toString();

      final checkOutTime =
      data?["checkOutTime"]?.toString();

      if (checkInTime == null ||
          checkOutTime == null) {
        return 0.0;
      }

      return calculateHours(
        checkInTime,
        checkOutTime,
      );
    });

    final results = await Future.wait(futures);

    for (final hours in results) {
      totalHours += hours;
    }

    return totalHours;
  }

  // ------------------------------------------------------------
  // ÓRÁK FORMÁZÁSA
  // ------------------------------------------------------------

  String formatHours(double hours) {
    final totalMinutes =
    (hours * 60).round();

    final h =
        totalMinutes ~/ 60;

    final m =
        totalMinutes % 60;

    if (m == 0) {
      return "$h ó";
    }

    return "$h ó ${m.toString().padLeft(2, '0')} p";
  }

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

        final workerCount =
            users.length;

        return FutureBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection("projects")
              .get(),

          builder: (context, projectSnapshot) {
            int activeProjectCount = 0;

            if (projectSnapshot.hasData) {
              final projects =
                  projectSnapshot.data!.docs;

              activeProjectCount = projects
                  .where((project) {
                if (project.id == "Szabi") {
                  return false;
                }

                final data =
                project.data();

                final workers =
                (data["Munkások száma"] ?? 0)
                as num;

                return workers > 0;
              })
                  .length;
            }

            return FutureBuilder<double>(
              future: getTodayWorkedHours(users),

              builder: (
                  context,
                  hoursSnapshot,
                  ) {
                final workedHours =
                    hoursSnapshot.data ?? 0;

                return FutureBuilder<
                    List<
                        DocumentSnapshot<
                            Map<String, dynamic>>>>
                  (
                  future: Future.wait(
                    users.map(
                          (user) {
                        return FirebaseFirestore
                            .instance
                            .collection("users")
                            .doc(user.id)
                            .collection("checkins")
                            .doc(today)
                            .get();
                      },
                    ),
                  ),

                  builder: (
                      context,
                      attendanceSnapshot,
                      ) {
                    int presentCount = 0;

                    if (attendanceSnapshot.hasData) {
                      presentCount =
                          attendanceSnapshot
                              .data!
                              .where(
                                (doc) => doc.exists,
                          )
                              .length;
                    }

                    final attendancePercentage =
                    workerCount > 0
                        ? presentCount /
                        workerCount
                        : 0.0;

                    return Row(
                      children: [
                        // =================================================
                        // DOLGOZÓK
                        // =================================================

                        Expanded(
                          child: _StatCard(
                            icon:
                            Icons.people_outline,
                            color:
                            const Color(
                              0xFF1269DC,
                            ),
                            title: "Dolgozók",
                            value:
                            "$workerCount fő",
                            subtitle:
                            "Adatbázisban",
                            progress:
                            workerCount > 0
                                ? 1.0
                                : 0.0,
                          ),
                        ),

                        const SizedBox(
                          width: 7,
                        ),

                        // =================================================
                        // MAI JELENLÉT
                        // =================================================

                        Expanded(
                          child: _StatCard(
                            icon: Icons
                                .calendar_month_outlined,
                            color:
                            const Color(
                              0xFF22A76A,
                            ),
                            title:
                            "Mai jelenlét",
                            value:
                            "$presentCount fő",
                            subtitle:
                            "${(attendancePercentage * 100).round()}% jelenlét",
                            progress:
                            attendancePercentage
                                .clamp(
                              0.0,
                              1.0,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 7,
                        ),

                        // =================================================
                        // LEDOLGOZOTT ÓRÁK
                        // =================================================

                        Expanded(
                          child: _StatCard(
                            icon:
                            Icons.access_time,
                            color:
                            const Color(
                              0xFFF28A18,
                            ),
                            title:
                            "Ledolgozott órák",
                            value:
                            formatHours(
                              workedHours,
                            ),
                            subtitle:
                            "Mai összesített",
                            progress:
                            workedHours > 0
                                ? (workedHours /
                                8)
                                .clamp(
                              0.0,
                              1.0,
                            )
                                : 0.0,
                          ),
                        ),

                        const SizedBox(
                          width: 7,
                        ),

                        // =================================================
                        // AKTÍV PROJEKTEK
                        // =================================================

                        Expanded(
                          child: _StatCard(
                            icon: Icons
                                .assignment_outlined,
                            color:
                            const Color(
                              0xFF8543D8,
                            ),
                            title:
                            "Aktív projektek",
                            value:
                            "$activeProjectCount db",
                            subtitle:
                            "Folyamatban lévő",
                            progress:
                            activeProjectCount > 0
                                ? 1.0
                                : 0.0,
                          ),
                        ),
                      ],
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

class _StatCard
    extends StatelessWidget {
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
      height: 133,

      padding:
      const EdgeInsets.all(10),

      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(8),

        border: Border.all(
          color:
          const Color(0xFFE8ECF0),
        ),
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Container(
            width: 30,
            height: 30,

            decoration:
            BoxDecoration(
              color:
              color.withOpacity(.12),
              borderRadius:
              BorderRadius.circular(7),
            ),

            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            title,

            maxLines: 1,

            overflow:
            TextOverflow.ellipsis,

            style:
            const TextStyle(
              fontSize: 9,
              color:
              Color(0xFF454B52),
            ),
          ),

          const SizedBox(height: 1),

          Text(
            value,

            style:
            const TextStyle(
              fontSize: 17,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF1E252C),
            ),
          ),

          Text(
            subtitle,

            maxLines: 1,

            overflow:
            TextOverflow.ellipsis,

            style:
            const TextStyle(
              fontSize: 7.5,
              color:
              Color(0xFF9AA0A7),
            ),
          ),

          const Spacer(),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(5),

            child:
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,

              backgroundColor:
              const Color(
                0xFFE9EDF1,
              ),

              valueColor:
              AlwaysStoppedAnimation<
                  Color>(
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

class _DailyOverview
    extends StatelessWidget {
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

  int _timeToMinutes(
      String time) {
    final parts =
    time.split(":");

    if (parts.length != 2) {
      return 0;
    }

    final hour =
        int.tryParse(parts[0]) ?? 0;

    final minute =
        int.tryParse(parts[1]) ?? 0;

    return hour * 60 + minute;
  }

  String _calculateWorkedTime(
      String checkIn,
      String checkOut,
      ) {
    final start =
    _timeToMinutes(checkIn);

    var end =
    _timeToMinutes(checkOut);

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
        FirebaseAuth.instance
            .currentUser;

    if (user == null) {
      return _SectionCard(
        title: "NAPI ÁTTEKINTÉS",
        subtitle:
        formattedDate,

        child: const Center(
          child: Text(
            "Nincs bejelentkezett felhasználó.",

            style: TextStyle(
              fontSize: 9,
              color:
              Color(0xFF8A9098),
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
      subtitle:
      formattedDate,

      child: FutureBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        future: checkinRef.get(),

        builder:
            (context, snapshot) {
          if (snapshot
              .connectionState ==
              ConnectionState
                  .waiting) {
            return const SizedBox(
              height: 120,

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
            return const SizedBox(
              height: 120,

              child: Center(
                child: Text(
                  "Nem sikerült betölteni az adatokat.",

                  textAlign:
                  TextAlign.center,

                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.red,
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData ||
              !snapshot.data!.exists) {
            return const SizedBox(
              height: 120,

              child: Center(
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,

                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 30,
                      color:
                      Color(0xFF9AA0A7),
                    ),

                    SizedBox(height: 8),

                    Text(
                      "Nincs munkavégzés rögzítve.",

                      style: TextStyle(
                        fontSize: 9,
                        color:
                        Color(0xFF8A9098),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final data =
              snapshot.data!.data() ??
                  {};

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
                  icon:
                  Icons.beach_access,
                  iconColor:
                  const Color(
                    0xFF8151D8,
                  ),
                  title:
                  "Állapot",
                  value:
                  "Szabadság",
                ),

                const SizedBox(
                    height: 10),

                const Text(
                  "Ezen a napon szabadságon voltál.",

                  style: TextStyle(
                    fontSize: 9,
                    color:
                    Color(0xFF8A9098),
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

          return Column(
            children: [
              _InfoRow(
                icon:
                Icons.access_time,
                iconColor:
                const Color(
                  0xFF1676E8,
                ),
                title:
                "Ledolgozott órák",
                value:
                workedTime,
              ),

              _InfoRow(
                icon: Icons.login,
                iconColor:
                const Color(
                  0xFF22B573,
                ),
                title:
                "Becsekkolás",
                value:
                checkIn ?? "-",
              ),

              _InfoRow(
                icon: Icons.logout,
                iconColor:
                const Color(
                  0xFFF09A19,
                ),
                title:
                "Kicsekkolás",
                value:
                checkOut ??
                    "Még dolgozik",
              ),

              _InfoRow(
                icon:
                Icons.business_outlined,
                iconColor:
                const Color(
                  0xFF8151D8,
                ),
                title:
                "Projekt",
                value:
                project.isNotEmpty
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

class _EmployeesCard
    extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title:
      "DOLGOZÓK JELENLÉTE",

      subtitle:
      formattedDate,

      child: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
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
            return Padding(
              padding:
              const EdgeInsets
                  .symmetric(
                vertical: 20,
              ),

              child: Text(
                "Nem sikerült betölteni a dolgozókat:\n"
                    "${snapshot.error}",

                style:
                const TextStyle(
                  fontSize: 9,
                  color: Colors.red,
                ),
              ),
            );
          }

          final employees =
              snapshot.data?.docs ??
                  [];

          if (employees.isEmpty) {
            return const Padding(
              padding:
              EdgeInsets.symmetric(
                vertical: 20,
              ),

              child: Center(
                child: Text(
                  "Nincs dolgozó az adatbázisban.",

                  style:
                  TextStyle(
                    fontSize: 9,
                    color:
                    Color(0xFF8A9098),
                  ),
                ),
              ),
            );
          }

          final visibleEmployees =
          employees
              .take(5)
              .toList();

          return Column(
            children: [
              ...visibleEmployees.map(
                    (employee) {
                  return _FirestoreEmployeeRow(
                    employeeId:
                    employee.id,

                    employeeData:
                    employee.data(),

                    selectedDate:
                    selectedDateString,
                  );
                },
              ),

              const SizedBox(
                  height: 3),

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
                      "ÖSSZES DOLGOZÓ MEGTEKINTÉSE",

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
        ? employeeData["name"]
        .toString()
        : "Ismeretlen dolgozó";

    final String? photoUrl =
    employeeData["photoURL"]
        ?.toString();

    return FutureBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      future: FirebaseFirestore
          .instance
          .collection("users")
          .doc(employeeId)
          .collection("checkins")
          .doc(selectedDate)
          .get(),

      builder:
          (context, snapshot) {

        String role =
            "Nincs becsekkolva";

        String time =
            "Hiányzik";

        Color color =
        const Color(0xFFE44E4E);

        IconData icon =
            Icons.person;

        // --------------------------------------------------
        // BETÖLTÉS
        // --------------------------------------------------

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          role = "Betöltés...";
          time = "";

          color =
          const Color(0xFF9AA0A7);

          icon =
              Icons.person;
        }

        // --------------------------------------------------
        // VAN JELENLÉTI ADAT
        // --------------------------------------------------

        if (snapshot.hasData &&
            snapshot.data!.exists) {

          final data =
          snapshot.data!.data();

          final String? project =
          data?["project"]
              ?.toString();

          final String? checkInTime =
          data?["checkInTime"]
              ?.toString();

          final String? checkOutTime =
          data?["checkOutTime"]
              ?.toString();

          // ------------------------------------------------
          // SZABADSÁG
          // ------------------------------------------------

          if (project == "Szabi") {
            role =
            "Szabadságon";

            time = "Szabi";

            color =
            const Color(0xFF8051D8);

            icon =
                Icons.beach_access;
          }

          // ------------------------------------------------
          // JELENLEG DOLGOZIK
          // ------------------------------------------------

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

          // ------------------------------------------------
          // KICSEKKOLT
          // ------------------------------------------------

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
            color:
            Color(0xFFECEFF2),
          ),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 29,
            height: 29,

            decoration:
            BoxDecoration(
              shape:
              BoxShape.circle,

              color:
              const Color(
                0xFFDCE4EC,
              ),

              border:
              Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),

            child:
            photoUrl != null &&
                photoUrl!.isNotEmpty
                ? ClipOval(
              child:
              Image.network(
                photoUrl!,
                width: 29,
                height: 29,
                fit:
                BoxFit.cover,

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

          Expanded(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment
                  .center,

              crossAxisAlignment:
              CrossAxisAlignment
                  .start,

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
                        BoxShape
                            .circle,
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
                          FontWeight
                              .w700,
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
                  TextOverflow
                      .ellipsis,

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
  final Function(int)
  onSelected;

  const _BottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      {
        "icon":
        Icons.home_rounded,
        "label": "Kezdőlap",
      },
      {
        "icon":
        Icons.access_time,
        "label": "Jelenlét",
      },
      {
        "icon":
        Icons.calendar_month_outlined,
        "label": "Naptár",
      },
      {
        "icon":
        Icons.business_outlined,
        "label": "Projektek",
      },
      {
        "icon":
        Icons.more_horiz,
        "label": "Több",
      },
    ];

    return Container(
      height: 72,

      decoration:
      const BoxDecoration(
        color:
        Color(0xFF101E2E),
      ),

      child: Row(
        children:
        List.generate(
          items.length,
              (index) {
            final selected =
                selectedIndex ==
                    index;

            return Expanded(
              child:
              GestureDetector(
                behavior:
                HitTestBehavior
                    .opaque,

                onTap: () =>
                    onSelected(
                      index,
                    ),

                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,

                  children: [
                    Icon(
                      items[index]
                      ["icon"]
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
                        height: 4),

                    Text(
                      items[index]
                      ["label"]
                      as String,

                      style:
                      TextStyle(
                        fontSize: 7,

                        color: selected
                            ? const Color(
                          0xFF1680F5,
                        )
                            : const Color(
                          0xFF8E9AA8,
                        ),

                        fontWeight: selected
                            ? FontWeight
                            .w700
                            : FontWeight
                            .normal,
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

  // ============================================================
  // 16:00 ELLENŐRZÉSE
  // ============================================================

  Future<void> checkOvertimeTime() async {
    if (!mounted) return;

    if (isHoliday) return;

    if (!isCheckedIn) return;

    if (overtimePromptShown) return;

    final now = DateTime.now();

    // 16:00 előtt nincs túlóra kérdés.
    if (now.hour < 16) {
      return;
    }

    // Már van eldöntött túlóra.
    if (overtimeDecision) {
      return;
    }

    await askOvertime();
  }

  // ============================================================
  // TÚLÓRA KÉRDÉS
  // ============================================================

  Future<void> askOvertime() async {
    if (!mounted) return;

    if (isHoliday) return;

    if (!isCheckedIn) return;

    if (overtimePromptShown) return;

    // Azonnal true, hogy ne jelenjen meg többször
    // párhuzamosan.
    setState(() {
      overtimePromptShown = true;
    });

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
                "16:00-tól kezdődik a túlóra.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text(
                "Nem, kicsekkolok",
              ),
            ),
            ElevatedButton(
              onPressed: () {
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

    if (!mounted) return;

    if (result == true) {
      await startOvertime();
    } else {
      await finishNormalWorkday();
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

class MorePage
    extends StatelessWidget {
  final Future<void> Function()?
  onLogout;

  const MorePage({
    super.key,
    this.onLogout,
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

        title:
        const Text("Több"),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment
              .center,

          children: [
            const Icon(
              Icons.more_horiz,
              size: 60,
              color:
              Color(0xFF1976E8),
            ),

            const SizedBox(
                height: 15),

            const Text(
              "Több",

              style:
              TextStyle(
                fontSize: 24,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
                height: 30),

            ElevatedButton.icon(
              onPressed:
              onLogout == null
                  ? null
                  : () async {
                await onLogout!();
              },

              icon:
              const Icon(
                Icons.logout,
              ),

              label:
              const Text(
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

class _SimplePage
    extends StatelessWidget {
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

        title:
        Text(title),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment
              .center,

          children: [
            Icon(
              icon,
              size: 60,
              color:
              const Color(
                0xFF1976E8,
              ),
            ),

            const SizedBox(
                height: 15),

            Text(
              title,

              style:
              const TextStyle(
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
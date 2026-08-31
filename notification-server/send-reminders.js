const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const serviceAccount = require("./serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();
const messaging = getMessaging();

async function main() {
  // =====================================================
  // MAGYAR IDŐ
  // =====================================================

  const now = new Date();

  const timeFormatter = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Budapest",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });

  const dateFormatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Budapest",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });

  const currentTime = timeFormatter.format(now);
  const today = dateFormatter.format(now);

  console.log(`📅 Mai dátum: ${today}`);
  console.log(`🕐 Magyar idő: ${currentTime}`);

  // =====================================================
  // IDŐKORLÁT
  // =====================================================

  const [hour, minute] = currentTime.split(":").map(Number);

  const currentMinutes = hour * 60 + minute;

   const startMinutes = 6 * 60 + 45; // 06:45
   const endMinutes = 16 * 60;       // 16:00

  // 06:45 előtt
  if (currentMinutes < startMinutes) {
    console.log(
      "🌙 Még nincs 06:45 → nincs értesítés."
    );
    return;
  }

  // 16:00 után
  if (currentMinutes >= endMinutes) {
    console.log(
      "🌙 16:00 után vagyunk → nincs értesítés."
    );
    return;
  }

  console.log(
    "✅ Az emlékeztetési időszak aktív."
  );

  // =====================================================
  // FELHASZNÁLÓK
  // =====================================================

  const usersSnapshot = await db.collection("users").get();

  console.log(
    `👥 Felhasználók száma: ${usersSnapshot.size}`
  );

  // =====================================================
  // FELHASZNÁLÓK ELLENŐRZÉSE
  // =====================================================

  for (const userDoc of usersSnapshot.docs) {
    const uid = userDoc.id;
    const userData = userDoc.data();

    const name = userData.name || "Dolgozó";
    const token = userData.fcmToken;

    // ===================================================
    // NINCS TOKEN
    // ===================================================

    if (!token) {
      console.log(
        `⚠️ ${name}: nincs fcmToken`
      );
      continue;
    }

    // ===================================================
    // MAI CHECK-IN
    // ===================================================

    const checkinRef = db
      .collection("users")
      .doc(uid)
      .collection("checkins")
      .doc(today);

    const checkinSnapshot = await checkinRef.get();

    // ===================================================
    // MÁR BECSKKEKOLT
    // ===================================================

    if (checkinSnapshot.exists) {
      console.log(
        `✅ ${name}: már becsekkolt`
      );
      continue;
    }

    // ===================================================
    // NINCS BECSKKEKOLVA → ÉRTESÍTÉS
    // ===================================================

    console.log(
      `🔔 ${name}: nincs becsekkolva → értesítés`
    );

    const message = {
      token: token,

      // =================================================
      // ALAP ÉRTESÍTÉS
      // =================================================

      notification: {
        title: "🔔 DINA95 Jelenléti Rendszer",
        body:
          "Még nem csekkoltál be! Kérlek, rögzítsd a jelenléted.",
      },

      // =================================================
      // WEB
      // =================================================

      webpush: {
        notification: {
          title: "🔔 DINA95 Jelenléti Rendszer",
          body:
            "Még nem csekkoltál be! Kérlek, rögzítsd a jelenléted.",

          icon: "/icons/Icon-192.png",
          badge: "/icons/Icon-192.png",

          tag: "dina95-checkin-reminder",

          requireInteraction: false,

          data: {
            type: "attendance_reminder",
            date: today,
          },
        },

        fcmOptions: {
          link: "/",
        },
      },

      // =================================================
      // ANDROID
      // =================================================

      android: {
        priority: "high",

        notification: {
          title: "🔔 DINA95 Jelenléti Rendszer",
          body:
            "Még nem csekkoltál be! Kérlek, rögzítsd a jelenléted.",

          channelId: "dina95_reminders",
        },
      },

      // =================================================
      // SAJÁT ADATOK
      // =================================================

      data: {
        type: "attendance_reminder",
        date: today,
        url: "/",
      },
    };

    // ===================================================
    // ÉRTESÍTÉS KÜLDÉSE
    // ===================================================

    try {
      const response = await messaging.send(message);

      console.log(
        `📨 ${name}: elküldve`,
        response
      );
    } catch (error) {
      console.error(
        `❌ ${name}: küldési hiba`,
        error.code || error
      );

      // =================================================
      // ÉRVÉNYTELEN TOKEN
      // =================================================

      if (
        error.code ===
          "messaging/registration-token-not-registered" ||
        error.code ===
          "messaging/invalid-registration-token"
      ) {
        await userDoc.ref.update({
          fcmToken: null,
        });

        console.log(
          `🗑️ ${name}: érvénytelen token törölve`
        );
      }
    }
  }

  console.log("🏁 Ellenőrzés befejezve.");
}

main().catch((error) => {
  console.error("❌ Programhiba:");
  console.error(error);
  process.exit(1);
});
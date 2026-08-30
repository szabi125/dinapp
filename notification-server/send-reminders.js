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
  // Magyarországi mai dátum
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Budapest",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });

  const today = formatter.format(new Date());

  console.log(`📅 Mai dátum: ${today}`);

  const usersSnapshot = await db.collection("users").get();

  console.log(
    `👥 Felhasználók száma: ${usersSnapshot.size}`
  );

  for (const userDoc of usersSnapshot.docs) {
    const uid = userDoc.id;
    const userData = userDoc.data();

    const name = userData.name || "Dolgozó";
    const token = userData.fcmToken;

    // Nincs token
    if (!token) {
      console.log(
        `⚠️ ${name}: nincs fcmToken`
      );
      continue;
    }

    // Mai check-in
    const checkinRef = db
      .collection("users")
      .doc(uid)
      .collection("checkins")
      .doc(today);

    const checkinSnapshot = await checkinRef.get();

    // Már becsekkolt
    if (checkinSnapshot.exists) {
      console.log(
        `✅ ${name}: már becsekkolt`
      );
      continue;
    }

    console.log(
      `🔔 ${name}: nincs becsekkolva → értesítés`
    );

    const message = {
      token: token,

      notification: {
        title: "DINA95 Jelenléti Rendszer",
        body:
          "Még nem csekkoltál be! Kérlek, rögzítsd a jelenléted.",
      },

      webpush: {
        notification: {
          title: "DINA95 Jelenléti Rendszer",
          body:
            "Még nem csekkoltál be! Kérlek, rögzítsd a jelenléted.",
          icon: "/icons/Icon-192.png",
        },
      },

      android: {
        notification: {
          title: "DINA95 Jelenléti Rendszer",
          body:
            "Még nem csekkoltál be! Kérlek, rögzítsd a jelenléted.",
        },
      },

      data: {
        type: "attendance_reminder",
        date: today,
      },
    };

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

      // Érvénytelen token esetén töröljük
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
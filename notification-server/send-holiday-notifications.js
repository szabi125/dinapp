const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const fs = require("fs");

// ============================================================
// FIREBASE SERVICE ACCOUNT
// ============================================================

const serviceAccount = require("./serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();
const messaging = getMessaging();

// ============================================================
// DÁTUM FORMÁZÁSA
// ============================================================

function formatHungarianDate(dateId) {
  const [year, month, day] = dateId.split("-");

  const monthNames = [
    "január",
    "február",
    "március",
    "április",
    "május",
    "június",
    "július",
    "augusztus",
    "szeptember",
    "október",
    "november",
    "december",
  ];

  return `${Number(day)}. ${monthNames[Number(month) - 1]}`;
}

// ============================================================
// FŐPROGRAM
// ============================================================

async function main() {
  console.log("🏖️ Szabadság értesítések ellenőrzése...");

  // ----------------------------------------------------------
  // Értesítetlen szabadságok lekérése
  // ----------------------------------------------------------

  const snapshot = await db
    .collection("holidayNotifications")
    .where("sent", "==", false)
    .get();

  if (snapshot.empty) {
    console.log("✅ Nincs új szabadságértesítés.");
    return;
  }

  console.log(
    `📋 Feldolgozandó értesítések: ${snapshot.size}`
  );

  // ----------------------------------------------------------
  // ÖSSZES FELHASZNÁLÓ LEKÉRÉSE
  // ----------------------------------------------------------

  const usersSnapshot = await db
    .collection("users")
    .get();

  console.log(
    `👥 Felhasználók száma: ${usersSnapshot.size}`
  );

  // ----------------------------------------------------------
  // FCM TOKENEK ÖSSZEGYŰJTÉSE
  // ----------------------------------------------------------

  const users = [];

  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();

    const uid = userDoc.id;
    const name = userData.name || "Dolgozó";
    const token = userData.fcmToken;

    if (!token) {
      console.log(
        `⚠️ ${name}: nincs FCM token`
      );

      continue;
    }

    users.push({
      uid,
      name,
      token,
    });
  }

  console.log(
    `📱 Értesíthető felhasználók: ${users.length}`
  );

  // ----------------------------------------------------------
  // MINDEN SZABADSÁGÉRTESÍTÉS FELDOLGOZÁSA
  // ----------------------------------------------------------

  for (const notificationDoc of snapshot.docs) {
    const notificationData =
      notificationDoc.data();

    const userId =
      notificationData.userId;

    const holidayName =
      notificationData.name || "Egy dolgozó";

    const dates =
      Array.isArray(notificationData.dates)
        ? notificationData.dates
        : [];

    // --------------------------------------------------------
    // DÁTUMOK RENDEZÉSE
    // --------------------------------------------------------

    dates.sort();

    const formattedDates = dates.map(
      formatHungarianDate
    );

    let dateText = "";

    if (formattedDates.length === 1) {
      dateText =
        `erre a napra: ${formattedDates[0]}`;
    } else {
      dateText =
        `ezekre a napokra: ${formattedDates.join(", ")}`;
    }

    // --------------------------------------------------------
    // ÉRTESÍTÉS
    // --------------------------------------------------------

    console.log(
      `🏖️ ${holidayName} szabadságot vett ki: ${dates.join(", ")}`
    );

    const sendPromises = [];

    for (const user of users) {
      const message = {
        token: user.token,

        // ====================================================
        // ALAP ÉRTESÍTÉS
        // ====================================================

        notification: {
          title: "🏖️ Szabadság",
          body:
            `${holidayName} szabadságot vett ki ${dateText}.`,
        },

        // ====================================================
        // WEB
        // ====================================================

        webpush: {
          notification: {
            title: "🏖️ Szabadság",
            body:
              `${holidayName} szabadságot vett ki ${dateText}.`,

            icon: "/icons/Icon-192.png",
            badge: "/icons/Icon-192.png",

            tag: `holiday-${notificationDoc.id}`,

            requireInteraction: false,

            data: {
              type: "holiday_notification",
              userId: userId,
              dates: dates.join(","),
            },
          },

          fcmOptions: {
            link: "/",
          },
        },

        // ====================================================
        // ANDROID
        // ====================================================

        android: {
          priority: "high",

          notification: {
            title: "🏖️ Szabadság",
            body:
              `${holidayName} szabadságot vett ki ${dateText}.`,

            channelId: "dina95_reminders",
          },
        },

        // ====================================================
        // SAJÁT ADATOK
        // ====================================================

        data: {
          type: "holiday_notification",
          userId: userId,
          dates: dates.join(","),
        },
      };

      sendPromises.push(
        messaging
          .send(message)
          .then((response) => {
            console.log(
              `📨 ${user.name}: értesítés elküldve`
            );

            return response;
          })
          .catch(async (error) => {
            console.error(
              `❌ ${user.name}: küldési hiba`,
              error.code || error
            );

            // ------------------------------------------------
            // ÉRVÉNYTELEN TOKEN TÖRLÉSE
            // ------------------------------------------------

            if (
              error.code ===
                "messaging/registration-token-not-registered" ||
              error.code ===
                "messaging/invalid-registration-token"
            ) {
              console.log(
                `🗑️ ${user.name}: érvénytelen token törölve`
              );

              await db
                .collection("users")
                .doc(user.uid)
                .update({
                  fcmToken: null,
                });
            }
          })
      );
    }

    // --------------------------------------------------------
    // ÖSSZES ÉRTESÍTÉS MEGVÁRÁSA
    // --------------------------------------------------------

    await Promise.all(sendPromises);

    // --------------------------------------------------------
    // ÉRTESÍTÉS MEGJELÖLÉSE ELKÜLDÖTTKÉNT
    // --------------------------------------------------------

    await notificationDoc.ref.update({
      sent: true,
      sentAt: new Date(),
    });

    console.log(
      `✅ ${holidayName}: értesítés feldolgozva`
    );
  }

  console.log(
    "🏁 Szabadságértesítések feldolgozása befejezve."
  );
}

// ============================================================
// INDÍTÁS
// ============================================================

main().catch((error) => {
  console.error("❌ Programhiba:");
  console.error(error);

  process.exit(1);
});
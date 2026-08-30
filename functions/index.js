const {setGlobalOptions} = require("firebase-functions");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {initializeApp} = require("firebase-admin/app");

initializeApp();

setGlobalOptions({
  maxInstances: 1,
});

/*
============================================================
 AUTOMATIKUS REGGELI JELENLÉTI ÉRTESÍTÉS
============================================================

 Minden 5 percben lefut.

 06:45-től 15:00-ig:
 - megnézi az összes dolgozót
 - megnézi, hogy az adott napra van-e checkin dokumentuma
 - ha nincs:
     -> push értesítést küld
 - ha van:
     -> nem küld értesítést

 A dolgozó FCM tokenje:
 users/{uid}/fcmToken

 A napi jelenlét:
 users/{uid}/checkins/{YYYY-MM-DD}
*/

exports.reggeliJelenletiEmlkezteto = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Europe/Budapest",
  },
  async () => {
    const now = new Date();

    // Magyarországi dátum és idő
    const formatter = new Intl.DateTimeFormat("hu-HU", {
      timeZone: "Europe/Budapest",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });

    const parts = formatter.formatToParts(now);

    const year = parts.find((p) => p.type === "year").value;
    const month = parts.find((p) => p.type === "month").value;
    const day = parts.find((p) => p.type === "day").value;
    const hour = Number(
      parts.find((p) => p.type === "hour").value
    );
    const minute = Number(
      parts.find((p) => p.type === "minute").value
    );

    const today = `${year}-${month}-${day}`;

    console.log(
      `Jelenléti ellenőrzés: ${today} ${hour}:${String(minute).padStart(2, "0")}`
    );

    // 06:45 előtt és 15:00 után nem küldünk
    const currentMinutes = hour * 60 + minute;

    if (currentMinutes < 6 * 60 + 45 ||
        currentMinutes > 15 * 60) {
      console.log("Nincs értesítési időszak.");
      return;
    }

    const db = getFirestore();
    const messaging = getMessaging();

    const usersSnapshot = await db
      .collection("users")
      .get();

    console.log(
      `Összes felhasználó: ${usersSnapshot.size}`
    );

    const sendPromises = [];

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();

      const uid = userDoc.id;
      const name = userData.name || "Dolgozó";
      const token = userData.fcmToken;

      // Nincs FCM token
      if (!token) {
        console.log(
          `${name}: nincs fcmToken`
        );
        continue;
      }

      // Mai checkin dokumentum
      const checkinRef = db
        .collection("users")
        .doc(uid)
        .collection("checkins")
        .doc(today);

      const checkinSnapshot = await checkinRef.get();

      // Ha már van mai jelenléti dokumentum,
      // akkor már becsekkolt / szabadságon van stb.
      if (checkinSnapshot.exists) {
        console.log(
          `${name}: már van mai checkin`
        );
        continue;
      }

      console.log(
        `${name}: NINCS becsekkolva -> értesítés küldése`
      );

      const message = {
        token: token,

        notification: {
          title: "DINA95 Jelenléti Rendszer",
          body: "Még nem csekkoltál be! Kérlek, rögzítsd a jelenléted.",
        },

        webpush: {
          notification: {
            title: "DINA95 Jelenléti Rendszer",
            body: "Még nem csekkoltál be! Kérlek, rögzítsd a jelenléted.",
            icon: "/icons/Icon-192.png",
          },
        },

        android: {
          notification: {
            title: "DINA95 Jelenléti Rendszer",
            body: "Még nem csekkoltál be! Kérlek, rögzítsd a jelenléted.",
          },
        },

        data: {
          type: "attendance_reminder",
          date: today,
        },
      };

      sendPromises.push(
        messaging.send(message)
          .then((response) => {
            console.log(
              `${name}: értesítés elküldve`,
              response
            );
          })
          .catch(async (error) => {
            console.error(
              `${name}: értesítés küldési hiba`,
              error
            );

            // Ha a token már érvénytelen, töröljük,
            // hogy később ne próbáljuk újra használni.
            if (
              error.code ===
                "messaging/registration-token-not-registered" ||
              error.code ===
                "messaging/invalid-registration-token"
            ) {
              console.log(
                `${name}: érvénytelen FCM token törlése`
              );

              await db
                .collection("users")
                .doc(uid)
                .update({
                  fcmToken: null,
                });
            }
          })
      );
    }

    await Promise.all(sendPromises);

    console.log(
      "Jelenléti értesítés ellenőrzés befejezve."
    );
  }
);
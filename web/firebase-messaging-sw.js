importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyC-0sVtXuSXppVPPHr7EvQxG0BLipcXUU0",
  authDomain: "dina95.firebaseapp.com",
  projectId: "dina95",
  storageBucket: "dina95.firebasestorage.app",
  messagingSenderId: "361116656518",
  appId: "1:361116656518:web:63817076bef003536dc207"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Háttérben érkezett FCM:", payload);

  const title =
    payload.notification?.title ||
    "DINA95 Jelenléti Rendszer";

  const body =
    payload.notification?.body ||
    "Új értesítés érkezett.";

  const options = {
    body: body,

    icon: "/icons/Icon-192.png",

    badge: "/icons/Icon-192.png",

    tag: "dina95-notification",

    renotify: true,

    requireInteraction: false,

    data: {
      url: payload.data?.url || "/"
    }
  };

  self.registration.showNotification(title, options);
});


/*
 * Értesítésre kattintás
 */
self.addEventListener("notificationclick", (event) => {

  event.notification.close();

  const urlToOpen =
    event.notification.data?.url || "/";

  event.waitUntil(

    clients.matchAll({
      type: "window",
      includeUncontrolled: true
    }).then((clientList) => {

      // Ha már nyitva van az alkalmazás,
      // akkor azt hozzuk előtérbe.
      for (const client of clientList) {

        if ("focus" in client) {
          return client.focus();
        }
      }

      // Ha nincs megnyitva, megnyitjuk.
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }

    })

  );
});
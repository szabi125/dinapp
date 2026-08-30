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

  const notificationTitle =
    payload.notification?.title || "DINA95 Jelenléti Rendszer";

  const notificationOptions = {
    body: payload.notification?.body || "Új értesítés érkezett.",
    icon: "/icons/Icon-192.png",
  };

  self.registration.showNotification(
    notificationTitle,
    notificationOptions
  );
});
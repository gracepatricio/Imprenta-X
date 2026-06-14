// web/firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyBrwkOBJcZ6Eysv803gvvOMCGQwUd71dTs",
  authDomain: "imprenta-x-system.firebaseapp.com",
  projectId: "imprenta-x-system",
  storageBucket: "imprenta-x-system.firebasestorage.app",
  messagingSenderId: "844000396103",
  appId: "1:844000396103:web:2b33ca52bdf4defe930262",
});

const messaging = firebase.messaging();

// Handle background messages on web
messaging.onBackgroundMessage((payload) => {
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png',
  });
});
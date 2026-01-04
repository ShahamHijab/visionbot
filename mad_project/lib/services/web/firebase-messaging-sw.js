importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: 'AIzaSyApaBAZDuGAP5eeAQTk84YrElAIf2iLN8U',
  appId: '1:747301058022:web:3576e8f5d63fb850891227',
  messagingSenderId: '747301058022',
  projectId: 'visionbot-82c8b',
  authDomain: 'visionbot-82c8b.firebaseapp.com',
  storageBucket: 'visionbot-82c8b.firebasestorage.app',
});

const messaging = firebase.messaging();

// Optional: Handle background messages
messaging.onBackgroundMessage((message) => {
  console.log("onBackgroundMessage", message);
});
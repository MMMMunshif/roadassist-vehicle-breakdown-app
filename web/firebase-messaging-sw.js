self.addEventListener('notificationclick', event => {
  const data=event.notification.data?.FCM_MSG?.data ?? event.notification.data;
  if (!data?.requestId) return;
  event.stopImmediatePropagation();
  event.notification.close();
  const url=new URL('./',self.location.href);
  url.searchParams.set('pushRequest',data.requestId);
  url.searchParams.set('pushType',data.type ?? 'update');
  url.searchParams.set('pushRecipient',data.recipientUid ?? '');
  event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(async windows=>{
    const existing=windows.find(client=>new URL(client.url).origin===url.origin);
    if (existing) { await existing.navigate(url.href); return existing.focus(); }
    return clients.openWindow(url.href);
  }));
});
importScripts('https://www.gstatic.com/firebasejs/12.17.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.17.0/firebase-messaging-compat.js');
firebase.initializeApp({"appId":"1:364238545986:web:addf03955fc923065b39db","messagingSenderId":"364238545986","projectId":"roadassist-lk-munshif","storageBucket":"roadassist-lk-munshif.firebasestorage.app","apiKey":"AIzaSyDTpWj6qtA-AAzWciVw4FQKN8fmV8H4x1w","authDomain":"roadassist-lk-munshif.firebaseapp.com"});
firebase.messaging();
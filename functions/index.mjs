import {createHash} from 'node:crypto';
import {initializeApp} from 'firebase-admin/app';
import {getFirestore, FieldValue, Timestamp} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {onDocumentCreated, onDocumentWritten, onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {setGlobalOptions} from 'firebase-functions/v2';
import {providerMatches, requestAlerts, quoteChanged, messageRecipient, permanentTokenErrors} from './notification_events.mjs';
initializeApp();
setGlobalOptions({region:'asia-south1',maxInstances:3,timeoutSeconds:120,memory:'256MiB'});
const db = getFirestore();
const hash = value => createHash('sha256').update(value).digest('hex');

async function sendTo(uid, notice, eventId, requestId) {
  const profile = await db.doc(`users/${uid}`).get();
  if (!profile.exists || profile.data().pushEnabled === false) return;
  const devices = await db.collection(`users/${uid}/devices`).get();
  if (devices.empty) return;
  const key = hash(`${eventId}:${uid}:${notice.type}`);
  const delivery = db.doc(`notificationDeliveries/${key}`);
  const previous = await db.runTransaction(async tx => {
    const snapshot = await tx.get(delivery);
    const data = snapshot.data() ?? {};
    if (data.done) return null;
    if ((data.leaseUntil?.toMillis() ?? 0) > Date.now()) throw new Error('Notification delivery is still in progress');
    tx.set(delivery,{leaseUntil:Timestamp.fromMillis(Date.now()+150000),updatedAt:FieldValue.serverTimestamp(),expiresAt:Timestamp.fromMillis(Date.now()+7*24*3600000)},{merge:true});
    return new Set(data.processed ?? []);
  });
  if (previous === null) return;
  try {
    const tokens = devices.docs.filter(d => typeof d.data().token === 'string' && d.data().token && !previous.has(hash(d.data().token)));
    let transient = false;
    for (let offset = 0; offset < tokens.length; offset += 500) {
      const batch = tokens.slice(offset,offset+500);
      const response = await getMessaging().sendEachForMulticast({
        tokens:batch.map(d=>d.data().token),notification:{title:notice.title,body:notice.body},
        data:{requestId,type:notice.type,eventId:key,recipientUid:uid},
        android:{priority:'high',notification:{tag:key,channelId:'roadassist_alerts_v1',sound:'default'}},
        apns:{payload:{aps:{sound:'default'}}},
        webpush:{headers:{TTL:'86400'},notification:{tag:key,icon:'/icons/Icon-192.png'}},
      });
      const processed = [];
      for (let i=0;i<response.responses.length;i++) {
        const result = response.responses[i];
        if (result.success || permanentTokenErrors.has(result.error?.code)) {
          processed.push(hash(batch[i].data().token));
          if (!result.success) await batch[i].ref.delete();
        } else transient = true;
      }
      if (processed.length) await delivery.set({processed:FieldValue.arrayUnion(...processed)},{merge:true});
    }
    if (transient) throw new Error('Temporary FCM delivery failure');
    await delivery.set({done:true,leaseUntil:Timestamp.fromMillis(0),updatedAt:FieldValue.serverTimestamp()},{merge:true});
  } catch (error) {
    await delivery.set({leaseUntil:Timestamp.fromMillis(0),updatedAt:FieldValue.serverTimestamp()},{merge:true});
    throw error;
  }
}
async function notifyProviders(request, eventId, requestId) {
  const providers = await db.collection('providerDirectory').where('online','==',true).get();
  const matching = providers.docs.filter(d => providerMatches(request,d.data(),d.id));
  for (let offset=0;offset<matching.length;offset+=10) {
    await Promise.all(matching.slice(offset,offset+10).map(d => sendTo(d.id,{type:'request',title:'New roadside assistance request',body:'A driver needs a service you offer. Open RoadAssist to review and quote.'},eventId,requestId)));
  }
}
export const notifyNewRequest = onDocumentCreated({document:'requests/{requestId}',retry:true}, async event => {
  if (!event.data) return;
  await notifyProviders(event.data.data(),event.id,event.params.requestId);
});
export const notifyRequestUpdates = onDocumentUpdated({document:'requests/{requestId}',retry:true}, async event => {
  if (!event.data) return;
  const before=event.data.before.data(), after=event.data.after.data();
  for (const notice of requestAlerts(before,after)) await sendTo(notice.uid,notice,event.id,event.params.requestId);
  if (before.preferredProviderId && !after.preferredProviderId && after.status === 'searching') await notifyProviders(after,event.id,event.params.requestId);
});
export const notifyQuote = onDocumentWritten({document:'requests/{requestId}/quotes/{providerId}',retry:true},async event => {
  if (!event.data || !event.data.after.exists) return;
  if (!quoteChanged(event.data.before.data(),event.data.after.data())) return;
  const snapshot=await db.doc(`requests/${event.params.requestId}`).get();
  const request=snapshot.data();
  if (!request || request.status !== 'searching') return;
  await sendTo(request.driverId,{type:'quote',title:'Provider offer received',body:'Compare the price and included work before choosing a provider.'},event.id,event.params.requestId);
});
export const notifyChatMessage = onDocumentCreated({document:'requests/{requestId}/messages/{messageId}',retry:true},async event => {
  if (!event.data) return;
  const snapshot=await db.doc(`requests/${event.params.requestId}`).get();
  const request=snapshot.data();
  if (!request) return;
  const uid=messageRecipient(request,event.data.data());
  if (!uid) return;
  await sendTo(uid,{type:'chat',title:'New RoadAssist message',body:'Open RoadAssist to read your message.'},event.id,event.params.requestId);
});
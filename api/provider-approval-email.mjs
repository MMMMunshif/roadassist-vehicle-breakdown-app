import { randomUUID } from 'node:crypto';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import nodemailer from 'nodemailer';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Cache-Control', 'no-store');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({message: 'POST required.'});
  let receipt, attempt;
  try {
    if (!getApps().length) initializeApp({credential: cert({projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL, privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n')})});
    const auth = getAuth(), db = getFirestore();
    const token = (req.headers.authorization ?? '').replace(/^Bearer /, '');
    const actor = await auth.verifyIdToken(token, true);
    const access = (await db.doc(`adminAccess/${actor.uid}`).get()).data();
    const moderation = (await db.doc(`accountModeration/${actor.uid}`).get()).data();
    if (!actor.admin || !actor.email_verified || !access?.enabled ||
        !['super_admin', 'reviewer'].includes(access.role ?? 'super_admin') ||
        moderation?.status === 'suspended' || moderation?.verification === 'rejected') {
      return res.status(403).json({message: 'Provider reviewer permission required.'});
    }
    const uid = req.body?.uid;
    if (typeof uid !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(uid)) return res.status(400).json({message: 'Invalid provider.'});
    const [approvalDoc, applicationDoc, profileDoc, user] = await Promise.all([
      db.doc(`accountModeration/${uid}`).get(), db.doc(`providerApplications/${uid}`).get(),
      db.doc(`users/${uid}`).get(), auth.getUser(uid),
    ]);
    const approval = approvalDoc.data(), application = applicationDoc.data();
    if (!applicationDoc.exists || !application?.professionalDetails || !approval?.validUntil || profileDoc.data()?.role !== 'provider' || !user.emailVerified || user.disabled ||
        approval?.verification !== 'verified' || approval.status !== 'active' ||
        approval.verificationRevision !== application?.revision || approval.validUntil?.toMillis() <= Date.now()) {
      return res.status(409).json({message: 'A current verified approval is required.'});
    }
    receipt = db.doc(`providerApprovalEmails/${uid}_${approval.lastAuditId}`);
    attempt = randomUUID();
    const claimed = await db.runTransaction(async tx => {
      const existing = (await tx.get(receipt)).data();
      if (existing?.status === 'sent' || (existing?.status === 'sending' && existing.startedAt?.toMillis() > Date.now() - 10 * 60 * 1000)) return false;
      tx.set(receipt, {uid, approvalId: approval.lastAuditId, actor: actor.uid, status: 'sending', attempt, startedAt: FieldValue.serverTimestamp()});
      return true;
    });
    if (!claimed) return res.status(200).json({ok: true, message: 'Already sent or delivery in progress.'});
    const transporter = nodemailer.createTransport({service: 'gmail', auth: {user: process.env.GMAIL_USER, pass: process.env.GMAIL_APP_PASSWORD?.replace(/\s/g, '')}});
    const result = await transporter.sendMail({from: `RoadAssist <${process.env.GMAIL_USER}>`, to: user.email,
      subject: 'Your RoadAssist provider verification is complete',
      text: `Hello,\n\nYour provider documents have been reviewed and your RoadAssist provider account is approved until ${approval.validUntil.toDate().toISOString().slice(0,10)}.\n\nSign in to RoadAssist to open your provider dashboard. Driver approval is required before additional work or charges. Keep your documents and contact details current.\n\nRoadAssist team`});
    if (!result.accepted?.length) throw new Error('Recipient not accepted');
    await receipt.update({status: 'sent', sentAt: FieldValue.serverTimestamp()});
    return res.status(200).json({ok: true});
  } catch (error) {
    if (receipt && attempt) {
      await getFirestore().runTransaction(async tx => {
        const data = (await tx.get(receipt)).data();
        if (data?.attempt === attempt && data.status !== 'sent') tx.update(receipt, {status: 'failed', failedAt: FieldValue.serverTimestamp()});
      }).catch(() => {});
    }
    console.error('Provider approval email failed', error?.code ?? 'delivery-error');
    return res.status(500).json({message: 'Approval email unavailable. Your saved approval has not been changed.'});
  }
}

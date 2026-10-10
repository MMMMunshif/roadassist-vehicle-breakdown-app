import {randomUUID} from 'node:crypto';
import {admin, amount, newToken, publicBase, sha256} from './payment-utils.mjs';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Cache-Control', 'no-store');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({message: 'POST required.'});
  if (!/^Bearer .+/.test(req.headers.authorization ?? '')) return res.status(401).json({message: 'Sign in again.'});

  const requestId = req.body?.requestId;
  if (typeof requestId !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(requestId)) {
    return res.status(400).json({message: 'Invalid service request.'});
  }
  try {
    const {auth, db, FieldValue} = await admin();
    const actor = await auth.verifyIdToken(req.headers.authorization.substring(7), true);
    const requestRef = db.doc(`requests/${requestId}`);
    const paymentId = randomUUID();
    const token = newToken();
    const paymentRef = requestRef.collection('payments').doc(paymentId);
    const result = await db.runTransaction(async tx => {
      const snap = await tx.get(requestRef);
      const data = snap.data();
      if (!snap.exists || data?.driverId !== actor.uid) return {status: 403, message: 'Only the assigned driver can pay this invoice.'};
      if (data.status !== 'completed') return {status: 409, message: 'Complete the service before paying.'};
      if (data.providerConfirmedPayment === true || data.paymentStatus === 'paid') return {status: 409, message: 'This invoice is already paid.'};
      const value = amount(data.finalCost ?? data.totalCost ?? data.estimatedCost);
      const existing = await tx.get(paymentRef);
      if (existing.exists) return {status: 409, message: 'Try starting payment again.'};
      tx.set(paymentRef, {
        requestId, orderId: paymentId, driverId: actor.uid, providerId: data.providerId ?? null,
        amount: Number(value), currency: 'LKR', gateway: 'payhere', status: 'created',
        checkoutTokenHash: sha256(token), createdAt: FieldValue.serverTimestamp(),
      });
      return {status: 200, paymentId, checkoutUrl: `${publicBase(req)}/api/payhere-checkout?paymentId=${encodeURIComponent(paymentId)}&token=${encodeURIComponent(token)}`};
    });
    const {status, ...body} = result;
    return res.status(status).json(body);
  } catch (error) {
    console.error('Payment order creation failed', error.code ?? error.message);
    if (error.code?.startsWith('auth/')) return res.status(401).json({message: 'Sign in again.'});
    return res.status(500).json({message: 'Secure payment is temporarily unavailable.'});
  }
}

import {admin, amount, md5} from './payment-utils.mjs';

async function bodyOf(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  let raw = '';
  for await (const chunk of req) raw += chunk;
  return Object.fromEntries(new URLSearchParams(raw));
}

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).send('POST required.');
  try {
    const body = await bodyOf(req);
    const secret = process.env.PAYHERE_MERCHANT_SECRET;
    const expected = md5(`${body.merchant_id}${body.order_id}${body.payhere_amount}${body.payhere_currency}${body.status_code}${md5(secret ?? '')}`);
    if (!secret || body.md5sig?.toUpperCase() !== expected) return res.status(400).send('Invalid signature.');
    const {db, FieldValue} = await admin();
    const paymentQuery = await db.collectionGroup('payments').where('orderId', '==', body.order_id).limit(1).get();
    if (paymentQuery.empty) return res.status(404).send('Payment not found.');
    const paymentRef = paymentQuery.docs[0].ref;
    const payment = paymentQuery.docs[0].data();
    if (amount(payment.amount) !== amount(body.payhere_amount) || payment.currency !== body.payhere_currency) return res.status(400).send('Amount mismatch.');
    const statusCode = String(body.status_code);
    const status = statusCode === '2' ? 'paid' : statusCode === '0' ? 'pending' : statusCode === '-3' ? 'chargeback' : 'failed';
    const requestRef = paymentRef.parent.parent;
    await db.runTransaction(async tx => {
      tx.set(paymentRef, {status, gatewayPaymentId: body.payment_id ?? null, gatewayMethod: body.method ?? null, gatewayStatusCode: statusCode, gatewayUpdatedAt: FieldValue.serverTimestamp()}, {merge: true});
      if (status === 'paid' && requestRef) tx.set(requestRef, {paymentStatus: 'paid', paymentGateway: 'payhere', paymentTransactionId: body.payment_id ?? paymentRef.id, paymentMethod: 'payhere', driverReportedPayment: true, providerConfirmedPayment: true, paymentReportedAt: FieldValue.serverTimestamp(), paymentConfirmedAt: FieldValue.serverTimestamp()}, {merge: true});
    });
    return res.status(200).send('OK');
  } catch (error) {
    console.error('PayHere notification failed', error.message);
    return res.status(500).send('Retry notification.');
  }
}

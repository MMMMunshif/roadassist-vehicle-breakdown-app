import {admin, amount, escapeHtml, md5, sha256} from './payment-utils.mjs';

export default async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'GET') return res.status(405).send('GET required.');
  const paymentId = req.query?.paymentId;
  const token = req.query?.token;
  if (typeof paymentId !== 'string' || !/^[a-f0-9-]{20,80}$/.test(paymentId) || typeof token !== 'string') return res.status(400).send('Invalid payment link.');
  try {
    const merchantId = process.env.PAYHERE_MERCHANT_ID;
    const secret = process.env.PAYHERE_MERCHANT_SECRET;
    if (!merchantId || !secret) return res.status(503).send('Payment gateway is not configured.');
    const {db} = await admin();
    const query = db.collectionGroup('payments').where('checkoutTokenHash', '==', sha256(token)).limit(1);
    const found = await query.get();
    if (found.empty || found.docs[0].id !== paymentId) return res.status(403).send('Payment link expired.');
    const payment = found.docs[0].data();
    if (!['created', 'pending'].includes(payment.status)) return res.status(409).send('This payment is no longer available.');
    const orderId = paymentId;
    const currency = payment.currency ?? 'LKR';
    const formattedAmount = amount(payment.amount);
    const hash = md5(`${merchantId}${orderId}${formattedAmount}${currency}${md5(secret)}`);
    const base = process.env.PAYMENT_PUBLIC_BASE_URL?.replace(/\/$/, '') ?? `${req.headers['x-forwarded-proto'] ?? 'https'}://${req.headers.host}`;
    const action = process.env.PAYHERE_SANDBOX === 'false' ? 'https://www.payhere.lk/pay/checkout' : 'https://sandbox.payhere.lk/pay/checkout';
    const fields = {
      merchant_id: merchantId, return_url: process.env.PAYMENT_RETURN_URL ?? base,
      cancel_url: process.env.PAYMENT_CANCEL_URL ?? base, notify_url: `${base}/api/payhere-notify`,
      order_id: orderId, items: 'RoadAssist roadside service', currency, amount: formattedAmount, hash,
    };
    const inputs = Object.entries(fields).map(([key, value]) => `<input type="hidden" name="${escapeHtml(key)}" value="${escapeHtml(value)}">`).join('');
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.status(200).send(`<!doctype html><html><body onload="document.forms[0].submit()"><p>Redirecting to secure payment…</p><form method="post" action="${escapeHtml(action)}">${inputs}</form></body></html>`);
  } catch (error) {
    console.error('Payment checkout creation failed', error.message);
    return res.status(500).send('Unable to open secure payment.');
  }
}

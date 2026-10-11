export class BillingError extends Error {
  constructor(message, status = 409) { super(message); this.status = status; }
}
export function visitFee(distanceKm) {
  if (!Number.isFinite(distanceKm) || distanceKm < 0 || distanceKm > 500) throw new BillingError('Invalid visit distance.', 400);
  return 100 + Math.max(0, Math.ceil(distanceKm) - 1) * 20;
}
export function distanceKm(a, b) {
  for (const p of [a,b]) if (!Number.isFinite(p.latitude) || !Number.isFinite(p.longitude) || Math.abs(p.latitude)>90 || Math.abs(p.longitude)>180) throw new BillingError('A valid GPS location is required.',400);
  const rad = n => n*Math.PI/180;
  const h = Math.sin(rad(b.latitude-a.latitude)/2)**2 + Math.cos(rad(a.latitude))*Math.cos(rad(b.latitude))*Math.sin(rad(b.longitude-a.longitude)/2)**2;
  return 6371*2*Math.asin(Math.sqrt(Math.min(1,h)));
}
export function finalBill(job, input) {
  const amount = n => Number.isSafeInteger(n) && n >= 0 && n <= 10000000;
  if (!amount(job.dispatchFee) || !amount(input.inspectionFee) || !amount(input.labourFee)) throw new BillingError('Enter valid whole-rupee charges.',400);
  const summary = typeof input.summary === 'string' ? input.summary.trim() : '';
  if (summary.length<10 || summary.length>500) throw new BillingError('Enter a service summary of 10?500 characters.',400);
  if (!Array.isArray(input.items) || input.items.length>10) throw new BillingError('Add at most 10 parts or additional charges.',400);
  const items = input.items.map(i => {
    const label = typeof i?.label === 'string' ? i.label.trim() : '';
    const reason = typeof i?.reason === 'string' ? i.reason.trim() : '';
    if (label.length<2 || label.length>80 || reason.length<3 || reason.length>300 || !amount(i.amount) || i.amount===0) throw new BillingError('Each extra charge needs an item, reason and positive amount.',400);
    return {label,reason,amount:i.amount};
  });
  const extraFee = items.reduce((n,i)=>n+i.amount,0);
  const total = job.dispatchFee + input.inspectionFee + input.labourFee + extraFee;
  if (total>10000000) throw new BillingError('The final bill exceeds the supported amount.',400);
  return {inspectionFee:input.inspectionFee,serviceFee:input.labourFee,extraFee,billItems:items,finalCost:total,estimatedCost:total,serviceNotes:summary,completionReport:{summary}};
}
export function assertVisitQuote(job, quote) {
  if (!quote || quote.driverId!==job.driverId || quote.providerId!==job.preferredProviderId || quote.latitude!==job.latitude || quote.longitude!==job.longitude || quote.visitFee!==job.dispatchFee || job.createdAt.toMillis()>quote.expiresAt.toMillis()) throw new BillingError('Visit fee no longer matches this request. Create a new request.');
}

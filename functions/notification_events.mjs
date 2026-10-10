export function providerMatches(request, provider, id) {
  if (!provider.online || provider.activeRequestId || request.status !== 'searching') return false;
  if (request.preferredProviderId && request.preferredProviderId !== id) return false;
  if ((request.rejectedBy ?? []).includes(id)) return false;
  const issues = request.issues?.length ? request.issues : [request.issue];
  if (provider.services?.length && !issues.every(issue => provider.services.includes(issue))) return false;
  const values = [request.latitude, request.longitude, provider.latitude, provider.longitude];
  if (values.every(v => typeof v === 'number' && Number.isFinite(v))) {
    const [a,b,c,d] = values.map(v => v * Math.PI / 180);
    const h = Math.sin((c-a)/2)**2 + Math.cos(a)*Math.cos(c)*Math.sin((d-b)/2)**2;
    const distance = 6371 * 2 * Math.asin(Math.min(1, Math.sqrt(h)));
    const radius = Number.parseFloat(provider.serviceRadius ?? '15') || 15;
    if (distance > radius) return false;
  }
  return true;
}
export function requestAlerts(before, after) {
  const alerts = [];
  const add = (uid, type, title, body) => { if (uid) alerts.push({uid,type,title,body}); };
  if (before.status !== after.status) {
    if (after.status === 'accepted') add(after.providerId,'selected','Driver selected your offer','Open RoadAssist to review the job and begin your journey.');
    const status = {en_route:['Provider on the way','Your provider has started travelling to you.'],arrived:['Provider arrived','Your provider has arrived. Review proposed work before approving.'],completed:['Service completed','Your service invoice is ready.'],cancelled:['Request cancelled','This assistance request was cancelled.']}[after.status];
    if (status) add(after.driverId,after.status,...status);
    if (after.status === 'cancelled') add(after.providerId,'cancelled',...status);
  }
  if (after.pendingRepairId && before.pendingRepairId !== after.pendingRepairId) add(after.driverId,'repair','Price change needs approval','Review the reason, evidence and new total before approving.');
  if (after.lastRepairDecisionId && before.lastRepairDecisionId !== after.lastRepairDecisionId) add(after.providerId,'decision','Driver reviewed your price change',after.lastRepairDecision === 'approved' ? 'The driver approved the revised work and total.' : 'The driver rejected the proposed change. Keep the existing approved total.');
  if (!before.driverReportedPayment && after.driverReportedPayment) add(after.providerId,'payment_reported','Driver reported payment','Confirm receipt only after receiving the payment.');
  if (!before.providerConfirmedPayment && after.providerConfirmedPayment) add(after.driverId,'payment_confirmed','Payment confirmed','Your provider confirmed that payment was received.');
  if (before.completionState !== 'pending' && after.completionState === 'pending') add(after.driverId,'completion_review','Review completed work and final bill','Check the work details and amount before confirming completion.');
  if (!before.arrivalConfirmedBy && after.arrivalConfirmedBy) add(after.providerId,'job_started','Job start confirmed','The driver confirmed your arrival. Begin only the approved work.');
  if (after.pendingDiscountId && before.pendingDiscountId !== after.pendingDiscountId) add(after.providerId,'discount','Driver requested a revised final amount','Review the requested discount before confirming the final bill.');
  if (before.pendingDiscountId && !after.pendingDiscountId) add(after.driverId,'discount_decision','Provider reviewed your discount request','Open the final bill to review the agreed amount.');
  return alerts;
}
export function quoteChanged(before, after) {
  return !!after && (!before || ['total','quoteType','notes','serviceFee','travelFee','extraFee'].some(key => before[key] !== after[key]));
}
export function messageRecipient(request, message) {
  if (!request.providerId) return null;
  if (message.senderId === request.driverId) return request.providerId;
  if (message.senderId === request.providerId) return request.driverId;
  return null;
}
export const permanentTokenErrors = new Set(['messaging/registration-token-not-registered','messaging/invalid-registration-token']);
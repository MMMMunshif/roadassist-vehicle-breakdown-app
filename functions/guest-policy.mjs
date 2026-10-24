import {BillingError} from './visit-billing-policy.mjs';
export const guestActions = new Set(['prepare','correct','checkout','decide_estimate']);
export function phoneActor(actor) {
  return actor?.firebase?.sign_in_provider === 'phone' && /^\+947\d{8}$/.test(actor.phone_number ?? '');
}
export function guestActor(actor) {
  return phoneActor(actor) || actor?.firebase?.sign_in_provider === 'anonymous' ||
    (actor?.firebase?.sign_in_provider === 'custom' && actor.guestSession === true);
}
export function guestPhone(value) {
  if (typeof value !== 'string' || !/^\+947\d{8}$/.test(value)) throw new BillingError('Enter a valid Sri Lankan mobile number.',400);
  return value;
}
export function assertGuest(actor, profile, session, moderation) {
  if (!guestActor(actor) || profile?.accountType !== 'guest' || profile?.role !== 'guest' ||
      !session?.enabled || session.phone !== profile.phone || (phoneActor(actor) && session.phone !== actor.phone_number) ||
      ['suspended','deleted','disabled'].includes(moderation?.status) || moderation?.verification === 'rejected') {
    throw new BillingError('Reopen your guest session or contact support.',403);
  }
}
export function assertGuestRequest(actor, session, job, requestId) {
  if (!requestId || session?.currentRequestId !== requestId || job?.driverId !== actor.uid || job?.guestRequest !== true) {
    throw new BillingError('This request is not available to this guest session.',403);
  }
}
export function guestName(value) {
  const name=typeof value==='string'?value.trim():'';
  if (name.length<2 || name.length>100) throw new BillingError('Enter your name (2–100 characters).',400);
  return name;
}
export function guestDraft(input) {
  if (!['General Mechanic','Vehicle Towing','Flat Tyre','Battery Jumpstart'].includes(input.issue) ||
      !['Sedan / Hatchback','SUV','Van','Motorcycle'].includes(input.vehicleType)) throw new BillingError('Select a service and vehicle type.',400);
  if (!Number.isFinite(input.latitude)||!Number.isFinite(input.longitude)||Math.abs(input.latitude)>90||Math.abs(input.longitude)>180) throw new BillingError('Select your breakdown location.',400);
  const registration=typeof input.registration==='string'?input.registration.trim():'';
  const modelYear=typeof input.modelYear==='string'?input.modelYear.trim():'';
  const notes=typeof input.notes==='string'?input.notes.trim():'';
  if (registration.length<3||registration.length>20||modelYear.length>80||notes.length>500) throw new BillingError('Check your vehicle registration and notes.',400);
  return {issue:input.issue,issues:[input.issue],vehicleType:input.vehicleType,registration,modelYear,notes,
    latitude:input.latitude,longitude:input.longitude,locationLabel:`GPS location (${input.latitude.toFixed(5)}, ${input.longitude.toFixed(5)})`};
}

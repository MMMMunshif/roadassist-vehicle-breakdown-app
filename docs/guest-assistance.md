# Anonymous guest assistance — free-plan flow

The implementation now uses Firebase Anonymous Authentication, not SMS OTP. No billing upgrade or SMS is required. Live activation has not been performed.

Enable Firebase Authentication > Sign-in method > Anonymous. Deploy the guest Firestore exclusion rule before enabling GUEST_REQUESTS_ENABLED on the backend; then deploy the matching frontend. Existing Firebase free quotas still apply.

Guests enter name and Sri Lankan mobile contact. The number is explicitly unverified, shared with the assigned provider for a confirmation call. The normal member email/role rules remain unchanged.

The server owns guest profiles and sessions. Guest actions are restricted to the current request. Visit fee quotes, physical arrival confirmation, parts approval, final bill and cash receipt confirmation use the existing billing flow. Cash reporting alone never marks a paid receipt. No live card gateway is included.

Save the displayed private recovery code before leaving. A 256-bit random bearer code is hashed in server storage; phone and request IDs cannot recover access. Recovery requires Firebase guest authentication, rechecks suspension/session status and issues a scoped guest custom token. Keep the code private. Browser Firebase persistence also retains the guest session. The code is shown only at initial bootstrap; clearing storage without saving it loses self-service recovery. Receipts are not automatically transferred to a new member account.

The previous OTP emulator suite remains a legacy-phone compatibility check. Anonymous behavior and recovery have additional handler tests. No real SMS or production account creation is involved in local tests.

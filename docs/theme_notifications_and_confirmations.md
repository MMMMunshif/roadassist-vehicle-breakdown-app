# Theme, notifications and departure confirmations

Ordinary feature screens share the role-selection road pattern through RaScaffold. Welcome/splash photo composition and camera preview retain their dedicated presentation. The background paints within each route, so previous routes cannot show through. Provider dashboard uses the existing persistent light/dark control. Provider and admin sign-out actions ask for confirmation; driver already had one. Vehicle changes and provider form changes ask before leaving; in-progress saves/uploads require waiting.

Android creates RoadAssist alerts channel roadassist_alerts_v1. Background FCM payloads select this channel and default sound; foreground messages play its configured sound through a native channel, respecting notification permission, disabled channel, ringer mode and Do Not Disturb. iOS payloads request default sound. OS settings remain authoritative. Browser sound is unchanged. Foreground messages addressed to a different UID are ignored. Real device foreground/background sound and notification taps still need verification.

Approved-provider additional-service changes with renewed admin review remain a separate workflow; current approved applications remain protected from silent edits. Custom declarations work during application submission.

Deployment attempt: Firebase rejected notification-functions deployment because project roadassist-lk-munshif requires the Blaze plan to enable Cloud Build. No billing upgrade was performed. Server notification changes are local until deployment is possible.

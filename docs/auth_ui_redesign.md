# Authentication UI redesign

Scope: Splash, Welcome, Driver/Provider Login, and Driver/Provider Registration.

- `lib/src/features/auth/welcome_screen.dart`: brand, code-drawn road artwork, feature labels and existing entry actions.
- `lib/src/features/auth/splash_screen.dart`: matching brand/loading presentation; existing session routing retained.
- `lib/src/features/auth/auth_form.dart`: shared login/signup presentation with grouped form fields and registration-only photo controls.
- `lib/src/features/auth/auth_visuals.dart`: reusable wordmark and Flutter CustomPainter artwork; no generated images or remote assets.
- LoginScreen and RegistrationScreen remain entry wrappers using the shared form.

Authentication methods, validation rules, provider approval, role routing and Firebase data structures are preserved. Both light and dark schemes use the existing theme. Screens scroll on small displays and with enlarged text.

Validation: 86 Flutter tests passed, including 17 new auth layout/splash cases at 320/430 widths, light/dark mode and enlarged text. The sign-out test now expects the new welcome heading. Physical Android and interactive Chrome visual review remain to be done.

This scope does not complete the full application UI migration. Existing driver-shell edits were left intact.

Visual revision: welcome and splash now use the existing bundled welcome_assistance.jpg photograph instead of the code-drawn road. Welcome uses a simpler trust panel and readable Arial/system fallback typography. No new photo generated.

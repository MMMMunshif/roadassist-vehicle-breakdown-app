# Driver Assistance Request Workflow

This document describes the RoadAssist driver request workflow owned and
demonstrated by Munshif. It maps the visible screens to the application code,
validation rules, Firestore data and viva demonstration steps.

## User flow

1. The driver selects an assistance type.
2. The driver enters the vehicle and breakdown information.
3. The driver optionally attaches up to three incident photos.
4. The driver confirms the current GPS position or enters a location manually.
5. The app lists providers that are currently online.
6. The driver selects a preferred provider and reviews the request.
7. The request is written to Firestore and the searching screen starts listening
   for real-time status changes.
8. If the preferred provider does not respond within 90 seconds, the request is
   expanded to other matching providers.
9. The driver may cancel while the request is still searching.

## Code map

| Responsibility | Main code |
| --- | --- |
| Assistance selection | `lib/src/features/request/assistance_type_screen.dart` |
| Breakdown and vehicle form | `BreakdownDetailsScreen` in `lib/src/screens.dart` |
| Camera and gallery capture | `CameraCaptureScreen` and `PhotoUploadService` |
| Request state between screens | `lib/src/models/request_draft.dart` |
| GPS and manual location | `LocationScreen` in `lib/src/screens.dart` |
| Online provider selection | `ProvidersScreen` in `lib/src/screens.dart` |
| Review and submission | `ReviewScreen` in `lib/src/screens.dart` |
| Firestore create/cancel operations | `lib/src/services/request_service.dart` |
| Searching and provider timeout | `SearchingScreen` in `lib/src/screens.dart` |

## Input validation

- Vehicle model must include a realistic manufacture year.
- Registration numbers are normalised before validation.
- A custom vehicle description is required when `Other` is selected.
- The breakdown description must contain at least 15 characters.
- A location must be selected using GPS or entered manually before review.
- A provider selection is required before a targeted request can be reviewed.

Validation tests are maintained in `test/frontend_flow_test.dart`.

## Firestore request lifecycle

`RequestService.createRequest` stores the authenticated driver's request with
vehicle, issue, location, photo, provider and initial estimate information. The
initial status is `searching`. Subsequent status values are `accepted`,
`en_route`, `arrived`, `completed` or `cancelled`.

The searching screen subscribes to the request document rather than polling.
When the status becomes active, the driver is moved to live tracking. Cancelling
uses `RequestService.cancelRequest`, which records the cancellation instead of
removing the audit history.

## Viva demonstration

1. Sign in using a driver test account.
2. Select `Flat Tyre` from Assistance Type.
3. Show that an incomplete breakdown form cannot continue.
4. Select `Other` and demonstrate the custom vehicle-type validation.
5. Complete the vehicle information and attach a camera/gallery photo.
6. Use current GPS and explain the permission/error handling.
7. Select an online provider and review the preliminary estimate.
8. Submit the request and show its Firestore document.
9. Demonstrate the animated real-time searching state.
10. Cancel a test request and show the resulting `cancelled` status.

## Boundaries with other team modules

This module creates and submits the request. Provider job processing belongs to
Zimthi's provider-operations module. Chat, live tracking, notifications and
routing belong to Fawdhan's real-time quality module. Driver dashboard, profile,
vehicle records, emergency contacts and history belong to Sabra's driver
experience module.

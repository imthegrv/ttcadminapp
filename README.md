# TripClub Operations

Flutter operations app for the TripClub team. The same source builds an Android
APK and a native macOS application without publishing to Google Play or the Mac
App Store.

## Current features

- Secure employee login and authenticator/backup-code 2FA
- Encrypted local session storage
- Responsive Android and macOS navigation
- **Light / dark / system theme** (persisted; toggle in the dashboard header)
- **"Today" dashboard agenda** — today's meetings and due/overdue lead
  follow-ups merged into one time-sorted glance, each tappable
- Live leads, bookings, invoices, customers, meetings, visa-price views
- **Guided multi-step lead wizard** (Contact → Trip → Qualify → Review)
- **Lead detail with stage / priority / status management and an activity
  timeline** (tap a lead to open it)
- **Lead follow-up reminders** — set a due date/time on a lead, get an
  on-device local notification when it's due (survives reboot), a Follow-ups
  board (overdue / today / upcoming via `/crm/leads/followups`), and a
  dashboard alert for what needs attention
- Booking creation plus a **booking detail screen** — status management,
  payment recording (`/bookings/update-financials`), and supplier/notes editing
- Invoice creation plus an **invoice detail screen** — record payments
  (auto-computed paid/balance status), edit client and remarks, item breakdown
- Meeting creation, editing and deletion, with **per-meeting reminder
  notifications** (choose how long before; fires on-device, survives reboot)
- **Full mailbox** — inbox/sent/drafts/archive folders, read/star/archive,
  reading pane, compose and reply (`/mail/*`)
- **Real-time team chat** over Socket.IO (live messages, typing indicator,
  connection status) with an authenticated REST fallback when offline, plus
  **1:1 direct messages** started from the team directory (`/hrm/employees/all`)
- Firebase push registration plus **deep-linking** — tapping a notification
  opens the relevant lead / booking / customer / mailbox
- API base URL configurable at build time

## Design system

The UI is built on a single set of design tokens so the whole product can be
retuned from one place:

- `lib/theme/app_theme.dart` — colours, spacing/radius scale, shadows, and the
  full Material 3 `ThemeData` (app bars, inputs, buttons, nav, chips, sheets).
- `lib/theme/status_palette.dart` — maps API status strings to semantic colours.
- `lib/utils/formatters.dart` — date/time/relative/money/initials helpers
  (no `intl` dependency so it builds offline).
- `lib/widgets/common.dart` — reusable `StatusChip`, `InitialsAvatar`,
  `AppCard`, `SectionHeader`, `StateMessage`, and shimmer `Skeleton`/`ListSkeleton`.
- `lib/widgets/form_kit.dart` — `SubmitBar` (sticky form CTA) and `FormSection`.

`ResourceListScreen` is the configurable surface behind the generic lists
(bookings, invoices, customers, visa prices, notifications); each is wired up
once in `ResourceCatalog` inside `operations_shell.dart`. Leads, mail and chat
have purpose-built screens.

### Dark mode

Neutral colours live in a `Palette` `ThemeExtension` (`app_theme.dart`) with
`light`/`dark` instances; widgets read them through `BuildContext` getters
(`context.surface`, `context.ink`, …). `ThemeController`
(`providers/theme_controller.dart`) persists the user's choice.

### Real-time chat & deep links

- `services/socket_service.dart` wraps the Socket.IO server (host root, not the
  `/v2` REST prefix) and auths with the user object as `handshake.auth.token`.
- `services/navigation_service.dart` exposes a global navigator key so
  `services/deep_link_router.dart` can route push taps without a context.

## Run locally

```sh
flutter pub get
flutter run -d macos --dart-define=TTC_API_URL=https://v1api.thetripclub.com/v2
```

## Build for direct installation

Android:

```sh
flutter build apk --release --dart-define=TTC_API_URL=https://v1api.thetripclub.com/v2
```

Share `build/app/outputs/flutter-apk/app-release.apk`. Android users must allow
installation from the app used to open the APK.

macOS:

```sh
flutter build macos --release --dart-define=TTC_API_URL=https://v1api.thetripclub.com/v2
```

Distribute the generated `.app` inside a signed/notarized DMG for the smoothest
installation. An unsigned internal build can be opened manually, but macOS
Gatekeeper will show additional warnings.

## Next implementation slices

1. Lead assignment and follow-up reminders.
2. Email compose/reply and direct employee chat.
3. Booking type-specific advanced fields and invoice customer selector.
4. Role/permission-aware navigation mirroring the admin ACL.

## Push configuration

Add Android `google-services.json` and macOS `GoogleService-Info.plist` from the
TripClub Firebase project. Configure APNs in Firebase for macOS.

The backend accepts either:

- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `FIREBASE_SERVICE_ACCOUNT_BASE64`

and optionally `FIREBASE_PROJECT_ID`. Device tokens are registered through
`/v2/notifications/devices/register`; existing lead and booking notifications
then also deliver through Firebase Cloud Messaging.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

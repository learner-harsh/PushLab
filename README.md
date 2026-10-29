# PushLab

A native macOS app for sending test push notifications to Apple devices through APNs and to
Android devices through Firebase Cloud Messaging (FCM HTTP v1). It started as a from-scratch
clone of [Push Hero](https://apps.apple.com/in/app/push-hero-test-notifications/id1499227284),
built in SwiftUI with no third-party dependencies.

## Features

- **Templates** – one per app or scenario, with duplicate, rename, drag to reorder, import and export.
- **Authentication**
  - Token based: pick an `AuthKey_XXXXXXXXXX.p8` file (Key ID is auto-filled) or paste the key content, plus Team ID and Key ID. ES256 provider tokens are generated with CryptoKit and cached for 50 minutes.
  - Certificate based: pick a `.p12` export with optional passphrase, with a "Verify certificate" check.
  - Keychain: choose any push identity already installed in Keychain Access.
- **Headers** – environment (sandbox/production), `apns-topic`, `apns-push-type` (alert, background, location, voip, complication, fileprovider, mdm, liveactivity, pushtotalk), `apns-priority` (10/5/1), `apns-expiration`, `apns-collapse-id`, `apns-id`. Every field has an ⓘ button with Apple's explanation, and the app points out when a push type needs a topic suffix.
- **Body** – multiple device tokens per send, a monospaced JSON editor with live validation (with the exact parse error), byte counter against the 4 KB / 5 KB limit, pretty-printing, and payload presets (alert, badge, sound, localized, critical, time sensitive, mutable content, background, Live Activity start/update/end, VoIP, complication, MDM).
- **Android via FCM** – switch a template to *Android · FCM*, pick the Firebase service-account JSON (or paste it), and PushLab mints a one-hour OAuth token with an RS256-signed JWT. Target one or more registration tokens, a topic, or a condition; use the "Validate only" dry run; start from presets for notification, data-only, Android priority/TTL/channel, images, localized text, multi-platform, and APNs-through-FCM messages. Error codes such as `UNREGISTERED` or `SENDER_ID_MISMATCH` are explained inline.
- **History** – every request and APNs response per template with General / Request / Response / Raw tabs, readable reason codes, `apns-id`, latency, and a configurable fetch limit.
- **Copy as cURL** – a ready-to-run `curl --http2` command for the current template.
- **Settings** – appearance, accent color, history fetch limit, import/export, and a one-click importer for Push Hero's template files.

## Build

Open `PushLab.xcodeproj` in Xcode 16 or newer (macOS 14 deployment target) and run, or:

```sh
xcodebuild -project PushLab.xcodeproj -scheme PushLab -configuration Debug build
```

Set your development team under Signing & Capabilities if Xcode asks. The app is sandboxed
with outgoing network and user-selected file access.

## Android setup

1. Firebase console → Project settings → Service accounts → *Generate new private key*.
2. Make sure the Firebase Cloud Messaging API (V1) is enabled for the project in Google Cloud, and the service account has the *Firebase Cloud Messaging API Admin* role (the default key has it).
3. In PushLab, create an Android template, choose the JSON file, press *Test credentials*, paste a registration token from `FirebaseMessaging.getInstance().getToken()`, and send.

The legacy GCM / FCM server-key endpoint was shut down by Google in 2024 and is not supported.

## Importing from Push Hero

Settings → Import & Export → Import from Push Hero, then pick the folder
`~/Library/Containers/com.onmyway133.PushHero/Data/Documents/com.onmyway133.PushHero/Default`.
Each template's name, bundle id, payload, headers, device tokens, key material, and
certificate are converted.

## Data

Templates, history, and preferences are JSON files in the app's Application Support
directory. Templates contain private keys and certificates, so treat exports as secrets.

## Project layout

```
PushLab/
  App/        PushLabApp (scenes, menu commands), AppStore (observable state, send, persistence)
  Models/     PushInput, FCMInput (platform, service account, FCM presets/errors), PushTemplate,
              SendHistoryItem, ReasonCode, Preference, PayloadPresets, FieldHelp
  Services/   APNsClient (HTTP/2 + client cert), JWTSigner (ES256), FCMClient, GoogleAuth (RS256 + OAuth),
              IdentityProvider, InputValidator, CurlExporter, Persistence, TemplateImporter, FilePicker
  Views/      MainView, SidebarView, ProjectView (Auth/Header/Body sections), FCMSections,
              HistoryView, SettingsView, Components
```

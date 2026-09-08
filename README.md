# PieSocket Flutter Demo

A feature demo for the [`piesocket_channels`](https://pub.dev/packages/piesocket_channels)
Flutter SDK's v4 protocol and PieRTC (WebRTC), running against PieSocket's
public `demo` cluster — no backend of your own required.

It is the Flutter counterpart of the [JavaScript demo suite](../javascript-demo),
screen-for-screen, and **interoperates with it**: join the same room from a
browser tab and a Flutter device and you're in the same session.

## Run it

```bash
flutter pub get
flutter run          # pick a device: macOS, an Android device/emulator, or an iOS simulator
```

On first launch you pick a display name (the equivalent of the JS demo's
`#username` URL hash). Change it any time from the icon in the home app bar.
Run a second device — or the browser demo — with a different name to play
both sides.

## Screens

| Screen | Feature | Shared channel(s) |
|---|---|---|
| Chatroom | Multi-channel multiplexing (one socket, two channels), delta presence, typing indicator, C2C direct messages | `general`, `random` |
| Binary transfer | `channel.sendBinary()` → `system::binary`, send a file/image as raw bytes | `binary-demo` |
| 1:1 call | PieRTC two-party video/audio call | `call-<room>` |
| 1:many broadcast | PieRTC broadcast (one broadcaster, many watchers) | `broadcast-<room>` |
| Many:many call | PieRTC full-mesh video conference | `mesh-<room>` |

A **Share screen / Stop sharing** toggle and an audio-only toggle are on every
call screen. `pieRTC.shareScreen()` / `stopScreenShare()` renegotiate the
screen track onto every peer and fire `onScreenSharingStopped` — the demo
shows a remote peer's screen as its own tile. Zero-config on web, desktop,
macOS and iOS (iOS uses in-app ReplayKit capture). **Android** additionally
needs a `mediaProjection` foreground service running while sharing; the
simplest way is the
[`flutter_background`](https://pub.dev/packages/flutter_background) package —
`FlutterBackground.enableBackgroundExecution()` before `shareScreen()` — which
ships the `<service>` its manifest needs. (Not wired into this demo.)

## Cross-platform interop

The Flutter app and the JS demo talk to each other because they match on
every wire-visible detail:

- same cluster (`demo`) and API key, protocol `version: "4"`
- identical channel names (table above)
- identical event names (`chat-message`, `typing`, `file-meta`, `rtc::*`)
  and payload shapes (`meta: { "from": "<name>" }`)
- direct messages are a plain frame with a top-level `system::to`
- PieRTC signalling on the `rtc::` namespace — a plain relay, no server-side
  special-casing

To try it: `npm run demo` in [`../javascript-demo`](../javascript-demo),
open `chatroom-v4.html#web` in a browser, run this app, name yourself
something else, and message between them.

## SDK source: local vs pub.dev

`pubspec.yaml` depends on `piesocket_channels: ^2.4.0` but currently has a
`dependency_overrides` block pointing at the in-repo SDK
(`../../sdks/piesocket-flutter`), so you build against this repo's copy —
including the `sendBinary()` addition. Once 2.4.0 is published to pub.dev,
delete that block and `flutter pub get`.

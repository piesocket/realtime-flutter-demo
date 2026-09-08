import 'package:piesocket_channels/channels.dart';

/// Same public `demo` cluster and key the JavaScript demo suite uses, so a
/// Flutter client and a browser tab land on the same server. Interop only
/// works if cluster, key, protocol version, channel names, event names and
/// payload shapes all match — see the JS demo's `shared/common.js`.
const String demoClusterId = 'demo';
const String demoApiKey = 'wDouy4TMvN5Qw4SkhmZ35skbCBKnlv0fDqKQfhmp';

/// Builds a fresh [PieSocket] for one screen. Each screen owns its own
/// instance and tears it down on exit — mirroring the JS demo, where every
/// page does its own `new PieSocket.default(...)`.
PieSocket buildPieSocket(
  String username, {
  bool presence = true,
  bool notifySelf = true,
}) {
  final options = PieSocketOptions()
    ..setClusterId(demoClusterId)
    ..setApiKey(demoApiKey)
    ..setVersion('4')
    ..setEnableLogs(false)
    ..setNotifySelf(notifySelf)
    ..setPresence(presence)
    ..setUserId(username);

  return PieSocket(options);
}

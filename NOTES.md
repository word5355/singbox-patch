# Notes

## Cross-profile loopback: what was verified

Confirmed on-device (Android 17):

### Granting the permission

```
adb shell pm grant --user <id> io.nekohasekai.sfa android.permission.INTERACT_ACROSS_USERS
adb shell am force-stop --user <id> io.nekohasekai.sfa
```

Grant it in **every** profile that needs to take part (source and
destination), not just one side. The `am force-stop` afterward matters: a
process already running won't pick up a newly granted permission on its
own. (This exact two-step sequence — `pm grant` then `am force-stop` — is
what VentralDigital/InterProfileSharing's own web-based ADB tool does; see
`docs/app.js` on its `web-adb` branch. That project hit the same Android 17
restriction and this permission is confirmed to fix it for their app too.)

Find profile IDs with `adb shell pm list users`.

### What does and doesn't work

- **Same-package, cross-profile, both sides granted: works.** Two sing-box
  instances (e.g. one in the Owner profile, one in Private Space), each
  granted the permission, can reach each other's `127.0.0.1` loopback
  ports. Verified end-to-end with a simple two-hop chain: an inbound in one
  profile forwarding via a `socks` outbound to an inbound in the other,
  which exits `direct`.
- **A third-party app reaching a permission-holding sing-box across
  profiles: does not work**, even with sing-box granted the permission on
  the receiving end. Tested with Termux (no permission of its own) trying
  to reach a granted sing-box in another profile: the connection hangs at
  `Trying 127.0.0.1:<port>...` and times out — packets are being dropped at
  the kernel/netd layer before they ever reach sing-box (nothing shows up
  in its log), not rejected by the app. This means the permission gate is
  keyed on the *connecting* app's identity, not just the listener's.

### The practical implication

The permission alone does **not** let arbitrary apps in another profile
(a browser, etc.) use a proxy exposed on `127.0.0.1` in a different
profile — you can't patch every app that might want to use it. To actually
share routing with everything in another profile, run a **second sing-box
instance inside that profile**, configured as a local VPN there (a `tun`
inbound capturing that profile's traffic normally, no special permission
needed for the apps inside it) whose outbound is a `socks`/`http` client
pointed at the source profile's sing-box over loopback — i.e. the same
same-package relay pattern above, just with the target profile's own
sing-box doing the capturing instead of a raw shared port. Both sing-box
instances still need the permission granted and restarted as above.

### Work Profile (managed profile) is out of scope for the ADB step

`adb shell pm grant --user <id>` (and `pm install --user`, etc.) fails with
`SecurityException: Shell does not have permission to access user <id>` for
a `MANAGED_PROFILE`-type user (a "Work profile", including one created by
an app like Shelter rather than a real MDM) — even while it's running. This
isn't the "profile isn't unlocked yet" issue that affects other secondary
users; it's the Android platform deliberately walling off ADB/shell access
into managed profiles as an enterprise data-isolation boundary, unrelated
to who the profile owner app actually is. Owner and Private Space (and
ordinary secondary/guest users) don't have this restriction.

This is a widely-reported platform limitation, not specific to this repo or
to Shelter: the same `handleIncomingUser`/`translateUserId` exception shows
up for Android Enterprise work profiles and Samsung Secure Folder (also
managed-profile-based) in unrelated projects —
[flutter/flutter#81115](https://github.com/flutter/flutter/issues/81115),
[appium/appium#20366](https://github.com/appium/appium/issues/20366),
[expo/expo#22473](https://github.com/expo/expo/issues/22473).

- **No non-root ADB workaround is known.** A `DevicePolicyManager`-based
  grant from the profile-owner app (Shelter or a real MDM) is not possible
  either way: `setPermissionGrantState()` is [documented as runtime
  (dangerous) permissions
  only](https://developer.android.com/reference/android/app/admin/DevicePolicyManager#setPermissionGrantState(android.content.ComponentName,%20java.lang.String,%20java.lang.String,%20int)),
  and `INTERACT_ACROSS_USERS` is a signature permission, not a runtime one.
- **Root bypasses it.** `adb shell su -c 'pm grant --user <id>
  io.nekohasekai.sfa android.permission.INTERACT_ACROSS_USERS'` — root
  (UID 0) skips this permission check entirely, unlike the unprivileged
  `shell` UID adb normally runs as.

## Pipeline internals

- After building, it verifies with `aapt2 dump permissions` that the
  permission actually made it into the APK, and fails the build otherwise
  (guards against silently shipping an unpatched APK).
- sing-box is GPL-3.0 licensed; this repo only patches and re-signs the
  already-public release binaries, it doesn't modify or redistribute the
  source.

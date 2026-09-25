# pong-notification

Default notification sound: **Pong** instead of LineageOS's Argon.

Pong is a LineageOS sound, not an OEM one -- `vendor/lineage/prebuilt/common/media/audio/
notifications/Pong.ogg`, copied to every device by `vendor/lineage/config/lineage_audio.mk`. So this
works on any device and any branch, and needs no per-branch patch.

## How it works

`RingtoneManager` resolves the default notification from a system property:

    RingtoneManager.java
      case TYPE_NOTIFICATION: return SystemProperties.get("ro.config.notification_sound");

Lineage sets it to `Argon.ogg` in `vendor/lineage/config/common_mobile.mk`. The option sets it to
`Pong.ogg` from `vendor/extra/product.mk`, which `common.mk` inherits first for exactly this reason:
`ro.*` properties are immutable, so the first value into `build.prop` wins and the later Lineage
assignment is ignored.

## Scope

Only the notification sound. The ringtone (`ro.config.ringtone`) and the alarm
(`ro.config.alarm_alert`, Hassium) are left at their defaults -- change those here if wanted, they
use the same mechanism.

Does not affect a device that has already booted: the property seeds the *default*, and a user who
has chosen a notification sound keeps it. Visible on a clean flash.

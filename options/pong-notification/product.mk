# LineageOS sets ro.config.notification_sound=Argon.ogg in
# vendor/lineage/config/common_mobile.mk. RingtoneManager reads that property directly
# (RingtoneManager.java, getDefaultRingtone -> TYPE_NOTIFICATION), so overriding it is the whole
# change -- no patch to any tree.
#
# This wins because vendor/extra/product.mk is inherited FIRST by common.mk and ro.* properties are
# immutable: the first value written into build.prop is the one that sticks, and every later
# assignment of the same name is ignored.
#
# Guarded on the file existing. Pong.ogg comes from vendor/lineage/config/lineage_audio.mk, which
# copies it unconditionally on every device, but a branch that dropped it would otherwise leave the
# property pointing at a missing file -- and a default notification sound that silently does not
# play is a miserable thing to debug.
ifneq ($(wildcard vendor/lineage/prebuilt/common/media/audio/notifications/Pong.ogg),)
PRODUCT_PRODUCT_PROPERTIES += ro.config.notification_sound=Pong.ogg
endif

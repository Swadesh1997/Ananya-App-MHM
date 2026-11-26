# R8 keep rules for the release build.
#
# build.gradle has named this file since the first commit but it never existed,
# so every release bundle so far was minified with no app-specific rules at all.
# That matters most for period reminders, which are the one feature that fails
# in a way nobody notices until a girl's reminder does not arrive.
#
# Nothing here is an optimisation. Each rule keeps something that is reached by
# reflection or by name, which R8 cannot see and therefore renames or deletes.

# --- flutter_local_notifications -------------------------------------------
#
# Required by the plugin whenever minifyEnabled is on. Two separate reasons:
#
#   1. The plugin's Android side is found from Dart by class name.
#   2. A scheduled notification is written to shared preferences as JSON via
#      Gson and read back by ScheduledNotificationBootReceiver after a reboot.
#      Gson maps JSON keys onto *field names*, so renaming the model fields
#      silently turns every stored reminder into nulls. The app declares
#      RECEIVE_BOOT_COMPLETED and reschedules on boot, so this path is live for
#      anyone who restarts her phone between logging a period and the reminder
#      firing — which, over a 28-day wait, is nearly everyone.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# --- Gson ------------------------------------------------------------------
#
# Gson reads generic types at runtime, so the Signature attribute has to
# survive; without it a List<T> field deserialises as raw Object. The
# annotation attribute is what @SerializedName is carried in.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-dontwarn sun.misc.**

# --- Kept because the manifest names them ----------------------------------
#
# A class referenced only from AndroidManifest.xml has no Java caller for R8 to
# trace, and the boot receiver is exactly that.
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver

# --- Play Core ------------------------------------------------------------
#
# Flutter's engine references the deferred-components API even when no deferred
# component exists. Without this the release build fails on missing classes
# rather than at runtime.
-dontwarn com.google.android.play.core.**

# R8 rules for release builds. Flutter, Firebase and other plugins ship
# their own consumer rules; these cover the app's own native code.

# Native location bridge: the foreground service is started by name from the
# manifest and the plugin is registered from MainActivity.
-keep class in.moops.stride.** { *; }

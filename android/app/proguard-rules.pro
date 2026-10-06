# UTE BLE SDK (Nadal) — подавление ВСЕХ предупреждений R8 для LZ4
-dontwarn net.jpountz.**
-keep class net.jpountz.** { *; }

# Сохранение всех классов UTE SDK
-keep class utejxchar.** { *; }
-keep class com.ute.** { *; }

# UTE Nadal SDK (основной пакет com.yc.nadalsdk.**)
-keep class com.yc.nadalsdk.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-dontwarn com.yc.nadalsdk.**

# JieLi OTA & Watch SDK
-dontwarn com.jieli.**
-keep class com.jieli.** { *; }

# Actions OTA & Ibluz SDK
-dontwarn com.actions.**
-keep class com.actions.** { *; }


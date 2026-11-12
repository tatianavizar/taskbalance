# kotlinx.serialization: keep the generated serializers of the bridge messages.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class app.cinquante.mobile.** {
    *** Companion;
}
-keepclasseswithmembers class app.cinquante.mobile.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class app.cinquante.mobile.**$$serializer { *; }

# Hotwire Native creates destinations and bridge components by reflection.
-keep class dev.hotwire.** { *; }
-keep class app.cinquante.mobile.bridge.** { *; }

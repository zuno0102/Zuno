# Razorpay Checkout survives shrinking.
#
# The SDK reaches its own classes reflectively and talks to Checkout's web layer over a
# JavaScript bridge, so R8 sees most of it as unreachable and strips it. The result is a release
# build where paying a crew fails and a debug build where it works — the worst shape a payment
# bug can take. Rules taken from Razorpay's own integration guide.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }

# Razorpay's plugin classes are looked up by name at runtime.
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
    public void onPayment*(...);
}

# The QR scanner (mobile_scanner → Google ML Kit barcode scanning) survives shrinking.
#
# ML Kit finds its scanner through a component registry that loads classes by name, so R8 sees
# them as unused and strips or renames them. The plugin's own rule keeps only the top package
# (`com.google.mlkit.*`, one star), not `com.google.mlkit.vision.barcode.internal`, so the release
# APK opened the camera to "Attempt to invoke virtual method 'z9.c z9.b.a(v9.b)' on a null object
# reference" — the barcode factory, renamed, came back null. Debug builds are not shrunk and worked.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode_bundled.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_**

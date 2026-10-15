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

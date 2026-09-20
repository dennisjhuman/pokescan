# ML Kit text recognition ships one artifact per script. We bundle only the
# Latin recognizer, but the Flutter plugin's Dart-facing entry point names all
# five, so R8 sees references to four classes that are not on the classpath and
# fails the release build. They are unreachable at runtime — nothing in this
# app asks for Chinese, Devanagari, Japanese or Korean — so warning about them
# is noise.
#
# If Japanese card support ever lands (see CLAUDE.md), swap the japanese
# -dontwarn for the real dependency rather than deleting this comment.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit loads its models and options through reflection, so the usual
# reachability analysis cannot see them.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }

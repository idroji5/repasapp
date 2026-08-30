# El plugin de ML Kit declara los reconocedores de todos los alfabetos, pero la
# app solo empaqueta el latino: es el único que necesita el castellano, y meter
# los demás engordaría el APK con modelos que nunca se usan.
#
# R8 ve esas referencias sin destino y aborta la compilación. Estas líneas le
# dicen que la ausencia es intencionada, no un error de dependencias.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit carga sus componentes por reflexión: si se renombran, no se encuentran.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text** { *; }

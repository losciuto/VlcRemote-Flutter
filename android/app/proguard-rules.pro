# Preserva le classi JNA necessarie a Vosk per evitare
# UnsatisfiedLinkError su com.sun.jna.Pointer su Android recente.
-keep class com.sun.jna.** { *; }
-keep interface com.sun.jna.** { *; }
-keep class org.vosk.** { *; }

# JNA riferisce classi java.awt.* inesistenti su Android: le ignora.
-dontwarn com.sun.jna.**
-dontwarn java.awt.**

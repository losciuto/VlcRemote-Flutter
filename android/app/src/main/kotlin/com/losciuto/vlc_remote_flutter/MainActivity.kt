package com.losciuto.vlc_remote_flutter

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        init {
            // Carica la libreria nativa JNA prima che Vosk inizializzi.
            // Su Android recente le classi JNA e libjnidispatch.so devono
            // essere della stessa versione, altrimenti Native.initIDs()
            // crasha con UnsatisfiedLinkError su com.sun.jna.Pointer.
            System.loadLibrary("jnidispatch")
        }
    }
}

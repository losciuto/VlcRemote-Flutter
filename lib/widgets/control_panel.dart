import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vlc_provider.dart';

class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  // Stato locale per gestire il trascinamento fluido
  bool _isSeeking = false;
  double _seekValue = 0.0;
  DateTime? _lastSeekTime;
  
  bool _isChangingVolume = false;
  double _volumeValue = 0.0;
  DateTime? _lastVolumeTime;

  @override
  Widget build(BuildContext context) {
    return Consumer<VlcProvider>(
      builder: (context, provider, _) {
        final status = provider.status;
        final now = DateTime.now();
        
        // Se stiamo trascinando O se abbiamo appena finito (grace period di 2 secondi)
        // usiamo il valore locale per evitare saltelli mentre VLC si sincronizza
        final bool useLocalSeek = _isSeeking || 
            (_lastSeekTime != null && now.difference(_lastSeekTime!) < const Duration(seconds: 2));
            
        final currentSeek = useLocalSeek 
            ? _seekValue 
            : status.currentTime.toDouble();
            
        final maxSeek = status.totalTime > 0 
            ? status.totalTime.toDouble() 
            : 1.0;
            
        final bool useLocalVolume = _isChangingVolume ||
            (_lastVolumeTime != null && now.difference(_lastVolumeTime!) < const Duration(seconds: 2));

        final double currentVolume = useLocalVolume
            ? _volumeValue
            : (status.volume?.toDouble() ?? 50.0);

        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Barra di progressione (Seek)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          // Se cerchiamo, formattiamo il valore locale
                          _isSeeking 
                              ? _formatTime(_seekValue.toInt())
                              : status.currentTimeFormatted,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          status.totalTimeFormatted,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    Slider(
                      value: currentSeek.clamp(0.0, maxSeek),
                      min: 0.0,
                      max: maxSeek,
                      onChanged: (value) {
                         setState(() {
                           _isSeeking = true;
                           _seekValue = value;
                           _lastSeekTime = DateTime.now();
                         });
                      },
                      onChangeEnd: (value) {
                        provider.seekTo(value);
                        setState(() {
                          _isSeeking = false;
                          _lastSeekTime = DateTime.now();
                        });
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),

                // Controlli principali (Prev, Play, Stop, Next)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      context,
                      icon: Icons.skip_previous,
                      label: '',
                      color: Colors.grey[700]!,
                      onPressed: provider.previous,
                      size: 48,
                    ),
                    _buildControlButton(
                      context,
                      icon: status.isPlaying ? Icons.pause : Icons.play_arrow,
                      label: '',
                      color: status.isPlaying ? Colors.orange : Colors.green,
                      onPressed: status.isPlaying ? provider.pause : provider.play,
                      size: 64,
                    ),
                    _buildControlButton(
                      context,
                      icon: Icons.stop,
                      label: '',
                      color: Colors.red,
                      onPressed: provider.stop,
                      size: 48,
                    ),
                     _buildControlButton(
                      context,
                      icon: Icons.skip_next,
                      label: '',
                      color: Colors.grey[700]!,
                      onPressed: provider.next,
                      size: 48,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Controllo Volume Slider
                Row(
                  children: [
                    const Icon(Icons.volume_mute, size: 20, color: Colors.grey),
                    Expanded(
                      child: Slider(
                        value: currentVolume.clamp(0.0, 100.0),
                        min: 0.0,
                        max: 100.0,
                        divisions: 100,
                        label: '${currentVolume.round()}%',
                        onChanged: (value) {
                          setState(() {
                            _isChangingVolume = true;
                            _volumeValue = value;
                            _lastVolumeTime = DateTime.now();
                          });
                          // Aggiornamento immediato al provider per feedback visivo se supportato
                          provider.setVolume(value); 
                        },
                        onChangeEnd: (value) {
                           provider.setVolume(value);
                           setState(() {
                             _isChangingVolume = false;
                             _lastVolumeTime = DateTime.now();
                           });
                        },
                      ),
                    ),
                    const Icon(Icons.volume_up, size: 20, color: Colors.grey),
                  ],
                ),

                const SizedBox(height: 8),
                
                // Fullscreen Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: provider.toggleFullscreen,
                    icon: const Icon(Icons.fullscreen),
                    label: const Text('Fullscreen'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required double size,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(size / 2),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

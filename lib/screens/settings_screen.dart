import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final bool soundEnabled;
  final bool musicEnabled;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onMusicChanged;
  final VoidCallback onBack;
  final VoidCallback? onResetProgress;

  const SettingsScreen({
    super.key,
    required this.soundEnabled,
    required this.musicEnabled,
    required this.onSoundChanged,
    required this.onMusicChanged,
    required this.onBack,
    this.onResetProgress,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  late bool _sound;
  late bool _music;

  @override
  void initState() {
    super.initState();
    _sound = widget.soundEnabled;
    _music = widget.musicEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back, color: _cream),
        ),
        title: const Text('Ayarlar', style: TextStyle(color: _gold)),
      ),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggle(
                icon: Icons.volume_up,
                label: 'Ses Efektleri',
                value: _sound,
                onChanged: (v) {
                  setState(() => _sound = v);
                  widget.onSoundChanged(v);
                },
              ),
              const SizedBox(height: 12),
              _buildToggle(
                icon: Icons.music_note,
                label: 'Muzik',
                value: _music,
                onChanged: (v) {
                  setState(() => _music = v);
                  widget.onMusicChanged(v);
                },
              ),
              const SizedBox(height: 24),
              const Divider(color: _gold, height: 1),
              const SizedBox(height: 24),
              Text(
                'Kale Kronikleri v1.0',
                style: TextStyle(color: _cream.withAlpha(100), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: _cream.withAlpha(40)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: _cream, fontSize: 14)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _gold,
            inactiveTrackColor: Colors.grey[800],
          ),
        ],
      ),
    );
  }
}

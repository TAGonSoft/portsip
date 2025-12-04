import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'call_cubit.dart';
import 'call_state.dart';

class CallPage extends StatelessWidget {
  const CallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CallView();
  }
}

class CallView extends StatelessWidget {
  const CallView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Call'), centerTitle: true),
      body: BlocBuilder<CallCubit, CallState>(
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status Section
                _buildStatusSection(state),

                // Phone Number Input (only when idle)
                if (state.status == CallStatus.idle)
                  _buildPhoneNumberInput(context),

                // Call Info (when in call)
                if (state.status != CallStatus.idle) _buildCallInfo(state),

                // Control Buttons
                _buildControlButtons(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusSection(CallState state) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: _getStatusColor(state.status),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(state.status).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(_getStatusIcon(state.status), color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            _getStatusText(state.status),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (state.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              state.errorMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneNumberInput(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Phone Number / SIP URI',
            hintText: 'e.g., 1001 or sip:user@domain.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          onChanged: (value) {
            context.read<CallCubit>().updatePhoneNumber(value);
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              context.read<CallCubit>().makeAudioCall();
            },
            icon: const Icon(Icons.call, color: Colors.white),
            label: const Text(
              'Call',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallInfo(CallState state) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              state.phoneNumber,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Session ID: ${state.sessionId}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (state.status == CallStatus.connected) ...[
              const SizedBox(height: 8),
              Text(
                _formatDuration(state.duration),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, CallState state) {
    if (state.status == CallStatus.idle) {
      return const SizedBox.shrink();
    }

    // Show retry button when call fails
    if (state.status == CallStatus.failed) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<CallCubit>().resetCall();
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Try Again',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Call control buttons (mute, hold, speaker)
        if (state.status == CallStatus.connected ||
            state.status == CallStatus.holding)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRoundButton(
                  icon: state.isMuted ? Icons.mic_off : Icons.mic,
                  label: state.isMuted ? 'Unmute' : 'Mute',
                  onPressed: () => context.read<CallCubit>().toggleMute(),
                  color: state.isMuted ? Colors.red : Colors.grey[700]!,
                ),
                _buildRoundButton(
                  icon: Icons.dialpad,
                  label: 'Keypad',
                  onPressed: () => _showKeypad(context),
                  color: Colors.grey[700]!,
                ),
                _buildRoundButton(
                  icon: state.isOnHold ? Icons.play_arrow : Icons.pause,
                  label: state.isOnHold ? 'Resume' : 'Hold',
                  onPressed: () => context.read<CallCubit>().toggleHold(),
                  color: state.isOnHold ? Colors.orange : Colors.grey[700]!,
                ),
                _buildRoundButton(
                  icon: state.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                  label: state.isSpeakerOn ? 'Speaker On' : 'Speaker Off',
                  onPressed: () => context.read<CallCubit>().toggleSpeaker(),
                  color: state.isSpeakerOn ? Colors.blue : Colors.grey[700]!,
                ),
              ],
            ),
          ),

        // Hang up button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              context.read<CallCubit>().hangUp();
            },
            icon: const Icon(Icons.call_end, color: Colors.white),
            label: const Text(
              'Hang Up',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Color _getStatusColor(CallStatus status) {
    switch (status) {
      case CallStatus.idle:
        return Colors.grey;
      case CallStatus.calling:
        return Colors.blue;
      case CallStatus.ringing:
        return Colors.orange;
      case CallStatus.connected:
        return Colors.green;
      case CallStatus.holding:
        return Colors.amber;
      case CallStatus.failed:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(CallStatus status) {
    switch (status) {
      case CallStatus.idle:
        return Icons.phone;
      case CallStatus.calling:
        return Icons.phone_forwarded;
      case CallStatus.ringing:
        return Icons.phone_in_talk;
      case CallStatus.connected:
        return Icons.call;
      case CallStatus.holding:
        return Icons.pause_circle;
      case CallStatus.failed:
        return Icons.error;
    }
  }

  String _getStatusText(CallStatus status) {
    switch (status) {
      case CallStatus.idle:
        return 'Ready to Call';
      case CallStatus.calling:
        return 'Connecting...';
      case CallStatus.ringing:
        return 'Calling...';
      case CallStatus.connected:
        return 'Connected';
      case CallStatus.holding:
        return 'On Hold';
      case CallStatus.failed:
        return 'Call Failed';
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showKeypad(BuildContext context) {
    // Capture the cubit BEFORE opening the bottom sheet
    final callCubit = context.read<CallCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Keypad',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  for (var i = 1; i <= 9; i++)
                    _buildKeypadButton(callCubit, i.toString()),
                  _buildKeypadButton(callCubit, '*'),
                  _buildKeypadButton(callCubit, '0'),
                  _buildKeypadButton(callCubit, '#'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(CallCubit callCubit, String label) {
    return Material(
      color: Colors.grey[200],
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          callCubit.sendDtmf(label);
        },
        customBorder: const CircleBorder(),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

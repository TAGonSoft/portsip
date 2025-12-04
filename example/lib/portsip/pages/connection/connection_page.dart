import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:portsip/models/sip_account.dart';
import 'package:portsip_example/portsip/pages/connection/connection_cubit.dart';
import 'package:portsip_example/portsip/pages/connection/connection_state.dart'
    as PortSIPConnectionState;

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _formKey = GlobalKey<FormState>();

  // Form field values
  String _userName = '';
  String _password = '';
  String _sipServer = '';
  String _sipServerPort = '';
  String _stunServer = '';
  String _stunServerPort = '';

  void _handleSubmit(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final account = SipAccount(
        userName: _userName,
        password: _password,
        sipServer: _sipServer,
        sipServerPort: int.tryParse(_sipServerPort) ?? 5060,
        stunServer: _stunServer,
        stunServerPort: int.tryParse(_stunServerPort) ?? 0,
      );

      context.read<ConnectionCubit>().connect(account: account);
    }
  }

  void _handleDisconnect(BuildContext context) {
    context.read<ConnectionCubit>().disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection Manager')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            BlocBuilder<
              ConnectionCubit,
              PortSIPConnectionState.ConnectionState
            >(
              builder: (context, state) {
                return Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // Connection Status Indicator
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: _getStatusColor(state.status),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getStatusIcon(state.status),
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getStatusText(state.status),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        label: 'User Name',
                        enabled: !state.isOnline,
                        initialValue: _userName,
                        onSaved: (value) => _userName = value ?? '',
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Username is required'
                            : null,
                      ),
                      _buildTextField(
                        label: 'Password',
                        enabled: !state.isOnline,
                        obscureText: true,
                        initialValue: _password,
                        onSaved: (value) => _password = value ?? '',
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Password is required'
                            : null,
                      ),
                      _buildTextField(
                        label: 'SIP Server (Leave empty for P2P)',
                        enabled: !state.isOnline,
                        initialValue: _sipServer,
                        onSaved: (value) => _sipServer = value ?? '',
                      ),
                      _buildTextField(
                        label: 'SIP Server Port',
                        enabled: !state.isOnline,
                        hint: '5060',
                        initialValue: _sipServerPort,
                        keyboardType: TextInputType.number,
                        onSaved: (value) => _sipServerPort = value ?? '5060',
                      ),

                      _buildTextField(
                        label: 'STUN Server',
                        enabled: !state.isOnline,
                        initialValue: _stunServer,
                        onSaved: (value) => _stunServer = value ?? '',
                      ),
                      _buildTextField(
                        label: 'STUN Server Port',
                        enabled: !state.isOnline,
                        hint: '3478',
                        keyboardType: TextInputType.number,
                        initialValue: _stunServerPort,
                        onSaved: (value) => _stunServerPort = value ?? '0',
                      ),
                      const SizedBox(height: 12),

                      // Toggle Button
                      ElevatedButton(
                        onPressed: state.isOnline
                            ? () => _handleDisconnect(context)
                            : () => _handleSubmit(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: state.isOnline
                              ? Colors.red
                              : Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          state.isOnline ? 'GO OFFLINE' : 'GO ONLINE',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required bool enabled,
    required FormFieldSetter<String> onSaved,
    String? initialValue,
    String? hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    FormFieldValidator<String>? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        initialValue: initialValue,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onSaved: onSaved,
        validator: validator,
      ),
    );
  }

  Color _getStatusColor(PortSIPConnectionState.ConnectionStatus status) {
    switch (status) {
      case PortSIPConnectionState.ConnectionStatus.disconnected:
        return Colors.grey;
      case PortSIPConnectionState.ConnectionStatus.connecting:
        return Colors.orange;
      case PortSIPConnectionState.ConnectionStatus.connected:
        return Colors.green;
      case PortSIPConnectionState.ConnectionStatus.error:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(PortSIPConnectionState.ConnectionStatus status) {
    switch (status) {
      case PortSIPConnectionState.ConnectionStatus.disconnected:
        return Icons.power_off;
      case PortSIPConnectionState.ConnectionStatus.connecting:
        return Icons.sync;
      case PortSIPConnectionState.ConnectionStatus.connected:
        return Icons.check_circle;
      case PortSIPConnectionState.ConnectionStatus.error:
        return Icons.error;
    }
  }

  String _getStatusText(PortSIPConnectionState.ConnectionStatus status) {
    switch (status) {
      case PortSIPConnectionState.ConnectionStatus.disconnected:
        return 'Disconnected';
      case PortSIPConnectionState.ConnectionStatus.connecting:
        return 'Connecting...';
      case PortSIPConnectionState.ConnectionStatus.connected:
        return 'Connected';
      case PortSIPConnectionState.ConnectionStatus.error:
        return 'Connection Error';
    }
  }
}

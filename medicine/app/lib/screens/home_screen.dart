import 'package:flutter/material.dart';
import '../services/index.dart';
import '../models/index.dart';
import 'add_medicine_screen.dart';
import 'take_medicine_screen.dart';

/// Home screen showing all slots and medicines
class HomeScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const HomeScreen({
    required this.userId,
    required this.userName,
    Key? key,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late FirebaseService _firebaseService;
  late NotificationService _notificationService;
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _notificationService = NotificationService();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _firebaseService.getUser(widget.userId);
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Navigate to add medicine screen
  void _navigateToAddMedicine(String slotName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicineScreen(
          userId: widget.userId,
          slotName: slotName,
          onSuccess: _loadUser,
        ),
      ),
    );
  }

  /// Navigate to take medicine screen
  void _navigateToTakeMedicine(String slotName) {
    if (_user == null) return;
    
    final slot = _user!.slots[slotName];
    if (slot == null || slot.medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No medicines in this slot')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TakeMedicineScreen(
          userId: widget.userId,
          slotName: slotName,
          medicinesInSlot: slot.medicines
              .map((m) => {
                'id': m.id,
                'name': m.name,
                'embeddings': m.embeddings,
              })
              .toList(),
          onResult: (verified) {
            if (verified) {
              _loadUser();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medicine Tracker')),
        body: const Center(child: Text('Failed to load user')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${widget.userName}!'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  userId: widget.userId,
                  onPhoneUpdated: _loadUser,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Slot cards
              ..._buildSlotCards(),
              const SizedBox(height: 24),

              // Medicine history button
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MedicineHistoryScreen(
                      userId: widget.userId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.history),
                label: const Text('View History'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSlotCards() {
    final slots = ['morning', 'afternoon', 'night'];
    return slots.map((slotName) {
      final slot = _user!.slots[slotName];
      return _SlotCard(
        slotName: slotName,
        slot: slot,
        onAddMedicine: () => _navigateToAddMedicine(slotName),
        onTakeMedicine: () => _navigateToTakeMedicine(slotName),
      );
    }).toList();
  }
}

class _SlotCard extends StatelessWidget {
  final String slotName;
  final MedicineSlot? slot;
  final VoidCallback onAddMedicine;
  final VoidCallback onTakeMedicine;

  const _SlotCard({
    required this.slotName,
    required this.slot,
    required this.onAddMedicine,
    required this.onTakeMedicine,
  });

  @override
  Widget build(BuildContext context) {
    final hasSlot = slot != null;
    final medicineCount = slot?.medicines.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  slotName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasSlot)
                  Text(
                    '${slot!.startTime} - ${slot!.endTime}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (medicineCount == 0)
              const Text('No medicines added')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Medicines ($medicineCount):'),
                  const SizedBox(height: 8),
                  ...slot!.medicines
                      .map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('• ${m.name}'),
                      ))
                      .toList(),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: onAddMedicine,
                  child: const Text('Add Medicine'),
                ),
                ElevatedButton(
                  onPressed: medicineCount > 0 ? onTakeMedicine : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Take Medicine'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings screen for parent phone configuration
class SettingsScreen extends StatefulWidget {
  final String userId;
  final VoidCallback onPhoneUpdated;

  const SettingsScreen({
    required this.userId,
    required this.onPhoneUpdated,
    Key? key,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late FirebaseService _firebaseService;
  late TextEditingController _phoneController;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _phoneController = TextEditingController();
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    try {
      final user = await _firebaseService.getUser(widget.userId);
      if (user != null) {
        _phoneController.text = user.parentPhone;
      }
    } catch (e) {
      debugPrint('Error loading phone: $e');
    }
  }

  Future<void> _updatePhone() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone number')),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await _firebaseService.updateUserPhone(
        widget.userId,
        _phoneController.text,
      );
      widget.onPhoneUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone updated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Parent WhatsApp Phone',
                hintText: '+1234567890',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isUpdating ? null : _updatePhone,
              child: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Phone'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Medicine history screen
class MedicineHistoryScreen extends StatefulWidget {
  final String userId;

  const MedicineHistoryScreen({required this.userId, Key? key})
      : super(key: key);

  @override
  State<MedicineHistoryScreen> createState() => _MedicineHistoryScreenState();
}

class _MedicineHistoryScreenState extends State<MedicineHistoryScreen> {
  late FirebaseService _firebaseService;
  List<MedicineLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final logs = await _firebaseService.getMedicineLogs(widget.userId);
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No history'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return ListTile(
                      title: Text(log.slot.toUpperCase()),
                      subtitle: Text(
                        '${log.createdAt.toLocal()}\n${log.taken ? '✅ Taken' : '❌ Missed'}',
                      ),
                      trailing: log.whatsappSent
                          ? const Icon(Icons.done_all, color: Colors.green)
                          : null,
                    );
                  },
                ),
    );
  }
}

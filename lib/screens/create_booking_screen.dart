import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/form_kit.dart';

class CreateBookingScreen extends StatefulWidget {
  const CreateBookingScreen({super.key});

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceName = TextEditingController();
  final _destination = TextEditingController();
  final _supplier = TextEditingController();
  final _reference = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  String _type = 'HotelBooking';
  String _currency = 'INR';
  DateTime _start = DateTime.now().add(const Duration(days: 1));
  DateTime _end = DateTime.now().add(const Duration(days: 2));
  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic>? _customer;
  bool _loadingCustomers = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    for (final controller in [
      _serviceName, _destination, _supplier, _reference, _amount, _notes, _pickup, _dropoff
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final raw = await context.read<AuthProvider>().api.post('/crm/customers/FindAll', data: {});
      final rows = raw is List ? raw : (raw is Map ? raw['items'] ?? raw['data'] : null);
      if (mounted) {
        setState(() => _customers = rows is List
            ? rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : []);
      }
    } finally {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  String _customerLabel(Map<String, dynamic> customer) {
    final name = [
      customer['FirstName'] ?? customer['PersonName'],
      customer['LastName'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
    return name.isNotEmpty ? name : (customer['CompanyName'] ?? customer['Email'] ?? 'Customer').toString();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create booking')),
        bottomNavigationBar: SubmitBar(
          label: 'Create booking',
          icon: Icons.card_travel_rounded,
          saving: _saving,
          onPressed: _save,
          helper: _amount.text.trim().isEmpty
              ? null
              : '$_currency ${_amount.text.trim()}',
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              const FormSection('Booking', icon: Icons.luggage_rounded),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Booking type'),
                items: const {
                  'HotelBooking': 'Hotel',
                  'ActivityBooking': 'Activity',
                  'VisaBooking': 'Visa',
                  'TaxiBooking': 'Transfer',
                  'CruiseBooking': 'Cruise',
                }.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (value) => setState(() => _type = value ?? 'HotelBooking'),
              ),
              const SizedBox(height: 14),
              if (_loadingCustomers)
                const LinearProgressIndicator()
              else
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _customer,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: _customers
                      .map((customer) => DropdownMenuItem(
                            value: customer,
                            child: Text(_customerLabel(customer), overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  validator: (value) => value == null ? 'Select a customer' : null,
                  onChanged: (value) => setState(() => _customer = value),
                ),
              const SizedBox(height: 14),
              _field(_serviceName, _serviceLabel, required: true),
              _field(_destination, 'Destination / country'),
              if (_type == 'TaxiBooking') ...[
                _field(_pickup, 'Pickup location', required: true),
                _field(_dropoff, 'Drop-off location', required: true),
              ],
              _dateTile('Service start', _start, (value) => setState(() => _start = value)),
              if (_type == 'HotelBooking' || _type == 'CruiseBooking')
                _dateTile('Service end', _end, (value) => setState(() => _end = value)),
              const SizedBox(height: 6),
              const FormSection('Supplier', icon: Icons.store_rounded),
              _field(_supplier, 'Supplier'),
              _field(_reference, 'Supplier reference'),
              const SizedBox(height: 6),
              const FormSection('Pricing', icon: Icons.payments_rounded),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _field(
                      _amount,
                      'Total amount',
                      required: true,
                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: const ['INR', 'USD', 'AED', 'EUR', 'GBP']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) => setState(() => _currency = value ?? 'INR'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _field(_notes, 'Internal notes', maxLines: 3),
            ],
          ),
        ),
      );

  String get _serviceLabel => switch (_type) {
        'HotelBooking' => 'Hotel name',
        'ActivityBooking' => 'Activity name',
        'VisaBooking' => 'Visa type',
        'TaxiBooking' => 'Vehicle / transfer name',
        'CruiseBooking' => 'Ship / cruise name',
        _ => 'Service name',
      };

  Widget _field(TextEditingController controller, String label,
          {bool required = false, TextInputType? keyboard, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          validator: required
              ? (value) => (value ?? '').trim().isEmpty ? '$label is required' : null
              : null,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _dateTile(String label, DateTime value, ValueChanged<DateTime> changed) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Card(
          child: ListTile(
            title: Text(label),
            subtitle: Text('${value.day}/${value.month}/${value.year}'),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 1000)),
                initialDate: value,
              );
              if (selected != null) changed(selected);
            },
          ),
        ),
      );

  Map<String, dynamic> _customerData() {
    final customer = _customer!;
    return {
      ...customer,
      'id': (customer['_id'] ?? customer['id'] ?? customer['UniqueId']).toString(),
      'GivenName': customer['GivenName'] ?? customer['FirstName'] ?? customer['PersonName'] ?? '',
      'FamilyName': customer['FamilyName'] ?? customer['LastName'] ?? '',
      'Email': customer['Email'] ?? customer['email'] ?? '',
      'Phone': customer['Phone'] ?? customer['phone'] ?? '',
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final total = double.tryParse(_amount.text.trim()) ?? 0;
    if (total <= 0) return;
    setState(() => _saving = true);
    final pricing = {'TotalPrice': total, 'Currency': _currency};
    final common = {
      'type': _type,
      'bookingType': _type,
      'customerData': _customerData(),
      'DateOfBooking': DateTime.now().toUtc().toIso8601String(),
      'SupplierName': _supplier.text.trim(),
      'SupplierBookingId': _reference.text.trim(),
      'Notes': _notes.text.trim(),
      'Pricing': pricing,
      'currency': _currency,
      'sendEmail': false,
    };
    final typed = switch (_type) {
      'HotelBooking' => {
          'HotelName': _serviceName.text.trim(),
          'HotelAddress': _destination.text.trim().isEmpty ? '-' : _destination.text.trim(),
          'CheckInDate': _start.toUtc().toIso8601String(),
          'CheckOutDate': _end.toUtc().toIso8601String(),
          'NoRooms': 1,
          'NoGuests': 1,
        },
      'ActivityBooking' => {
          'ActivityName': _serviceName.text.trim(),
          'TravelDate': _start.toUtc().toIso8601String(),
          'NoOfAdults': 1,
          'NoOfKids': 0,
        },
      'VisaBooking' => {
          'visaCountry': _destination.text.trim(),
          'visaType': _serviceName.text.trim(),
          'VisaCategory': _serviceName.text.trim(),
        },
      'TaxiBooking' => {
          'TaxiName': _serviceName.text.trim(),
          'TravelDate': _start.toUtc().toIso8601String(),
          'PickupLocation': _pickup.text.trim(),
          'DropOffLocation': _dropoff.text.trim(),
          'NoGuests': 1,
        },
      'CruiseBooking' => {
          'ShipName': _serviceName.text.trim(),
          'CruiseLine': _serviceName.text.trim(),
          'SailingDate': _start.toUtc().toIso8601String(),
          'Duration': _end.difference(_start).inDays,
          'DeparturePort': _destination.text.trim(),
        },
      _ => <String, dynamic>{},
    };
    try {
      await context.read<AuthProvider>().api.post(
        '/bookings/createnew',
        data: {...common, ...typed},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create booking: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

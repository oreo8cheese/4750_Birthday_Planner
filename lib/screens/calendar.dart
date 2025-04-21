import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contact_details_page.dart';

class Calendar extends StatefulWidget {
  const Calendar({super.key});

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _loadBirthdays();
  }

  Future<void> _loadBirthdays() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final contactsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();

      final Map<DateTime, List<Map<String, dynamic>>> events = {};

      for (var doc in contactsSnapshot.docs) {
        final data = doc.data();
        if (data['birthday'] != null) {
          final Timestamp birthdayTimestamp = data['birthday'];
          final DateTime birthday = birthdayTimestamp.toDate();
          
          // Create event date for this year (only using month and day)
          final eventDate = DateTime(
            _focusedDay.year,
            birthday.month,
            birthday.day,
          );

          // Add to events map
          if (!events.containsKey(eventDate)) {
            events[eventDate] = [];
          }
          
          events[eventDate]!.add({
            'name': '${data['firstName']} ${data['lastName']}',
            'contactId': doc.id,
            'originalBirthday': birthday,
          });
        }
      }

      setState(() {
        _events = events;
      });
    } catch (e) {
      print('Error loading birthdays: $e');
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    // Compare only month and day
    final normalizedDay = DateTime(
      _focusedDay.year,
      day.month,
      day.day,
    );
    return _events[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  String _getAge(DateTime birthday) {
    final today = DateTime.now();
    int age = today.year - birthday.year;
    if (today.month < birthday.month || 
        (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return '(Turning ${age + 1})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        backgroundColor: Colors.pink[100],
        title: const Text('Birthday Calendar'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              child: TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2025, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: _onDaySelected,
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                eventLoader: _getEventsForDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.pink[200],
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.pink[400],
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Colors.pink[300],
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonDecoration: BoxDecoration(
                    color: Colors.pink[100],
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  formatButtonTextStyle: TextStyle(color: Colors.pink[900]),
                  titleCentered: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _selectedDay != null
                  ? _buildEventList(_getEventsForDay(_selectedDay!))
                  : const Center(
                      child: Text('Select a day to see birthdays'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList(List<Map<String, dynamic>> events) {
    if (events.isEmpty) {
      return const Center(
        child: Text('No birthdays on this day'),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final originalBirthday = event['originalBirthday'] as DateTime;
        final age = _getAge(originalBirthday);
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.cake, color: Colors.pink),
            title: Text(event['name']),
            subtitle: Text('Birthday $age'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContactDetailsPage(
                    contactId: event['contactId'],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}


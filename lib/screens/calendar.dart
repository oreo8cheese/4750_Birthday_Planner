import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contact_details_page.dart';
import 'package:google_fonts/google_fonts.dart';

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
        
        // Add birthday event
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
            'type': 'birthday',
          });
        }

        // Add additional dates
        if (data['additionalDates'] != null) {
          final additionalDates = List<Map<String, dynamic>>.from(data['additionalDates']);
          for (var dateData in additionalDates) {
            final Timestamp dateTimestamp = dateData['date'];
            final DateTime date = dateTimestamp.toDate();
            
            // Create event date for this year
            final eventDate = DateTime(
              _focusedDay.year,
              date.month,
              date.day,
            );

            // Add to events map
            if (!events.containsKey(eventDate)) {
              events[eventDate] = [];
            }
            
            events[eventDate]!.add({
              'name': '${data['firstName']} ${data['lastName']} - ${dateData['name']}',
              'contactId': doc.id,
              'originalDate': date,
              'type': 'special',
            });
          }
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
    // Normalize the day to only compare month and day
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
        title: Text('Calendar', style: GoogleFonts.vollkorn(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadBirthdays(); // Reload events when month changes
            },
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.pink[300],
                shape: BoxShape.circle,
              ),
            ),
          ),
          if (_selectedDay != null)
            Expanded(
              child: ListView.builder(
                itemCount: _getEventsForDay(_selectedDay!).length,
                itemBuilder: (context, index) {
                  final event = _getEventsForDay(_selectedDay!)[index];
                  final isBirthday = event['type'] == 'birthday';
                  final originalDate = event[isBirthday ? 'originalBirthday' : 'originalDate'];
                  final age = _selectedDay!.year - originalDate.year;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: Icon(
                        isBirthday ? Icons.cake : Icons.calendar_today,
                        color: Colors.pink[300],
                      ),
                      title: Text(
                        event['name'],
                        style: GoogleFonts.vollkorn(fontSize: 18),
                      ),
                      subtitle: isBirthday
                          ? Text(
                              'Turning $age years old',
                              style: GoogleFonts.vollkorn(fontSize: 16),
                            )
                          : null,
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
              ),
            ),
        ],
      ),
    );
  }
}


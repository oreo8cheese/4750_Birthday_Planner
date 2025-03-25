import 'package:flutter/material.dart';
import 'new_contact_form.dart';
import 'contact.dart';
import 'dart:io';
import 'contact_details_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ContactBookPage extends StatefulWidget {
  const ContactBookPage({super.key});

  @override
  State<ContactBookPage> createState() => _ContactBookPageState();
}

class _ContactBookPageState extends State<ContactBookPage> {
  late List<Contact> contacts;
  static const String _storageKey = 'contacts';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList(_storageKey);
    
    if (contactsJson != null) {
      setState(() {
        contacts = contactsJson
            .map((json) => Contact.fromJson(jsonDecode(json)))
            .toList();
      });
    } else {
      // Initialize with sample contacts only if no saved contacts exist
      contacts = [
        Contact(
          firstName: 'John',
          lastName: 'Doe',
          gender: 'male',
          birthday: DateTime(1990, 5, 15),
          relationship: 'Friend',
          likes: ['Pizza', 'Basketball', 'Reading'],
          dislikes: ['Mondays', 'Traffic'],
        ),
        Contact(
          firstName: 'Jane',
          lastName: 'Smith',
          gender: 'female',
          birthday: DateTime(1995, 8, 23),
          relationship: 'Co-worker',
          likes: ['Coffee', 'Hiking', 'Photography'],
          dislikes: ['Spiders', 'Cold Weather'],
        ),
        Contact(
          firstName: 'Alex',
          lastName: 'Johnson',
          gender: 'nonbinary',
          birthday: DateTime(1988, 12, 3),
          relationship: 'Best Friend',
          likes: ['Music', 'Gaming', 'Art'],
          dislikes: ['Early Mornings', 'Loud Noises'],
        ),
      ];
      _saveContacts(); // Save initial contacts
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = contacts
        .map((contact) => jsonEncode(contact.toJson()))
        .toList();
    await prefs.setStringList(_storageKey, contactsJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        backgroundColor: Colors.pink[100],
        title: const Text('Contact Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final Contact? newContact = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewContactForm(),
                ),
              );
              
              if (newContact != null) {
                setState(() {
                  contacts.add(newContact);
                });
                _saveContacts(); // Save when adding new contact
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                radius: 25,
                backgroundImage: contact.imagePath != null
                    ? FileImage(File(contact.imagePath!))
                    : null,
                child: contact.imagePath == null
                    ? Text(
                        '${contact.firstName[0]}${contact.lastName[0]}',
                        style: const TextStyle(fontSize: 20),
                      )
                    : null,
              ),
              title: Text('${contact.firstName} ${contact.lastName}'),
              subtitle: Text(contact.relationship),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContactDetailsPage(contact: contact),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
} 
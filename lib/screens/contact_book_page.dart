import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'new_contact_form.dart';
import 'contact_details_page.dart';

class ContactBookPage extends StatefulWidget {
  const ContactBookPage({super.key});

  @override
  State<ContactBookPage> createState() => _ContactBookPageState();
}

class _ContactBookPageState extends State<ContactBookPage> {
  bool _isSelectionMode = false;
  final Set<String> _selectedContacts = {};

  void _toggleSelection(String contactId) {
    setState(() {
      if (_selectedContacts.contains(contactId)) {
        _selectedContacts.remove(contactId);
      } else {
        _selectedContacts.add(contactId);
      }
    });
  }

  Future<void> _deleteSelectedContacts() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${_selectedContacts.length} contact(s)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final batch = FirebaseFirestore.instance.batch();
      
      for (final contactId in _selectedContacts) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('contacts')
            .doc(contactId);
        batch.delete(docRef);
      }

      await batch.commit();
      setState(() {
        _isSelectionMode = false;
        _selectedContacts.clear();
      });
    }
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
            icon: Icon(_isSelectionMode ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                _selectedContacts.clear();
              });
            },
          ),
          if (_isSelectionMode && _selectedContacts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedContacts,
            ),
        ],
      ),
      floatingActionButton: !_isSelectionMode ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NewContactForm(),
            ),
          );
        },
        backgroundColor: Colors.pink[300],
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('contacts')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No contacts yet'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final contactData = doc.data() as Map<String, dynamic>;
              final firstName = contactData['firstName'] ?? '';
              final lastName = contactData['lastName'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: contactData['photoUrl']?.isNotEmpty == true
                        ? NetworkImage(contactData['photoUrl'])
                        : null,
                    child: (contactData['photoUrl']?.isEmpty ?? true)
                        ? Text(
                            '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                            style: const TextStyle(fontSize: 20),
                          )
                        : null,
                  ),
                  title: Text('$firstName $lastName'),
                  subtitle: contactData['relationship'] != null && contactData['relationship'].toString().isNotEmpty
                      ? Text(contactData['relationship'])
                      : null,
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(doc.id);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ContactDetailsPage(
                            contactId: doc.id,
                          ),
                        ),
                      );
                    }
                  },
                  trailing: _isSelectionMode ? Checkbox(
                    value: _selectedContacts.contains(doc.id),
                    onChanged: (bool? value) {
                      _toggleSelection(doc.id);
                    },
                  ) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
} 
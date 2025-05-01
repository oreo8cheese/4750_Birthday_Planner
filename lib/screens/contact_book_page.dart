import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'new_contact_form.dart';
import 'contact_details_page.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';

class ContactBookPage extends StatefulWidget {
  const ContactBookPage({super.key});

  @override
  State<ContactBookPage> createState() => _ContactBookPageState();
}

class _ContactBookPageState extends State<ContactBookPage> {
  bool _isSelectionMode = false;
  final Set<String> _selectedContacts = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  final Map<String, int> _letterPositions = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLetter(String letter) {
    if (_letterPositions.containsKey(letter)) {
      final position = _letterPositions[letter]!;
      _scrollController.animateTo(
        position * 80.0, // Approximate height of each contact item
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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

                // Filter contacts based on search query
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final contactData = doc.data() as Map<String, dynamic>;
                  final firstName = contactData['firstName']?.toString().toLowerCase() ?? '';
                  final lastName = contactData['lastName']?.toString().toLowerCase() ?? '';
                  final fullName = '$firstName $lastName';
                  return fullName.contains(_searchQuery);
                }).toList();

                // Sort contacts alphabetically by first name, then last name
                filteredDocs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aFirstName = aData['firstName']?.toString().toLowerCase() ?? '';
                  final bFirstName = bData['firstName']?.toString().toLowerCase() ?? '';
                  final aLastName = aData['lastName']?.toString().toLowerCase() ?? '';
                  final bLastName = bData['lastName']?.toString().toLowerCase() ?? '';
                  
                  // First compare by first name
                  final firstNameComparison = aFirstName.compareTo(bFirstName);
                  if (firstNameComparison != 0) {
                    return firstNameComparison;
                  }
                  // If first names are the same, compare by last name
                  return aLastName.compareTo(bLastName);
                });

                // Update letter positions
                _letterPositions.clear();
                for (var i = 0; i < filteredDocs.length; i++) {
                  final doc = filteredDocs[i];
                  final contactData = doc.data() as Map<String, dynamic>;
                  final firstName = contactData['firstName']?.toString().toLowerCase() ?? '';
                  if (firstName.isNotEmpty) {
                    final firstLetter = firstName[0].toUpperCase();
                    if (!_letterPositions.containsKey(firstLetter)) {
                      _letterPositions[firstLetter] = i;
                    }
                  }
                }

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No contacts found'));
                }

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final contactData = doc.data() as Map<String, dynamic>;
                        final firstName = contactData['firstName'] ?? '';
                        final lastName = contactData['lastName'] ?? '';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: contactData['photoPath']?.isNotEmpty == true
                                  ? (() {
                                      final file = File(contactData['photoPath']);
                                      if (!file.existsSync()) {
                                        final alternativePath = contactData['photoPath'].replaceAll('/files/', '/app_flutter/');
                                        final alternativeFile = File(alternativePath);
                                        if (alternativeFile.existsSync()) {
                                          return FileImage(alternativeFile);
                                        }
                                        return null;
                                      }
                                      return FileImage(file);
                                    })()
                                  : null,
                              child: (!File(contactData['photoPath'] ?? '').existsSync())
                                  ? Text(
                                      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                                      style: GoogleFonts.satisfy(fontSize: 20),
                                    )
                                  : null,
                            ),
                            title: Text('$firstName $lastName', style: GoogleFonts.vollkorn(fontSize: 20)),
                            subtitle: contactData['relationship'] != null && contactData['relationship'].toString().isNotEmpty
                                ? Text(contactData['relationship'], style: GoogleFonts.vollkorn(fontSize: 16))
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
                    ),
                    if (_searchQuery.isEmpty) // Only show alphabet bar when not searching
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(26, (index) {
                              final letter = String.fromCharCode(65 + index);
                              final hasContacts = _letterPositions.containsKey(letter);
                              return GestureDetector(
                                onTap: hasContacts ? () => _scrollToLetter(letter) : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    letter,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: hasContacts ? FontWeight.bold : FontWeight.normal,
                                      color: hasContacts ? Colors.pink[700] : Colors.grey,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 
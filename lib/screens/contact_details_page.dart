import 'package:flutter/material.dart';
import 'contact.dart';
import 'dart:io';

class ContactDetailsPage extends StatelessWidget {
  final Contact contact;

  const ContactDetailsPage({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        backgroundColor: Colors.pink[100],
        title: Text('${contact.firstName} ${contact.lastName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundImage: contact.imagePath != null
                    ? FileImage(File(contact.imagePath!))
                    : null,
                child: contact.imagePath == null
                    ? Text(
                        '${contact.firstName[0]}${contact.lastName[0]}',
                        style: const TextStyle(fontSize: 40),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoSection('Personal Information', [
              _buildInfoRow('First Name', contact.firstName),
              _buildInfoRow('Last Name', contact.lastName),
              _buildInfoRow('Gender', contact.gender),
              _buildInfoRow('Birthday', 
                '${contact.birthday.day}/${contact.birthday.month}/${contact.birthday.year}'),
              _buildInfoRow('Relationship', contact.relationship),
            ]),
            const SizedBox(height: 16),
            _buildListSection('Likes', contact.likes),
            const SizedBox(height: 16),
            _buildListSection('Dislikes', contact.dislikes),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8),
                  const SizedBox(width: 8),
                  Text(item),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

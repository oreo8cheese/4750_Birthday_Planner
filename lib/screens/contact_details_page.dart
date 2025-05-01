import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'new_contact_form.dart';
import '../services/openai_service.dart';
import '../config/api_config.dart';
import 'package:google_fonts/google_fonts.dart';

class ContactDetailsPage extends StatelessWidget {
  final String contactId; // Change from Contact to String to store document ID

  const ContactDetailsPage({super.key, required this.contactId});

  Future<String?> _showPriceRangeDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Price Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Under \$25'),
                onTap: () => Navigator.pop(context, 'under \$25'),
              ),
              ListTile(
                title: const Text('\$25 - \$50'),
                onTap: () => Navigator.pop(context, '\$25 - \$50'),
              ),
              ListTile(
                title: const Text('\$50 - \$100'),
                onTap: () => Navigator.pop(context, '\$50 - \$100'),
              ),
              ListTile(
                title: const Text('\$100 - \$200'),
                onTap: () => Navigator.pop(context, '\$100 - \$200'),
              ),
              ListTile(
                title: const Text('Over \$200'),
                onTap: () => Navigator.pop(context, 'over \$200'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addGiftIdea(BuildContext context, String contactId, List<String> currentGiftIdeas) async {
    final TextEditingController controller = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Gift Idea'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter gift idea',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newGiftIdeas = [...currentGiftIdeas, controller.text];
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('contacts')
                    .doc(contactId)
                    .update({'giftIdeas': newGiftIdeas});
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAIGiftIdea(BuildContext context, String contactId, String giftIdea, List<String> currentGiftIdeas) async {
    try {
      final newGiftIdeas = [...currentGiftIdeas, giftIdea];
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('contacts')
          .doc(contactId)
          .update({'giftIdeas': newGiftIdeas});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gift idea saved!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save gift idea: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeGiftIdea(BuildContext context, String contactId, List<String> currentGiftIdeas, int index) async {
    try {
      final newGiftIdeas = List<String>.from(currentGiftIdeas)..removeAt(index);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('contacts')
          .doc(contactId)
          .update({'giftIdeas': newGiftIdeas});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove gift idea: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showGiftSuggestions(BuildContext context, Map<String, dynamic> contactData) async {
    final priceRange = await _showPriceRangeDialog(context);
    if (priceRange == null) return;

    final currentGiftIdeas = List<String>.from(contactData['giftIdeas'] ?? []);
    final savedIdeasNotifier = ValueNotifier<Set<String>>(
      Set.from(currentGiftIdeas),
    );

    Future<void> generateAndShowSuggestions() async {
      try {
        showDialog(
          context: context,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        final openAI = OpenAIService(apiKey: APIConfig.openAIKey);
        final suggestions = await openAI.generateGiftSuggestions(
          firstName: contactData['firstName'],
          likes: List<String>.from(contactData['likes'] ?? []),
          dislikes: List<String>.from(contactData['dislikes'] ?? []),
          relationship: contactData['relationship'],
          gender: contactData['gender'],
          priceRange: priceRange,
        );

        if (!context.mounted) return;
        Navigator.pop(context); // Dismiss loading dialog

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Gift Ideas for ${contactData['firstName']}', style: GoogleFonts.vollkorn(fontSize: 22, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Price Range: $priceRange', style: GoogleFonts.vollkorn(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  ...suggestions.map((suggestion) {
                    final displaySuggestion = '${suggestion.idea} - ${suggestion.explanation} (Around ${suggestion.approximatePrice})';
                    final cleanedIdea = suggestion.cleanIdea;
                    return ValueListenableBuilder(
                      valueListenable: savedIdeasNotifier,
                      builder: (context, Set<String> savedIdeas, _) {
                        final isSaved = savedIdeas.contains(cleanedIdea);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(displaySuggestion, style: GoogleFonts.vollkorn(fontSize: 16)),
                              ),
                              IconButton(
                                icon: Icon(
                                  isSaved ? Icons.check_circle : Icons.add_circle_outline,
                                  color: isSaved ? Colors.green : Colors.blue,
                                ),
                                onPressed: isSaved ? null : () async {
                                  await _saveAIGiftIdea(
                                    context,
                                    contactId,
                                    cleanedIdea,
                                    List<String>.from(savedIdeas),
                                  );
                                  savedIdeasNotifier.value = {...savedIdeas, cleanedIdea};
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  Text(
                    'Click the + button to save a suggestion to your gift ideas list.',
                    style: GoogleFonts.vollkorn(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.vollkorn(fontSize: 16)),
              ),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context); // Close current dialog
                  await generateAndShowSuggestions(); // Show new suggestions
                },
                icon: const Icon(Icons.refresh),
                label: Text('Regenerate', style: GoogleFonts.vollkorn(fontSize: 16)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.pink[700],
                ),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate gift suggestions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Initial generation
    await generateAndShowSuggestions();
  }

  Future<void> _showBirthdayMessage(BuildContext context, Map<String, dynamic> contactData) async {
    final openAI = OpenAIService(apiKey: APIConfig.openAIKey);
    
    try {
      showDialog(
        context: context,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final message = await openAI.generateBirthdayMessage(
        firstName: contactData['firstName'],
        relationship: contactData['relationship'] ?? 'friend',
      );

      Navigator.pop(context); // Dismiss loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Birthday Message for ${contactData['firstName']}'),
          content: SingleChildScrollView(
            child: Text(message, style: GoogleFonts.vollkorn(fontSize: 18)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate birthday message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        title: const Text('Contact Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewContactForm(
                    isEditing: true,
                    contactId: contactId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('contacts')
            .doc(contactId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Contact not found'));
          }

          final contactData = snapshot.data!.data() as Map<String, dynamic>;
          final firstName = contactData['firstName'] ?? '';
          final lastName = contactData['lastName'] ?? '';
          final gender = contactData['gender'] ?? '';
          final relationship = contactData['relationship'] ?? '';
          final likes = List<String>.from(contactData['likes'] ?? []);
          final dislikes = List<String>.from(contactData['dislikes'] ?? []);
          final giftIdeas = List<String>.from(contactData['giftIdeas'] ?? []);
          
          // Convert Timestamp to DateTime
          final Timestamp? birthdayTimestamp = contactData['birthday'];
          final DateTime birthday = birthdayTimestamp?.toDate() ?? DateTime.now();

          return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo container with rounded rectangle shape
                    Container(
                      width: 160,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: contactData['photoPath']?.isNotEmpty == true
                          ? (() {
                              print('Attempting to load photo from: ${contactData['photoPath']}');
                              final file = File(contactData['photoPath']);
                              if (!file.existsSync()) {
                                print('Warning: Image file does not exist at path');
                                return Center(
                                  child: Text(
                                    '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                                    style: GoogleFonts.satisfy(fontSize: 40),
                                  ),
                                );
                              }
                              return Image.file(
                                file,
                                fit: BoxFit.cover,
                              );
                            })()
                          : Center(
                              child: Text(
                                '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                        style: GoogleFonts.satisfy(fontSize: 40),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Personal Information next to photo
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 24),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$firstName $lastName',
                                      style: GoogleFonts.vollkorn(fontSize: 20),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    gender.toLowerCase() == 'female' 
                                        ? Icons.female 
                                        : gender.toLowerCase() == 'male' 
                                            ? Icons.male 
                                            : Icons.transgender,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    gender,
                                    style: GoogleFonts.vollkorn(fontSize: 20),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.cake, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${birthday.month}/${birthday.day}/${birthday.year}',
                                    style: GoogleFonts.vollkorn(fontSize: 20),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.favorite, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    relationship,
                                    style: GoogleFonts.vollkorn(fontSize: 20),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildListSection('Likes', likes),
            const SizedBox(height: 16),
                _buildListSection('Dislikes', dislikes),
            const SizedBox(height: 16),
                _buildGiftIdeasSection(giftIdeas, context),
                const SizedBox(height: 24),
                // Buttons at bottom
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () => _showGiftSuggestions(context, contactData),
                        icon: const Icon(Icons.card_giftcard),
                        label: const Text('Gift Ideas'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink[100],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      flex: 4,
                      child: ElevatedButton.icon(
                        onPressed: () => _showBirthdayMessage(context, contactData),
                        icon: const Icon(Icons.message),
                        label: const Text('Birthday Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink[100],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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
                fontSize: 22,
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
                  Text(item, style: TextStyle(fontSize: 20),),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftIdeasSection(List<String> giftIdeas, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gift Ideas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addGiftIdea(context, contactId, giftIdeas),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...giftIdeas.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entry.value, style: TextStyle(fontSize: 20),),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _removeGiftIdea(
                      context,
                      contactId,
                      giftIdeas,
                      entry.key,
                    ),
                  ),
                ],
              ),
            )),
            if (giftIdeas.isEmpty)
              const Text(
                'No gift ideas yet. Add your own or generate some!',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

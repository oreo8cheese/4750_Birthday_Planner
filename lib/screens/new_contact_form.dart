import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'contact.dart';
import 'package:path_provider/path_provider.dart' show getApplicationSupportDirectory;
import 'package:google_fonts/google_fonts.dart';

// You'll need to create this new widget in a separate file: lib/screens/new_contact_form.dart
class NewContactForm extends StatefulWidget {
  final bool isEditing;
  final String? contactId;

  const NewContactForm({
    super.key, 
    this.isEditing = false, 
    this.contactId,
  });

  @override
  State<NewContactForm> createState() => _NewContactFormState();
}

class _NewContactFormState extends State<NewContactForm> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  DateTime? selectedDate;
  String? existingPhotoUrl;
  
  // Add controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _selectedGender;
  final _relationshipController = TextEditingController();
  List<TextEditingController> likesControllers = [TextEditingController()];
  List<TextEditingController> dislikesControllers = [TextEditingController()];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadContactData();
    }
  }

  Future<void> _loadContactData() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('contacts')
          .doc(widget.contactId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        setState(() {
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _selectedGender = data['gender'];
          _relationshipController.text = data['relationship'] ?? '';
          existingPhotoUrl = data['photoPath'];
          
          // Handle birthday
          if (data['birthday'] != null) {
            selectedDate = (data['birthday'] as Timestamp).toDate();
          }
          
          // Handle likes
          final likes = List<String>.from(data['likes'] ?? []);
          likesControllers = likes.map((like) => TextEditingController(text: like)).toList();
          if (likesControllers.isEmpty) {
            likesControllers.add(TextEditingController());
          }
          
          // Handle dislikes
          final dislikes = List<String>.from(data['dislikes'] ?? []);
          dislikesControllers = dislikes.map((dislike) => TextEditingController(text: dislike)).toList();
          if (dislikesControllers.isEmpty) {
            dislikesControllers.add(TextEditingController());
          }
        });
      }
    } catch (e) {
      print('Error loading contact data: $e');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _relationshipController.dispose();
    for (var controller in likesControllers) {
      controller.dispose();
    }
    for (var controller in dislikesControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitForm() {
    if (_firstNameController.text.isEmpty || 
        _lastNameController.text.isEmpty || 
        _selectedGender == null || 
        selectedDate == null ||
        _relationshipController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final newContact = Contact(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      gender: _selectedGender!,
      birthday: selectedDate!,
      relationship: _relationshipController.text,
      imagePath: _imageFile?.path,
      likes: likesControllers
          .map((controller) => controller.text)
          .where((text) => text.isNotEmpty)
          .toList(),
      dislikes: dislikesControllers
          .map((controller) => controller.text)
          .where((text) => text.isNotEmpty)
          .toList(),
    );

    Navigator.pop(context, newContact);
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile, String contactId) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      print('App directory: ${appDir.path}');
      
      final contactPhotosDir = Directory('${appDir.path}/contact_photos');
      if (!await contactPhotosDir.exists()) {
        await contactPhotosDir.create(recursive: true);
        print('Created contact photos directory');
      }

      final fileName = '${contactId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final localPath = '${contactPhotosDir.path}/$fileName';
      print('Attempting to save image to: $localPath');

      // Copy the image file to our local storage
      final newFile = await imageFile.copy(localPath);
      print('Image copied successfully: ${newFile.existsSync()}');
      
      return localPath;
    } catch (e) {
      print('Failed to save image locally: $e');
      return null;
    }
  }

  Widget buildExpandableSection(String title, List<TextEditingController> controllers) {
    return ExpansionTile(
      title: Text(title),
      children: [
        ...controllers.map((controller) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: '$title Item',
              border: const OutlineInputBorder(),
            ),
          ),
        )),
        IconButton(
          icon: const Icon(Icons.add_circle),
          onPressed: () {
            setState(() {
              controllers.add(TextEditingController());
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Contact' : 'New Contact'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (existingPhotoUrl != null && existingPhotoUrl!.isNotEmpty)
                            ? FileImage(File(existingPhotoUrl!)) as ImageProvider
                            : null,
                    child: (_imageFile == null && (existingPhotoUrl == null || existingPhotoUrl!.isEmpty))
                        ? const Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
              ),
              Text(
                'Add a photo',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'nonbinary', child: Text('Non-binary')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Birthday',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                controller: TextEditingController(
                  text: selectedDate != null 
                      ? "${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}"
                      : "",
                ),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && picked != selectedDate) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              buildExpandableSection('Likes', likesControllers),
              buildExpandableSection('Dislikes', dislikesControllers),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  // Validate required fields
                  if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Missing Information'),
                          content: const Text('Please fill in the required fields:\n\n• First Name\n• Last Name'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('OK'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );
                    return;
                  }

                  try {
                    // Create contact data with required fields
                    final Map<String, dynamic> contactData = {
                      "firstName": _firstNameController.text,
                      "lastName": _lastNameController.text,
                    };

                    // Add optional fields
                    if (_selectedGender != null) {
                      contactData["gender"] = _selectedGender.toString();
                    }
                    if (selectedDate != null) {
                      contactData["birthday"] = Timestamp.fromDate(selectedDate!);
                    }
                    if (_relationshipController.text.isNotEmpty) {
                      contactData["relationship"] = _relationshipController.text;
                    }

                    // Add non-empty likes
                    final likes = likesControllers
                        .map((controller) => controller.text)
                        .where((text) => text.isNotEmpty)
                        .toList();
                    if (likes.isNotEmpty) {
                      contactData["likes"] = likes;
                    }

                    // Add non-empty dislikes
                    final dislikes = dislikesControllers
                        .map((controller) => controller.text)
                        .where((text) => text.isNotEmpty)
                        .toList();
                    if (dislikes.isNotEmpty) {
                      contactData["dislikes"] = dislikes;
                    }

                    // First, save/update the contact to get a valid contactId
                    final contactsCollection = FirebaseFirestore.instance
                        .collection("users")
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection("contacts");

                    String contactId;
                    if (widget.isEditing) {
                      contactId = widget.contactId!;
                      await contactsCollection.doc(contactId).update(contactData);
                    } else {
                      final docRef = await contactsCollection.add(contactData);
                      contactId = docRef.id;
                    }

                    // Now handle image upload with the valid contactId
                    if (_imageFile != null) {
                      final imagePath = await _uploadImage(_imageFile!, contactId);
                      if (imagePath != null) {
                        print('Image saved locally at: $imagePath');
                        // Update the contact with the photo path
                        await contactsCollection.doc(contactId).update({'photoPath': imagePath});
                        print('Photo path saved to Firestore: $imagePath');
                      } else {
                        print('Failed to save image locally');
                      }
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(widget.isEditing 
                          ? '${_firstNameController.text} updated'
                          : '${_firstNameController.text} saved'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    Navigator.pop(context);
                  } catch (error) {
                    print("Failed to ${widget.isEditing ? 'update' : 'add'} contact: $error");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to ${widget.isEditing ? 'update' : 'save'} contact: ${error.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink[100],
                  minimumSize: const Size(200, 50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16
                  ),
                ),
                child: Text(
                  widget.isEditing ? 'Update Contact' : 'Save Contact',
                  style: const TextStyle(
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
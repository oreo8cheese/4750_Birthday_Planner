import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'contact.dart';

// You'll need to create this new widget in a separate file: lib/screens/new_contact_form.dart
class NewContactForm extends StatefulWidget {
  const NewContactForm({super.key});

  @override
  State<NewContactForm> createState() => _NewContactFormState();
}

class _NewContactFormState extends State<NewContactForm> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  DateTime? selectedDate;
  
  // Add controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _selectedGender;
  final _relationshipController = TextEditingController();
  List<TextEditingController> likesControllers = [TextEditingController()];
  List<TextEditingController> dislikesControllers = [TextEditingController()];

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
        backgroundColor: Colors.pink[100],
        title: const Text('New Contact'),
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
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.file(
                              _imageFile!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Colors.grey,
                          ),
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
                      ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
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
                onPressed: _submitForm,
                child: const Text('Save Contact'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
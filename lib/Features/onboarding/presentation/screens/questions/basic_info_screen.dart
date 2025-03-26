import 'package:flutter/material.dart';

class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({super.key});

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  int? age;
  String? gender;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Progress bar
              const LinearProgressIndicator(
                value: 0.2,
                backgroundColor: Colors.grey,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
              const SizedBox(height: 40),
              // Title
              const Text(
                "Let's get to know you",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  fontFamily: '.SF Pro Display',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "To create your perfect plan",
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.grey,
                  fontFamily: '.SF Pro Display',
                ),
              ),
              const SizedBox(height: 40),
              // Age input
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextFormField(
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: 'Your age',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      age = int.tryParse(value);
                    });
                  },
                ),
              ),
              const Spacer(),
              // Continue button
              Container(
                width: double.infinity,
                height: 56,
                margin: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton(
                  onPressed: age != null
                      ? () {
                          // Navigate to next question
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      fontFamily: '.SF Pro Display',
                    ),
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

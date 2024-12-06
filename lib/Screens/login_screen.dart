
import 'package:chat_app/Screens/home_screen.dart';
import 'package:chat_app/Screens/userDetails_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'dart:async';

import '../constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  bool _isLoading = false;
  bool _otpVisible = false;
  bool _isOtpLoading = false;
  Timer? _loadingTimer;
  Timer? _otpLoadingTimer;
  String _completePhoneNumber = '';
  bool _isValidPhoneNumber = false;

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _otpLoadingTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(
      {String message = 'Something went wrong! Try again later'}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          backgroundColor: Red,
        ),
      );
    }
  }

  bool _validateIndianPhoneNumber(String phoneNumber) {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    RegExp indianPhoneRegex = RegExp(r'^[6-9]\d{9}$');
    return indianPhoneRegex.hasMatch(cleanNumber);
  }

  Future<void> _sendOTP() async {
    if (!_isValidPhoneNumber) {
      _showErrorSnackBar(message: 'Please enter a valid phone number');
      return;
    }

    setState(() => _isLoading = true);

    _loadingTimer = Timer(const Duration(seconds: 60), () {
      if (_isLoading) {
        setState(() => _isLoading = false);
        _showErrorSnackBar();
      }
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        verificationCompleted: (PhoneAuthCredential credential) {
          _loadingTimer?.cancel();
          setState(() => _isLoading = false);
        },
        verificationFailed: (FirebaseException ex) {
          _loadingTimer?.cancel();
          setState(() => _isLoading = false);
          _showErrorSnackBar(message: ex.message ?? 'Verification failed');
        },
        codeSent: (String verificationid, int? resendtoken) {
          _loadingTimer?.cancel();
          _verificationId = verificationid;
          setState(() {
            _isLoading = false;
            _otpVisible = true;
          });
        },
        codeAutoRetrievalTimeout: (String verificationid) {
          _loadingTimer?.cancel();
          setState(() => _isLoading = false);
        },
        phoneNumber: _completePhoneNumber,
      );
    } catch (e) {
      _loadingTimer?.cancel();
      setState(() => _isLoading = false);
      _showErrorSnackBar();
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) {
      _showErrorSnackBar(message: 'Please enter a valid 6-digit OTP');
      return;
    }

    setState(() => _isOtpLoading = true);

    _otpLoadingTimer = Timer(const Duration(seconds: 60), () {
      if (_isOtpLoading) {
        setState(() => _isOtpLoading = false);
        _showErrorSnackBar();
      }
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      await FirebaseAuth.instance
          .signInWithCredential(credential)
          .then((value) {
        _otpLoadingTimer?.cancel();
        if (_auth.currentUser != null) {
          _navigateBasedOnUserExistence();
        } else {
          if (kDebugMode) {
            print("_auth.currentUser is null");
          }
          _showErrorSnackBar();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error during OTP verification: $e");
      }
      _otpLoadingTimer?.cancel();
      setState(() => _isOtpLoading = false);
      _showErrorSnackBar(message: 'Invalid OTP. Please try again.');
    }
  }

  Future<void> _navigateBasedOnUserExistence() async {
    final user = _auth.currentUser;

    if (user != null) {
      try {
        // Check if the user document exists in Firestore
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (docSnapshot.exists) {
          // Assuming the user has data, navigate to HomeScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          // New user, navigate to UserDetailsPage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserDetailsPage()),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error checking user existence: $e");
        }
        _showErrorSnackBar();
      }
    } else {
      // If no user is authenticated
      if (kDebugMode) {
        print("Error: No authenticated user found.");
      }
      _showErrorSnackBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              SecondaryBlue,
             PrimaryBlue
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background logo watermark
              // Positioned.fill(
              //   child: Opacity(
              //     opacity: 0.2, // Set opacity to 20%
              //     child: Align(
              //       alignment: Alignment.center,
              //       child: Image.asset(
              //         'assets/logo.png', // Path to your logo image
              //         height: 200, // Adjust the size of the logo
              //         width: 200, // Adjust the size of the logo
              //         fit: BoxFit.contain, // Make sure the logo scales properly
              //       ),
              //     ),
              //   ),
              // ),
              Column(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(
                            'WingChat',
                            style: TextStyle(
                              color: White,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Where Privacy Meets Modern Chat',
                            style: TextStyle(
                              color: White.withOpacity(0.9),
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: _otpVisible ? 2 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 30),
                      decoration:  BoxDecoration(
                        color: White,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: IntlPhoneField(
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  labelStyle:
                                      TextStyle(color:SecondaryBlue),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: PrimaryBlue),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: ShadowBlue),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: PrimaryBlue),
                                  ),
                                ),
                                initialCountryCode: 'IN',
                                dropdownIconPosition: IconPosition.trailing,
                                onChanged: (phone) {
                                  setState(() {
                                    _completePhoneNumber = phone.completeNumber;
                                    if (phone.countryCode == '+91') {
                                      _isValidPhoneNumber =
                                          _validateIndianPhoneNumber(
                                              phone.number);
                                    } else {
                                      _isValidPhoneNumber =
                                          phone.isValidNumber();
                                    }
                                  });
                                },
                                validator: (phone) {
                                  if (phone?.countryCode == '+91') {
                                    if (!_validateIndianPhoneNumber(
                                        phone?.number ?? '')) {
                                      return 'Please enter a valid Indian phone number';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_otpVisible)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: TextField(
                                  controller: _otpController,
                                  decoration: InputDecoration(
                                    labelText: 'Enter OTP',
                                    labelStyle:
                                        TextStyle(color: PrimaryBlue),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                          color: PrimaryBlue),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                          color: ShadowBlue),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                          color: PrimaryBlue),
                                    ),
                                    suffixIcon: Icon(Icons.message,
                                        color: PrimaryBlue),
                                  ),
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                ),
                              ),
                            _isLoading || _isOtpLoading
                                ? CircularProgressIndicator(
                                    color:PrimaryBlue)
                                : ElevatedButton(
                                    onPressed:
                                        _otpVisible ? _verifyOTP : _sendOTP,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: PrimaryBlue,
                                      minimumSize:
                                          const Size(double.infinity, 55),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: Text(
                                      _otpVisible ? 'Verify OTP' : 'Get OTP',
                                      style:  TextStyle(
                                        color: White,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../functions/authentication.dart';
import 'signup_with_email.dart';
import 'splash.dart';

class LoginWithEmail extends StatefulWidget {
  const LoginWithEmail({super.key});

  @override
  _LoginWithEmailState createState() => _LoginWithEmailState();
}

class _LoginWithEmailState extends State<LoginWithEmail>
    with SingleTickerProviderStateMixin {
  String? password, email;
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  final _emailFieldKey = GlobalKey<FormFieldState>();
  bool isPwdHidden = true, isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formkey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          // Back
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: lineColor),
                                boxShadow: [shadowSm],
                              ),
                              child: Icon(Icons.arrow_back_rounded,
                                  color: inkColor, size: 20),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Title
                          Text(
                            utils.getTranslated(context, "signIn"),
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 28,
                                color: inkColor),
                          ),
                          const SizedBox(height: 6),
                          Text('Welcome back to Chilling Zone',
                              style: TextStyle(
                                  fontSize: 14, color: ink2Color)),
                          const SizedBox(height: 32),

                          // Email
                          _AuthField(
                            label: utils.getTranslated(context, "email"),
                            icon: Icons.email_outlined,
                            fieldKey: _emailFieldKey,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) => utils.validateEmail(
                                val!,
                                utils.getTranslated(
                                    context, "emailRequired"),
                                utils.getTranslated(
                                    context, "enterValidEmail")),
                            onSaved: (v) => email = v,
                          ),
                          const SizedBox(height: 14),

                          // Password
                          _AuthField(
                            label: utils.getTranslated(context, "password"),
                            icon: Icons.lock_outlined,
                            isPassword: true,
                            isPwdHidden: isPwdHidden,
                            onTogglePwd: () =>
                                setState(() => isPwdHidden = !isPwdHidden),
                            validator: (val) => utils.validatePass(
                                val!,
                                utils.getTranslated(
                                    context, "passwordRequired"),
                                utils.getTranslated(
                                    context, "passwordShouldHaveSixChar")),
                            onSaved: (v) => password = v,
                          ),
                          const SizedBox(height: 10),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () async {
                                final emailField =
                                    _emailFieldKey.currentState!;
                                emailField.save();
                                if (emailField.validate()) {
                                  await Auth.sendForgotPasswordLink(
                                          email!.trim())
                                      .then((v) {
                                    utils.setSnackbar(
                                        context,
                                        v == null
                                            ? utils.getTranslated(context,
                                                "resetPasswordEmailSent")
                                            : v.toString());
                                  });
                                  return;
                                }
                                utils.setSnackbar(context,
                                    utils.getTranslated(context, "enterEmail"));
                              },
                              child: Text(
                                utils.getTranslated(
                                    context, "forgotPassword"),
                                style: TextStyle(
                                    color: xColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Sign in button
                          _PrimaryBtn(
                            label: utils.getTranslated(context, "signIn"),
                            onTap: () {
                              setState(() => isLoading = true);
                              _validateAndSubmit();
                            },
                          ),
                          const SizedBox(height: 20),

                          // Divider
                          Row(children: [
                            Expanded(child: Divider(color: lineColor)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              child: Text(
                                utils.getTranslated(context, "or"),
                                style: TextStyle(
                                    color: ink3Color, fontSize: 13),
                              ),
                            ),
                            Expanded(child: Divider(color: lineColor)),
                          ]),
                          const SizedBox(height: 16),

                          // Social buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (Platform.isIOS) ...[
                                _SocialBtn(
                                  child: getSvgImage(
                                      imageName: 'apple_icon',
                                      width: 22,
                                      height: 22,
                                      imageColor: inkColor),
                                  onTap: () =>
                                      Auth.signin(context, false, "IOS"),
                                ),
                                const SizedBox(width: 12),
                              ],
                              _SocialBtn(
                                child: getSvgImage(
                                    imageName: "google_logo",
                                    width: 22,
                                    height: 22),
                                onTap: () => Auth.signin(context, false,
                                    "Android",
                                    email: "", password: ""),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Register link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(utils.getTranslated(context, "newAccount"),
                                  style: TextStyle(
                                      color: ink2Color, fontSize: 14)),
                              GestureDetector(
                                onTap: () => Navigator.pushReplacement(
                                  context,
                                  CupertinoPageRoute(
                                      builder: (_) => SignInWithEmail()),
                                ),
                                child: Text(
                                  ' ${utils.getTranslated(context, "register")}',
                                  style: TextStyle(
                                      color: xColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.6),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: xColor, strokeWidth: 2.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _validateAndSubmit() async {
    if (_validateAndSave()) {
      await Auth.signin(context, false, "android",
          email: email, password: password, username: "");
    }
    if (mounted) setState(() => isLoading = false);
  }

  bool _validateAndSave() {
    final form = _formkey.currentState!;
    form.save();
    return form.validate();
  }
}

// ── Shared auth widgets ────────────────────────────────────────────────────────

class _AuthField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPassword;
  final bool isPwdHidden;
  final VoidCallback? onTogglePwd;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final TextInputType keyboardType;
  final GlobalKey<FormFieldState>? fieldKey;

  const _AuthField({
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.isPwdHidden = true,
    this.onTogglePwd,
    this.validator,
    this.onSaved,
    this.keyboardType = TextInputType.text,
    this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lineColor),
        boxShadow: [shadowSm],
      ),
      child: TextFormField(
        key: fieldKey,
        obscureText: isPassword && isPwdHidden,
        obscuringCharacter: '*',
        keyboardType: keyboardType,
        style: TextStyle(color: inkColor, fontWeight: FontWeight.w500),
        textInputAction: TextInputAction.next,
        validator: validator,
        onSaved: onSaved,
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Icon(icon, color: ink3Color, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 46),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPwdHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: ink3Color,
                  ),
                  onPressed: onTogglePwd,
                )
              : null,
          hintText: label,
          hintStyle: TextStyle(color: ink3Color, fontWeight: FontWeight.w400),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: xColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: xColor.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _SocialBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: lineColor),
          boxShadow: [shadowSm],
        ),
        child: Center(child: child),
      ),
    );
  }
}

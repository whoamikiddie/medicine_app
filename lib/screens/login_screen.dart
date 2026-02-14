import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'auth_wrapper.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  // Animation controllers
  late AnimationController _bgAnimController;
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _shimmerController;

  // Animations
  late Animation<double> _bgAnim;
  late Animation<double> _iconScale;
  late Animation<double> _iconGlow;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _emailFade;
  late Animation<double> _passFade;
  late Animation<double> _btnFade;
  late Animation<Offset> _btnSlide;
  late Animation<double> _featureFade;

  // Floating particles
  late List<_Particle> _particles;
  final math.Random _rand = math.Random();

  @override
  void initState() {
    super.initState();

    // Generate floating particles
    _particles = List.generate(20, (_) => _Particle(_rand));

    // Animated gradient background
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _bgAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(_bgAnimController);

    // Pulse animation for icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _iconGlow = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Particle animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Shimmer animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Staggered entrance animations
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.25, curve: Curves.elasticOut),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.12, 0.35, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.12, 0.35, curve: Curves.easeOut),
    ));

    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.28, 0.5, curve: Curves.easeOut),
      ),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.28, 0.5, curve: Curves.easeOut),
    ));

    _emailFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.42, 0.6, curve: Curves.easeOut),
      ),
    );

    _passFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.52, 0.7, curve: Curves.easeOut),
      ),
    );

    _btnFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.65, 0.85, curve: Curves.easeOut),
      ),
    );
    _btnSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.65, 0.85, curve: Curves.easeOut),
    ));

    _featureFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await context.read<UserProvider>().signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgAnimController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnim,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF050A18),
                  Color.lerp(
                    const Color(0xFF0D1B2A),
                    const Color(0xFF0A1628),
                    (math.sin(_bgAnim.value) + 1) / 2,
                  )!,
                  Color.lerp(
                    const Color(0xFF12203A),
                    const Color(0xFF0B1120),
                    (math.cos(_bgAnim.value * 0.7) + 1) / 2,
                  )!,
                  const Color(0xFF060D1F),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [
                  0.0,
                  0.35 + 0.1 * math.sin(_bgAnim.value),
                  0.7 + 0.1 * math.cos(_bgAnim.value),
                  1.0,
                ],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            // Animated mesh gradient blobs
            ..._buildMeshGradients(),

            // Floating particles
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) => CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleController.value,
                ),
                size: Size.infinite,
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: screenHeight * 0.02),

                      // ─── Animated Logo ───────────────
                      AnimatedBuilder(
                        animation: Listenable.merge([_iconScale, _iconGlow]),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _iconScale.value,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0066FF),
                                    Color(0xFF00D4FF),
                                    Color(0xFF7C3AED),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00D4FF).withValues(alpha: _iconGlow.value * 0.5),
                                    blurRadius: 40,
                                    spreadRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withValues(alpha: _iconGlow.value * 0.3),
                                    blurRadius: 60,
                                    spreadRadius: 15,
                                    offset: const Offset(10, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Inner subtle pattern
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(28),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.15),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.white,
                                    size: 44,
                                  ),
                                  Positioned(
                                    top: 28,
                                    child: Icon(
                                      Icons.add_rounded,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // ─── Title ────────────────────────
                      FadeTransition(
                        opacity: _titleFade,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: Column(
                            children: [
                              // Shimmer text effect
                              AnimatedBuilder(
                                animation: _shimmerController,
                                builder: (context, _) {
                                  return ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: const [
                                        Colors.white,
                                        Color(0xFF00D4FF),
                                        Color(0xFF7C3AED),
                                        Colors.white,
                                      ],
                                      stops: [
                                        0.0,
                                        _shimmerController.value,
                                        _shimmerController.value + 0.2,
                                        1.0,
                                      ].map((s) => s.clamp(0.0, 1.0)).toList(),
                                    ).createShader(bounds),
                                    child: const Text(
                                      "MediTrack",
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF00D4FF).withValues(alpha: 0.15),
                                      const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF00D4FF).withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, color: Color(0xFF00D4FF), size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      "AI-Powered Health Companion",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8892B0),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ─── Glassmorphism Login Card ─────
                      FadeTransition(
                        opacity: _cardFade,
                        child: SlideTransition(
                          position: _cardSlide,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.1),
                                      Colors.white.withValues(alpha: 0.04),
                                      const Color(0xFF7C3AED).withValues(alpha: 0.03),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF0066FF), Color(0xFF00D4FF)],
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.login_rounded, color: Colors.white, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          const Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Welcome Back",
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                "Sign in to continue",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF8892B0),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 28),

                                      // Email field
                                      FadeTransition(
                                        opacity: _emailFade,
                                        child: _buildGlassField(
                                          controller: _emailController,
                                          label: "Email Address",
                                          hint: "you@example.com",
                                          icon: Icons.email_outlined,
                                          type: TextInputType.emailAddress,
                                          validator: (v) {
                                            if (v == null || v.isEmpty || !v.contains('@')) {
                                              return "Enter a valid email";
                                            }
                                            return null;
                                          },
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      // Password field
                                      FadeTransition(
                                        opacity: _passFade,
                                        child: _buildGlassField(
                                          controller: _passwordController,
                                          label: "Password",
                                          hint: "••••••••",
                                          icon: Icons.lock_outline_rounded,
                                          obscure: _obscurePassword,
                                          suffix: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded,
                                              color: const Color(0xFF8892B0),
                                              size: 20,
                                            ),
                                            onPressed: () => setState(
                                                () => _obscurePassword = !_obscurePassword),
                                          ),
                                          validator: (v) {
                                            if (v == null || v.length < 4) {
                                              return "Minimum 4 characters";
                                            }
                                            return null;
                                          },
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const ForgotPasswordScreen()),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(0xFF00D4FF),
                                            padding: EdgeInsets.zero,
                                          ),
                                          child: const Text("Forgot Password?",
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        ),
                                      ),

                                      // Error message
                                      if (_error != null) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF1744).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(0xFFFF1744).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error_outline,
                                                  color: Color(0xFFFF1744), size: 18),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _error!,
                                                  style: const TextStyle(
                                                    color: Color(0xFFFF1744),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],

                                      const SizedBox(height: 8),

                                      // Sign In button
                                      FadeTransition(
                                        opacity: _btnFade,
                                        child: SlideTransition(
                                          position: _btnSlide,
                                          child: _buildSignInButton(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Register Link
                      FadeTransition(
                        opacity: _btnFade,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: Color(0xFF8892B0),
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RegisterScreen()),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF00D4FF),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ─── Feature Highlights ──────────
                      FadeTransition(
                        opacity: _featureFade,
                        child: _buildFeatureHighlights(),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'v2.0',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF8892B0).withValues(alpha: 0.4),
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sign In Button ─────────────────────────────────────────
  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0066FF), Color(0xFF00D4FF), Color(0xFF7C3AED)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0066FF).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_forward_rounded, size: 22),
                    SizedBox(width: 10),
                    Text(
                      "SIGN IN",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── Glass Input Field ──────────────────────────────────────
  Widget _buildGlassField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? type,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8892B0),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: type,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF00D4FF), size: 18),
            ),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: const Color(0xFFFF1744).withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Feature Highlights ─────────────────────────────────────
  Widget _buildFeatureHighlights() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _featureItem(Icons.notifications_active_rounded, "Smart\nReminders", const Color(0xFF00D4FF)),
          _featureItem(Icons.psychology_rounded, "AI Health\nAssistant", const Color(0xFF7C3AED)),
          _featureItem(Icons.analytics_rounded, "Track\nAdherence", const Color(0xFF00E676)),
        ],
      ),
    );
  }

  Widget _featureItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // ─── Mesh Gradient Blobs ────────────────────────────────────
  List<Widget> _buildMeshGradients() {
    return [
      // Top-right cyan blob
      AnimatedBuilder(
        animation: _bgAnim,
        builder: (context, _) => Positioned(
          top: -80 + 30 * math.sin(_bgAnim.value * 0.6),
          right: -60 + 20 * math.cos(_bgAnim.value * 0.4),
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00D4FF).withValues(alpha: 0.12),
                  const Color(0xFF00D4FF).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      // Bottom-left purple blob
      AnimatedBuilder(
        animation: _bgAnim,
        builder: (context, _) => Positioned(
          bottom: -100 + 25 * math.cos(_bgAnim.value * 0.5),
          left: -70 + 30 * math.sin(_bgAnim.value * 0.7),
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  const Color(0xFF7C3AED).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      // Mid-right blue blob
      AnimatedBuilder(
        animation: _bgAnim,
        builder: (context, _) => Positioned(
          top: MediaQuery.of(context).size.height * 0.35 +
              15 * math.sin(_bgAnim.value * 0.9),
          right: -50 + 10 * math.cos(_bgAnim.value * 1.1),
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0066FF).withValues(alpha: 0.08),
                  const Color(0xFF0066FF).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      // Small pink accent
      AnimatedBuilder(
        animation: _bgAnim,
        builder: (context, _) => Positioned(
          top: MediaQuery.of(context).size.height * 0.15 +
              8 * math.cos(_bgAnim.value * 1.3),
          left: 40 + 12 * math.sin(_bgAnim.value),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE040FB).withValues(alpha: 0.12),
                  const Color(0xFFE040FB).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

// ─── Particle Model ───────────────────────────────────────────
class _Particle {
  late double x, y, size, speed, opacity;

  _Particle(math.Random rand) {
    x = rand.nextDouble();
    y = rand.nextDouble();
    size = rand.nextDouble() * 3 + 1;
    speed = rand.nextDouble() * 0.3 + 0.1;
    opacity = rand.nextDouble() * 0.4 + 0.1;
  }
}

// ─── Particle Painter ─────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final yPos = (p.y + progress * p.speed) % 1.0;
      final xPos = p.x + math.sin(progress * 2 * math.pi + p.y * 10) * 0.02;

      final paint = Paint()
        ..color = const Color(0xFF00D4FF).withValues(alpha: p.opacity * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(
        Offset(xPos * size.width, yPos * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}


import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() {
  runApp(const LawsYemenApp());
}

class LawsYemenApp extends StatelessWidget {
  const LawsYemenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'القوانين اليمنية',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Arial',
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Future<void> checkActivation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool activated = prefs.getBool('activated') ?? false;
    int startTimestamp = prefs.getInt('trial_start') ?? 0;
    int currentTime = DateTime.now().millisecondsSinceEpoch;

    if (!activated && startTimestamp == 0) {
      prefs.setInt('trial_start', currentTime);
      startTimestamp = currentTime;
    }

    bool trialExpired = (currentTime - startTimestamp) > (3 * 24 * 60 * 60 * 1000);

    if (activated || !trialExpired) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ActivationPage()));
    }
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), checkActivation);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final TextEditingController codeController = TextEditingController();
  final String validCode = '123456';

  void activate() async {
    if (codeController.text.trim() == validCode) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('activated', true);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمز التفعيل غير صحيح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التفعيل')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'ادخل كود التفعيل',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: activate,
              child: const Text('تفعيل'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Database db;
  List<Map<String, dynamic>> laws = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initDatabase();
  }

  Future<void> initDatabase() async {
    final path = join(await getDatabasesPath(), 'laws.db');
    db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE laws (
            id INTEGER PRIMARY KEY,
            name TEXT,
            content TEXT
          )
        ''');
        await db.insert('laws', {'name': 'قانون العمل', 'content': 'يجب على صاحب العمل توفير بيئة صحية للعاملين.'});
        await db.insert('laws', {'name': 'قانون المرور', 'content': 'يمنع الوقوف في الأماكن غير المخصصة.'});
      },
    );
    fetchLaws();
  }

  void fetchLaws([String query = '']) async {
    final result = await db.query(
      'laws',
      where: 'content LIKE ? OR name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    setState(() {
      laws = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('القوانين اليمنية')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'ابحث عن قانون...',
                border: OutlineInputBorder(),
              ),
              onChanged: fetchLaws,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: laws.length,
                itemBuilder: (context, index) {
                  final law = laws[index];
                  return Card(
                    child: ListTile(
                      title: Text(law['name'], textDirection: TextDirection.rtl),
                      subtitle: highlightText(law['content'], searchController.text),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget highlightText(String text, String query) {
    if (query.isEmpty) return Text(text, textDirection: TextDirection.rtl);

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int start = 0;
    int index = lowerText.indexOf(lowerQuery);
    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(backgroundColor: Colors.yellow, color: Colors.black),
      ));
      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return RichText(text: TextSpan(style: const TextStyle(color: Colors.black), children: spans));
  }
}

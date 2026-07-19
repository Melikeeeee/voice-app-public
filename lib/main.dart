import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:background_sms/background_sms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'llm_service.dart';

void main() {
  runApp(const VoiceApp());
}

class VoiceApp extends StatelessWidget {
  const VoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VoiceScreen(),
    );
  }
}

enum AppState {
  idle,
  listening,
  speaking,
}

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  AppState _currentState = AppState.idle;

  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  final LlmService _llmService = LlmService();
  
  bool _isSpeechInitialized = false;
  String _lastRecognizedText = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
    _initSpeech();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("tr-TR");
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.awaitSpeakCompletion(true);
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _currentState = AppState.idle;
        });
      }
    });
  }

  Future<void> _initSpeech() async {
    _isSpeechInitialized = await _speech.initialize(
      onError: (error) {
        debugPrint('SpeechError: ${error.errorMsg}');
        _stopListeningAndSpeak();
      },
      onStatus: (status) {
        debugPrint('SpeechStatus: $status');
        if (status == 'done' || status == 'notListening') {
          if (_currentState == AppState.listening) {
             _stopListeningAndSpeak();
          }
        }
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _stopListeningAndSpeak() async {
    if (_currentState == AppState.listening) {
       setState(() {
         _currentState = AppState.speaking;
       });
       await _speech.stop();

       if (_lastRecognizedText.trim().isEmpty) {
         await _flutterTts.speak("Seni duyamadım anneanneciğim, tekrar dener misin?");
         return;
       }

       // Sesi LLM API'sine gönder
       final responseMap = await _llmService.processSpeech(_lastRecognizedText);
       
       if (responseMap != null) {
         final type = responseMap['type'];
         if (type == 'sohbet') {
           final mesaj = responseMap['mesaj'] ?? 'Seni pek anlayamadım canım anneannem.';
           await _flutterTts.speak(mesaj);
         } else if (type == 'whatsapp') {
           final kisiInfo = responseMap['kisi']?.toString().toLowerCase() ?? '';
           final mesajText = responseMap['mesaj']?.toString() ?? '';
           
           if (kisiInfo.isEmpty) {
              await _flutterTts.speak("Kime mesaj atmak istediğini anlayamadım anneanneciğim.");
           } else {
             if (await Permission.contacts.request().isGranted) {
               final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
               String? targetNumber;

               // 1. Önce tam isim eşleşmesi ara
               for (var contact in contacts) {
                 final displayName = (contact.displayName ?? '').toLowerCase().trim();
                 if (displayName == kisiInfo.trim() && contact.phones.isNotEmpty) {
                   targetNumber = contact.phones.first.normalizedNumber;
                   if (targetNumber == null || targetNumber.isEmpty) targetNumber = contact.phones.first.number;
                   break;
                 }
               }
               // 2. Tam eşleşme yoksa başlangıç eşleşmesi ara
               if (targetNumber == null) {
                 for (var contact in contacts) {
                   final displayName = (contact.displayName ?? '').toLowerCase().trim();
                   if (displayName.isNotEmpty && displayName.startsWith(kisiInfo.trim()) && contact.phones.isNotEmpty) {
                     targetNumber = contact.phones.first.normalizedNumber;
                     if (targetNumber == null || targetNumber.isEmpty) targetNumber = contact.phones.first.number;
                     break;
                   }
                 }
               }

               if (targetNumber != null && targetNumber.isNotEmpty) {
                 // Sadece rakamları al
                 targetNumber = targetNumber.replaceAll(RegExp(r'[^\d]'), '');
                 // Eğer 0 ile başlıyorsa (0530...) 90 ekle
                 if (targetNumber.startsWith('0')) {
                   targetNumber = '90' + targetNumber.substring(1);
                 } else if (targetNumber.length == 10) {
                   // Eğer direkt 530... diye başlıyorsa
                   targetNumber = '90' + targetNumber;
                 }
                 
                 await _flutterTts.speak("Mesajını hazırladım canım anneannem.");
                 
                 final Uri whatsappUri = Uri.parse("whatsapp://send?phone=$targetNumber&text=${Uri.encodeComponent(mesajText)}");
                 final Uri fallbackUri = Uri.parse("https://wa.me/$targetNumber?text=${Uri.encodeComponent(mesajText)}");
                 
                 try {
                   // Önce uygulamanın kendisini açmayı dene
                   bool launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                   if (!launched) {
                     // Uygulama açılamadıysa tarayıcı üzerinden açmayı dene
                     launched = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
                     if (!launched) {
                        await _flutterTts.speak("Telefonda WhatsApp bulamadım anneanneciğim.");
                     }
                   }
                 } catch (e) {
                   try {
                     await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
                   } catch (e2) {
                     await _flutterTts.speak("Telefonda WhatsApp bulamadım anneanneciğim.");
                   }
                 }
               } else {
                 await _flutterTts.speak("Bu kişiyi rehberde bulamadım anneanneciğim.");
               }
             } else {
               await _flutterTts.speak("Rehbere erişmeme izin vermemişler anneanneciğim.");
             }
           }
         } else if (type == 'arama') {
           final kisiInfo = responseMap['kisi']?.toString().toLowerCase() ?? '';
           if (kisiInfo.isEmpty) {
              await _flutterTts.speak("Kimi aramak istediğini anlayamadım anneanneciğim.");
           } else {
             if (await Permission.contacts.request().isGranted) {
               final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
               String? targetNumber;
               // 1. Önce tam isim eşleşmesi ara
               for (var contact in contacts) {
                 final displayName = (contact.displayName ?? '').toLowerCase().trim();
                 if (displayName == kisiInfo.trim() && contact.phones.isNotEmpty) {
                   targetNumber = contact.phones.first.normalizedNumber;
                   if (targetNumber == null || targetNumber.isEmpty) targetNumber = contact.phones.first.number;
                   break;
                 }
               }
               // 2. Tam eşleşme yoksa başlangıç eşleşmesi ara
               if (targetNumber == null) {
                 for (var contact in contacts) {
                   final displayName = (contact.displayName ?? '').toLowerCase().trim();
                   if (displayName.isNotEmpty && displayName.startsWith(kisiInfo.trim()) && contact.phones.isNotEmpty) {
                     targetNumber = contact.phones.first.normalizedNumber;
                     if (targetNumber == null || targetNumber.isEmpty) targetNumber = contact.phones.first.number;
                     break;
                   }
                 }
               }

               if (targetNumber != null && targetNumber.isNotEmpty) {
                 targetNumber = targetNumber.replaceAll(RegExp(r'[^\d+]'), '');
                 await _flutterTts.speak("Hemen arıyorum canım anneannem, telefonu kulağına götür.");
                 await FlutterPhoneDirectCaller.callNumber(targetNumber);
               } else {
                 await _flutterTts.speak("Bu kişiyi rehberde bulamadım anneanneciğim.");
               }
             } else {
               await _flutterTts.speak("Rehbere bakmama izin vermemişler anneanneciğim.");
             }
           }
         } else if (type == 'acil_durum') {
           await _flutterTts.speak("Korkma canım anneannem, hemen arama yapıyorum.");

           // SMS İzni İste
           var status = await Permission.sms.status;
           if (!status.isGranted) {
             await Permission.sms.request();
           }

           // Yedek 3 Kişiye SMS At
           for (String numara in Constants.emergencyNumbers) {
             if (numara.isNotEmpty && !numara.contains("1112233") && !numara.contains("2223344") && !numara.contains("3334455")) {
               try {
                 await BackgroundSms.sendMessage(phoneNumber: numara, message: "ACİL DURUM! Lütfen bana hemen ulaşın!");
               } catch (e) {
                 debugPrint("SMS Hatası: $e");
               }
             }
           }

           await FlutterPhoneDirectCaller.callNumber(Constants.mainContactNumber);
         } else if (type == 'youtube') {
           final aramaMetni = responseMap['arama_metni']?.toString() ?? '';
           if (aramaMetni.isNotEmpty) {
             await _flutterTts.speak("Senin için hemen açıyorum canım anneannem.");
             final String temizArama = Uri.encodeComponent(aramaMetni);
             final Uri youtubeUri = Uri.parse("https://www.youtube.com/results?search_query=$temizArama");
             await launchUrl(youtubeUri, mode: LaunchMode.externalApplication);
           } else {
             await _flutterTts.speak("Ne açmamı istediğini tam duyamadım anneanneciğim.");
           }
         } else {
            await _flutterTts.speak("Ne dediğini pek anlayamadım canım anneannem.");
         }
       } else {
         await _flutterTts.speak("İnternet çekmiyor galiba anneanneciğim, sonra bir daha deneyelim.");
       }
    }
  }

  void _toggleState() async {
    if (_currentState == AppState.speaking) {
      await _flutterTts.stop();
      setState(() {
        _currentState = AppState.idle;
      });
      return;
    }

    if (_currentState == AppState.listening) {
      _stopListeningAndSpeak();
      return;
    }

    if (_currentState == AppState.idle) {
      if (_isSpeechInitialized) {
        HapticFeedback.heavyImpact(); // Titreşim eklendi
        setState(() {
          _currentState = AppState.listening;
          _lastRecognizedText = '';
        });
        await _speech.listen(
          onResult: (result) {
            _lastRecognizedText = result.recognizedWords;
          },
          localeId: 'tr_TR',
        );
      } else {
        await _initSpeech();
        if (_isSpeechInitialized) {
          _toggleState();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color iconColor;

    switch (_currentState) {
      case AppState.idle:
        backgroundColor = Colors.grey.shade300;
        iconColor = Colors.black;
        break;
      case AppState.listening:
        backgroundColor = Colors.green.shade300;
        iconColor = Colors.white;
        break;
      case AppState.speaking:
        backgroundColor = Colors.blue.shade300;
        iconColor = Colors.white;
        break;
    }

    return Scaffold(
      body: GestureDetector(
        onTap: _toggleState,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: backgroundColor,
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Icon(
              Icons.mic,
              size: 200.0,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

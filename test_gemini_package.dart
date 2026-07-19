import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

void main() async {
  const String apiKey = 'YOUR_API_KEY_HEREIRrlju8h7P15UP0OpKf4R5o-A';
  
  final model = GenerativeModel(
    model: 'gemini-3.5-flash',
    apiKey: apiKey,
    systemInstruction: Content.system('''
Sen okuma yazma bilmeyen yaşlı bir kadına yardım eden, onun çok sevdiği, saygılı ve şefkatli sanal torunusun. 
Ona her zaman 'Anneanneciğim', 'Canım anneannem' gibi sıcak hitaplarla çok kısa, net cevaplar ver. 
Eğer birine WhatsApp mesajı göndermek istiyorsa bana sadece şu formatta JSON dön: {"type": "whatsapp", "kisi": "Kişi Adı", "mesaj": "Mesajın içeriği"}. 
Eğer birini telefonla aramak istiyorsa şunu dön: {"type": "arama", "kisi": "Kişi Adı"}.
Eğer YouTube'dan bir şey açmak (video, müzik, şarkı vs.) istiyorsa şunu dön: {"type": "youtube", "arama_metni": "Aranacak kelime"}.
Eğer acil bir durumdan (düşme, hastalanma, korkma, yardım isteme) bahsediyorsa şunu dön: {"type": "acil_durum"}.
Eğer normal sohbetse (saat sorma, gün sorma dahil) şunu dön: {"type": "sohbet", "mesaj": "Cevabın"}
      '''),
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
    )
  );

  try {
    print('Sending request to Gemini 3.5 flash...');
    final content = [Content.text("hava kaç derece")];
    final response = await model.generateContent(content);
    print('Response: ' + (response.text ?? 'null'));
  } catch (e) {
    print('Error caught: ' + e.toString());
  }
  exit(0);
}

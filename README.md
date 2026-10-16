# Sasisho: GIMIS Token Queue + Bot
Nakili faili hizi juu ya repo yako (zinabadilisha zilizopo, zinaongeza mpya):
pubspec.yaml, firebase.json, firestore.rules (MPYA), functions/ (MPYA),
lib/screens/home_screen.dart, lib/screens/token_queue_screen.dart (MPYA), lib/services/firestore_service.dart

Kisha: flutter pub get && flutter build web
       firebase use gpsa-kinondoni
       firebase functions:secrets:set GIMIS_USER   (na GIMIS_PASS)
       (cd functions && npm install)
       firebase deploy

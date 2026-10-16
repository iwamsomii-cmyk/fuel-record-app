# Sasisho 2: Ruhusa (Permit) kabla ya Issue
Faili: lib/screens/token_queue_screen.dart, firestore.rules, functions/index.js
1. Weka rules mpya: Console > Firestore > Rules > bandika firestore.rules > Publish
2. Kwenye Firestore > users > document yako: ongeza field  canPermit (boolean) = true
3. flutter build web && firebase deploy --only hosting
4. Bot (Functions): upgrade Blaze, kisha firebase functions:secrets:set GIMIS_USER / GIMIS_PASS,
   (cd functions && npm install), firebase deploy --only functions

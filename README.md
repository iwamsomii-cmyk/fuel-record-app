# GPSA Fuel Record App (Flutter + Firebase)

Toleo la kidijitali la kitabu cha "Daily Fuel Receipts and Issue Summary".
Inafuata wireframe: Home Page → Start a Record → Receipt Information (jedwali
linaloweza kuongezwa mara kwa mara) → Total Quantity Sold → SUBMIT.

## Muundo wa data (Firestore)

```
fuelRecords (collection)
  └── {recordId}
        pumpName, preparedByName, preparedBySignature, preparedByDate,
        openingMeterReading, closingMeterReading,
        openingBalance, closingBalance,
        totalQuantitySold, totalPreparedByName, totalPreparedBySignature,
        totalPreparedByDate, timeClosed, submitted (bool), createdAt
        receiptItems (subcollection)
              └── {itemId}: pe, driver, token, chassisNo, qty, signature, contract, createdAt
```

`submitted: false` = bado ni draft ya local (haijapanda server bado).
`submitted: true` = imepandishwa baada ya kubonyeza SUBMIT.

Kwa sababu Firestore inahifadhi writes zote local kwanza (offline persistence
imewashwa moja kwa moja kwenye `firestore_service.dart`), hata kama simu
haina intaneti wakati wa Save, data haipotei — inasubiri tu isync
mtandao unaporudi. Hii ndiyo requirement uliyoandika kwenye wireframe.

## Njia ya haraka: GitHub Codespaces (bila kupakua chochote kwenye PC)

Folder hii ina `.devcontainer/devcontainer.json` inayowasha Flutter automatic
kwenye computer ya "cloud" (GitHub Codespaces), hivyo huhitaji kupakua
Flutter SDK kwenye PC yako mwenyewe:

1. Tengeneza akaunti ya bure kwenye github.com (kama huna).
2. Tengeneza repository mpya tupu (New repository), kisha "Add file >
   Upload files" na uburute (drag & drop) folder nzima ya `fuel_record_app`
   (pamoja na `.devcontainer`) kwenye hiyo ukurasa, kisha "Commit changes".
3. Kwenye repo hiyo, bonyeza kitufe cha kijani "Code" > tab "Codespaces" >
   "Create codespace on main". Subiri container ijijenge (mara ya kwanza
   inachukua dakika chache - inapakua Flutter kwenye server ya GitHub, si
   kwenye PC yako).
4. Terminal itafunguka moja kwa moja ndani ya VS Code (browser) ikiwa na
   Flutter tayari. Andika `flutter doctor` kuthibitisha.
5. Kwa vile Codespaces haina simu/emulator ya Android, tumia
   `flutter run -d chrome` kuona app kwenye browser (Flutter Web inasoma
   Firestore vizuri pia).
6. Usisahau kusimamisha Codespace (Stop codespace) unapomaliza, ili
   isitumie masaa yako ya bure bila sababu (free tier ni ~saa 60/mwezi).

Endelea na hatua ya "Unganisha app na Firebase" (flutterfire configure)
hapa chini - inafanya kazi ndani ya Codespaces vile vile.

## Hatua za kuanzisha (mara moja tu)

1. **Tengeneza Firebase project**
   - Nenda https://console.firebase.google.com → "Add project" → fuata hatua
     (unaweza zima Google Analytics, si lazima).

2. **Washa Firestore**
   - Kwenye console, Build → Firestore Database → Create database →
     anza kwa "Test mode" kwa majaribio (baadaye tutabadilisha Security
     Rules kabla ya matumizi halisi/production).

3. **Unganisha app na Firebase**
   ```bash
   flutter pub get
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Chagua project ulioutengeneza hapo juu, chagua Android (na iOS ukihitaji).
   Amri hii itaunda `lib/firebase_options.dart` halisi (inabadilisha
   placeholder iliyopo sasa) na kusajili app kwenye Firebase console.

4. **Endesha app**
   ```bash
   flutter run
   ```

## Ijayo (si lazima sasa)

- **Firestore Security Rules**: kabla ya kutoa app kwa watumiaji wa kweli,
  weka rules zinazohitaji kuingia (Firebase Auth) kabla ya kuandika/kusoma
  data, badala ya "test mode" iliyo wazi kwa kila mtu.
- **Firebase Auth**: pakiti `firebase_auth` tayari iko kwenye pubspec —
  tunaweza kuongeza login ya officer (jina/nywila au simu) ili "Prepared By"
  ijazwe automatic kutoka kwa aliye-login.
- **Signature halisi (mchoro)**: sasa "Signature" ni maandishi ya kuandikiwa;
  tunaweza kuibadilisha kuwa signature-pad (mchoro wa kidole) unaohifadhiwa
  Firebase Storage kama picha.
- **Export/Ripoti**: ripoti za kila siku/mwezi (kama TOTAL column kwenye
  kitabu cha karatasi) zinaweza kutengenezwa kwa Cloud Function au moja
  kwa moja app-side kwa kujumlisha `qty` za `receiptItems`.

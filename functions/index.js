const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
const GU = defineSecret("GIMIS_USER"), GP = defineSecret("GIMIS_PASS");
const BASE = "https://gimis.gpsa.go.tz";

const Q_GET = `query getIssueNoteToken($vehicleRegNo: String, $token: String) {
  getIssueNoteToken(vehicleRegNo: $vehicleRegNo, token: $token) { code data { id token used expireOn
    issueNote { issueNoteItems { id quantity issued } requisitionRequest { institutionName } } } } }`;
const M_ISSUE = `mutation issueItemsSelected($issueNoteItemDtos: [IssueNoteItemDtoInput]) {
  issueItemsSelected(issueNoteItemDtos: $issueNoteItemDtos) { id quantity issued } }`;

async function login() {
  const r = await fetch(`${BASE}/gateway/gpsa-uaa/gpsa/anonymous/user/login`, {
    method: "POST", headers: {"content-type": "application/json"},
    body: JSON.stringify({username: GU.value(), password: GP.value()})});
  if (!r.ok) throw new Error("GIMIS login " + r.status);
  return (await r.json()).access_token;
}
async function gql(at, operationName, variables, query) {
  const r = await fetch(`${BASE}/api/graphql?access_token=${at}`, {
    method: "POST",
    headers: {"content-type": "application/json", authorization: `Bearer ${at}`},
    body: JSON.stringify({operationName, variables, query})});
  if (!r.ok) throw new Error("GIMIS " + operationName + " " + r.status);
  const j = await r.json();
  if (j.errors) throw new Error(j.errors[0].message);
  return j.data;
}

async function processAll() {
  const snap = await db.collection("tokenQueue").where("status", "==", "pending").limit(60).get();
  if (snap.empty) return {done: 0};
  let at;
  try { at = await login(); }               // GIMIS imezima -> subiri mzunguko ujao
  catch (e) { console.warn(e.message); return {gimisDown: true}; }
  let issued = 0, failed = 0;
  for (const d of snap.docs) {
    const t = d.data(), ref = d.ref;
    if (t.expiresAt && t.expiresAt.toMillis() < Date.now()) { await ref.update({status: "expired"}); continue; }
    try {
      const res = (await gql(at, "getIssueNoteToken", {token: t.token, vehicleRegNo: t.chassisNo}, Q_GET)).getIssueNoteToken;
      const data = res && res.data;
      if (!data) throw new Error("Token haijapatikana / chassis si sahihi (code " + (res && res.code) + ")");
      if (!data.used) {
        const items = data.issueNote.issueNoteItems.filter(i => !i.issued)
          .map(i => ({id: i.id, token: t.token, quantity: i.quantity, prePriceUuid: null}));
        if (items.length) {
          const out = (await gql(at, "issueItemsSelected", {issueNoteItemDtos: items}, M_ISSUE)).issueItemsSelected;
          if (!out || !out.every(i => i.issued)) throw new Error("Save haikukamilika");
        }
      }
      await ref.update({status: "issued", issuedAt: admin.firestore.FieldValue.serverTimestamp(),
        institutionGimis: data.issueNote.requisitionRequest.institutionName, error: null});
      issued++;
    } catch (e) {
      failed++;
      await ref.update({attempts: admin.firestore.FieldValue.increment(1), error: String(e.message).slice(0, 300),
        status: (t.attempts || 0) >= 4 ? "failed" : "pending"});   // baada ya majaribio 5 -> failed (mtu aangalie)
    }
  }
  return {issued, failed};
}

exports.issuePending = onSchedule({schedule: "every 30 minutes", timeZone: "Africa/Dar_es_Salaam",
  secrets: [GU, GP], timeoutSeconds: 540}, processAll);

// Kitufe cha "Issue All Pending" (watumiaji walio-approved tu)
exports.runNow = onCall({secrets: [GU, GP], timeoutSeconds: 540}, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Ingia kwanza");
  const u = await db.doc(`users/${req.auth.uid}`).get();
  if (!u.exists || u.data().approved !== true) throw new HttpsError("permission-denied", "Huna ruhusa");
  return processAll();
});

// Onyo la kila siku: token zinazokaribia kuisha (unganisha SMS/WhatsApp hapa)
exports.expiryAlert = onSchedule({schedule: "every day 08:00", timeZone: "Africa/Dar_es_Salaam"}, async () => {
  const lim = admin.firestore.Timestamp.fromMillis(Date.now() + 2 * 864e5);
  const s = await db.collection("tokenQueue").where("status", "==", "pending").get();
  const n = s.docs.filter(d => d.data().expiresAt && d.data().expiresAt.toMillis() < lim.toMillis()).length;
  if (n) console.log(`ONYO: token ${n} zitaisha ndani ya siku 2`); // TODO: tuma SMS
});

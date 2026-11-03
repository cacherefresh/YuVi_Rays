// Live MIDI smoke test for YuVi Rays, run inside the app page in Chrome.
// It drives the REAL audio engine (Tone.js / Web Audio) with fake MIDI from
// an Akai MPK Mini Mk II, using the debug-build hook yuviDebugInjectMidi.
//
// Run with tool/live_midi_smoke.sh while `flutter run -d chrome` is up.
// Needs at least one audio file in assets/royalty_free_audio/.
(async () => {
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const D = window.YuViDVS;
  const dev = 'MPK Mini Mk II';
  const midi = (bytes) => window.yuviDebugInjectMidi(dev, bytes);
  const steps = [];
  const check = (name, ok, detail) => steps.push({ name, pass: !!ok, detail });
  const secs = () => D.getPosition('A') * D.decks.A.duration;

  if (typeof window.yuviDebugInjectMidi !== 'function') {
    return { pass: false, error: 'yuviDebugInjectMidi missing: is this a debug build?' };
  }

  // Load the first bundled audio file into Deck A, found the same way the
  // app's song menu finds it: from Flutter's asset list.
  const assetList = await (await fetch('assets/AssetManifest.bin.json')).json();
  const keyBytes = atob(assetList);
  const keys = [...new TextDecoder().decode(Uint8Array.from(keyBytes, (c) => c.charCodeAt(0)))
    .matchAll(/assets\/royalty_free_audio\/[^\u0000-\u001f]+?\.(?:mp3|m4a|aac|wav|ogg|flac)/gi)].map((m) => m[0]).sort();
  const key = keys[0];
  check('track is bundled', key, key || 'no audio file in assets/royalty_free_audio/');
  if (!key) return { pass: false, steps };
  await D.loadUrl('A', 'assets/' + key.split('/').map(encodeURIComponent).join('/'));
  for (let i = 0; i < 50 && !(D.decks.A.duration > 0); i++) await sleep(100);
  check('track loaded', D.decks.A.duration > 0, `${D.decks.A.duration.toFixed(1)} s`);
  await sleep(300); // let the Dart side receive the "loaded" event

  // Pad 1 (note 44): play.
  midi([144, 44, 100]); midi([128, 44, 0]);
  await sleep(1500);
  check('pad 1 plays', D.decks.A.isPlaying, `playhead ${secs().toFixed(2)} s`);
  check('sound reaches the master meter', D.getMasterLevel() > -60, `${D.getMasterLevel().toFixed(1)} dBFS`);

  // K2 (CC 2) coarse pitch, swept from centre up to 80; K3 (CC 3) fine, to 48.
  for (const v of [64, 70, 75, 80]) { midi([176, 2, v]); await sleep(30); }
  midi([176, 3, 64]); midi([176, 3, 48]);
  await sleep(100);
  const wantRate = 1 + (16 * 16 / 63 - 0.25) / 100;
  check('K2 + K3 set the playback rate', Math.abs(D.decks.A.rate - wantRate) < 1e-6,
    `rate ${D.decks.A.rate.toFixed(5)}, expected ${wantRate.toFixed(5)}`);

  // The playhead now advances at that rate (the old drift bug ignored it).
  const p1 = secs(); await sleep(2000); const p2 = secs();
  const measured = (p2 - p1) / 2;
  check('playhead follows the pitch', Math.abs(measured - D.decks.A.rate) < 0.03,
    `${measured.toFixed(3)} track-s per s at rate ${D.decks.A.rate.toFixed(3)}`);

  // Pad 2 (note 45) held 1.3 s: cue set where the press began.
  const atPress = secs();
  midi([144, 45, 90]); await sleep(1300); midi([128, 45, 0]);
  await sleep(100);
  check('pad 2 hold sets cue at the press point', Math.abs(D.decks.A.cuePoint - atPress) < 0.1,
    `cue ${D.decks.A.cuePoint.toFixed(2)} s, press at ${atPress.toFixed(2)} s`);

  // Pad 1: pause. Then pad 2 tap: play from cue.
  midi([144, 44, 100]); midi([128, 44, 0]);
  await sleep(300);
  check('pad 1 again pauses', !D.decks.A.isPlaying, '');
  midi([144, 45, 90]); await sleep(150); midi([128, 45, 0]);
  await sleep(500);
  const fromCue = secs() - D.decks.A.cuePoint;
  check('pad 2 tap plays from the cue', D.decks.A.isPlaying && fromCue >= 0 && fromCue < 1.0,
    `${fromCue.toFixed(2)} s past the cue`);

  // Bank B pad 1 (note 32): first press sets hot cue 1 at the playhead,
  // a later press jumps back to it.
  const hotAt = secs();
  midi([144, 32, 100]); midi([128, 32, 0]);
  await sleep(1500);
  midi([144, 32, 100]); midi([128, 32, 0]);
  await sleep(150);
  check('bank B pad 1 sets, then jumps to, hot cue 1', Math.abs(secs() - hotAt) < 0.3,
    `hot cue at ${hotAt.toFixed(2)} s, playhead after jump ${secs().toFixed(2)} s`);

  // Leave it quiet: pause.
  midi([144, 44, 100]); midi([128, 44, 0]);
  return { pass: steps.every((s) => s.pass), steps };
})()

'use strict';

// YuVi Rays - Digital Vinyl System
// Audio graph (plan 007):
//   per deck:  Player → EQ3 (Hi / Mid / Low) ─┬→ ChannelVol → XfadeGain → MasterVol
//                                             └→ CueGate (0/1, pre-fader) → CueBus
//   master:    MasterVol → Meter
//              MasterVol → Destination (speakers: the default output)
//   phones:    CueBus    → MixCue    ─┐
//              MasterVol → MixMaster ─┴→ PhonesVol → MediaStreamDestination
//              → hidden <audio>.setSinkId(chosen device)
//
// Everything stays in one AudioContext. The headphone path plays only once a
// device is chosen; on the default device it would double the speakers.

(function () {
  // Normalized 0..1 fader value → dB, with a -60 dB floor (≈ silence).
  function faderToDb(normalized) {
    const v = Math.max(0, Math.min(1, normalized));
    return v <= 0.0001 ? -60 : 20 * Math.log10(v);
  }

  // Short ramp avoids zipper noise from 7-bit MIDI fader steps.
  const RAMP_SECONDS = 0.02;

  // BPM detection: web-audio-beat-detector (MIT), self-contained module build
  // from jsDelivr, pinned. Loaded once, on demand, and preloaded at start-up.
  const BEAT_DETECTOR_URL =
    'https://cdn.jsdelivr.net/npm/web-audio-beat-detector@8.2.31/+esm';
  let beatDetector = null;
  function loadBeatDetector() {
    if (!beatDetector) {
      beatDetector = import(BEAT_DETECTOR_URL).catch((e) => {
        beatDetector = null; // allow a retry on the next track
        throw e;
      });
    }
    return beatDetector;
  }

  const YuViDVS = {
    decks: {},
    _cb: null,
    // Master section is created lazily so the Tone context is ready.
    _master: null,

    initMaster: function () {
      if (this._master) return this._master;
      loadBeatDetector().catch(() => {}); // warm the cache; errors surface per track
      // Give Tone a native AudioContext instead of its compatibility wrapper,
      // so the master output can move to another device (setSinkId). Must
      // happen before any Tone node exists.
      try {
        const Native = window.AudioContext || window.webkitAudioContext;
        Tone.setContext(new Tone.Context(new Native({ latencyHint: 'interactive' })));
      } catch (e) {
        console.warn('[YuViDVS] native AudioContext unavailable, using Tone default', e);
      }
      // Low latency: Tone schedules everything lookAhead seconds ahead
      // (default 0.1 s), so play, stop, faders and EQ all acted 100 ms late.
      // A live mixer reacts now. The device itself adds a few ms
      // (latencyHint 'interactive').
      Tone.getContext().lookAhead = 0;

      // smoothing=0.8 gives a natural ballistic feel matching Pioneer meters
      const meter     = new Tone.Meter({ normalRange: false, smoothing: 0.8 });
      const masterVol = new Tone.Volume(0);
      masterVol.connect(meter);       // meter reads post-master, like a Pioneer mixer
      masterVol.toDestination();      // speakers

      // Headphone cue bus. Mix gains come from Dart (equal-power curve).
      const cueBus    = new Tone.Gain(1);
      const mixCue    = new Tone.Gain(Math.SQRT1_2);
      const mixMaster = new Tone.Gain(Math.SQRT1_2);
      const phonesVol = new Tone.Volume(0);
      cueBus.connect(mixCue);
      masterVol.connect(mixMaster);
      mixCue.connect(phonesVol);
      mixMaster.connect(phonesVol);
      const phonesOut = Tone.getContext().rawContext.createMediaStreamDestination();
      phonesVol.connect(phonesOut);

      this._master = {
        meter: meter, masterVol: masterVol,
        cueBus: cueBus, mixCue: mixCue, mixMaster: mixMaster,
        phonesVol: phonesVol, phonesOut: phonesOut,
      };
      this._watchOutputDevices();
      return this._master;
    },

    initDeck: function (deckId) {
      const master = this.initMaster();
      // EQ3 uses a proper MultibandSplit crossover so the three bands together
      // reconstruct the full spectrum. Killing all three → true silence.
      // Crossover points: Low 0–250 Hz, Mid 250–2500 Hz, High 2500 Hz–Nyquist.
      const eq3 = new Tone.EQ3({
        low:  0,
        mid:  0,
        high: 0,
        lowFrequency:  250,
        highFrequency: 2500,
      });
      const vol    = new Tone.Volume(faderToDb(0.8));
      const xfade  = new Tone.Gain(1);
      const cueGate = new Tone.Gain(0);   // headphone cue (PFL), off by default
      const player = new Tone.Player({ loop: false });

      player.connect(eq3);
      eq3.connect(vol);
      vol.connect(xfade);
      xfade.connect(master.masterVol);
      eq3.connect(cueGate);               // pre-fader: after EQ, before the fader
      cueGate.connect(master.cueBus);

      this.decks[deckId] = {
        player:    player,
        eq3:       eq3,
        vol:       vol,
        xfade:     xfade,
        cueGate:   cueGate,
        cuePoint:  0,
        startTime: 0,
        offset:    0,
        _volume:   0.8,
        isPlaying: false,
        duration:  0,
        ticker:    null,
        rate:      1,   // playback-rate multiplier (pitch)
        loadId:    0,   // increments per load, so stale BPM results are dropped
      };
    },

    // Current playhead in track seconds. Elapsed wall time is scaled by the
    // playback rate: at +16% pitch, 1 s of wall time plays 1.16 s of track.
    _seconds: function (deck) {
      if (!deck.isPlaying) return deck.offset;
      return deck.offset + (Tone.now() - deck.startTime) * deck.rate;
    },

    setDartCallback: function (fn) {
      this._cb = fn;
    },

    _emit: function (event, deckId, data) {
      if (this._cb) {
        try {
          this._cb(JSON.stringify({ event: event, deckId: deckId, data: data || {} }));
        } catch (e) {
          console.error('[YuViDVS] callback error:', e);
        }
      }
    },

    loadUrl: async function (deckId, url) {
      await Tone.start();
      const deck = this.decks[deckId];
      if (!deck) return;
      try {
        const loadId = ++deck.loadId;
        await deck.player.load(url);
        deck.duration = deck.player.buffer.duration;
        const waveform = this._extractWaveform(deck.player.buffer, 512);
        this._emit('loaded',   deckId, { duration: deck.duration });
        this._emit('waveform', deckId, { points: Array.from(waveform) });
        this._detectBpm(deckId, loadId);
      } catch (e) {
        console.error('[YuViDVS] loadUrl error:', e);
        this._emit('error', deckId, { message: String(e) });
      }
    },

    // Detects the track's tempo off the main thread and emits
    // 'bpm' {bpm: number|null}. Searches 90-180 BPM (the library default).
    _detectBpm: async function (deckId, loadId) {
      const deck = this.decks[deckId];
      try {
        const detector = await loadBeatDetector();
        const bpm = await detector.analyze(deck.player.buffer.get());
        if (deck.loadId !== loadId) return; // a newer track was loaded meanwhile
        this._emit('bpm', deckId, { bpm: bpm });
      } catch (e) {
        if (deck.loadId !== loadId) return;
        console.warn('[YuViDVS] BPM detection failed:', e);
        this._emit('bpm', deckId, { bpm: null });
      }
    },

        _extractWaveform: function (toneBuffer, numSamples) {
      const raw  = toneBuffer.get();
      const data = raw.getChannelData(0);
      const step = Math.max(1, Math.floor(data.length / numSamples));
      const out  = new Float32Array(numSamples);
      let max = 0.0001;

      for (let i = 0; i < numSamples; i++) {
        let sum = 0;
        for (let j = 0; j < step; j++) {
          sum += Math.abs(data[i * step + j] || 0);
        }
        out[i] = sum / step;
        if (out[i] > max) max = out[i];
      }
      for (let i = 0; i < numSamples; i++) out[i] /= max;
      return out;
    },

    play: async function (deckId) {
      await Tone.start();
      const deck = this.decks[deckId];
      if (!deck || deck.isPlaying || !deck.player.loaded) return;
      // Capture a single Tone.now() so player start time and our tracking
      // reference are exactly the same instant (no drift between two calls).
      const now = Tone.now();
      deck.player.start(now, deck.offset);
      deck.startTime = now;
      deck.isPlaying = true;
      this._startTicker(deckId);
    },

    pause: function (deckId) {
      const deck = this.decks[deckId];
      if (!deck || !deck.isPlaying) return;
      deck.offset     = this._seconds(deck);
      deck.isPlaying  = false;
      deck.player.stop();
      this._stopTicker(deckId);
    },

    stop: function (deckId) {
      const deck = this.decks[deckId];
      if (!deck) return;
      deck.player.stop();
      deck.offset    = 0;
      deck.isPlaying = false;
      this._stopTicker(deckId);
      this._emit('position', deckId, { position: 0, seconds: 0 });
    },

    seek: function (deckId, normalizedPosition) {
      const deck = this.decks[deckId];
      if (!deck) return;
      const wasPlaying = deck.isPlaying;
      if (wasPlaying) {
        deck.player.stop();
        deck.isPlaying = false;
        this._stopTicker(deckId);
      }
      deck.offset = normalizedPosition * deck.duration;
      if (wasPlaying) {
        const now = Tone.now();
        deck.player.start(now, deck.offset);
        deck.startTime = now;
        deck.isPlaying = true;
        this._startTicker(deckId);
      }
    },

    setCuePoint: function (deckId) {
      const deck = this.decks[deckId];
      if (!deck) return;
      const seconds    = this._seconds(deck);
      deck.cuePoint    = Math.max(0, Math.min(seconds, deck.duration));
      const normalized = deck.duration > 0 ? deck.cuePoint / deck.duration : 0;
      this._emit('cue', deckId, { cuePoint: normalized });
    },

    jumpToCue: function (deckId) {
      const deck = this.decks[deckId];
      if (!deck) return;
      const normalized = deck.duration > 0 ? deck.cuePoint / deck.duration : 0;
      this.seek(deckId, normalized);
    },

    setVolume: function (deckId, normalized) {
      const deck = this.decks[deckId];
      if (!deck) return;
      deck._volume = Math.max(0, Math.min(1, normalized));
      deck.vol.volume.rampTo(faderToDb(deck._volume), RAMP_SECONDS);
    },

    // Linear gain 0..1 from the crossfader curve (computed in Dart).
    setCrossfaderGain: function (deckId, gain) {
      const deck = this.decks[deckId];
      if (!deck) return;
      deck.xfade.gain.rampTo(Math.max(0, Math.min(1, gain)), RAMP_SECONDS);
    },

    setMasterVolume: function (normalized) {
      this.initMaster().masterVol.volume.rampTo(faderToDb(normalized), RAMP_SECONDS);
    },

    setHeadphoneVolume: function (normalized) {
      this.initMaster().phonesVol.volume.rampTo(faderToDb(normalized), RAMP_SECONDS);
    },

    // Headphone cue (PFL) on or off for one deck.
    setHeadphoneCue: function (deckId, on) {
      const deck = this.decks[deckId];
      if (!deck) return;
      deck.cueGate.gain.rampTo(on ? 1 : 0, RAMP_SECONDS);
    },

    // Linear gains for the cue and master sides of the headphone mix
    // (equal-power curve, computed in Dart).
    setHeadphoneMixGains: function (cueGain, masterGain) {
      const m = this.initMaster();
      m.mixCue.gain.rampTo(Math.max(0, Math.min(1, cueGain)), RAMP_SECONDS);
      m.mixMaster.gain.rampTo(Math.max(0, Math.min(1, masterGain)), RAMP_SECONDS);
    },

    // ── Headphone output device ──────────────────────────────────────────
    // Chrome hides output device names and IDs until the site has
    // microphone permission, so listing may ask for it once. The microphone
    // is stopped straight away; nothing is recorded.
    _phones: { el: null, deviceId: null, deviceName: null, status: 'off' },

    headphonesSupported: function () {
      return typeof HTMLMediaElement !== 'undefined' &&
        'setSinkId' in HTMLMediaElement.prototype &&
        !!(navigator.mediaDevices && navigator.mediaDevices.enumerateDevices);
    },

    _outputs: async function () {
      const all = await navigator.mediaDevices.enumerateDevices();
      return all.filter((d) => d.kind === 'audiooutput');
    },

    // A saved device ID can go stale (new browser profile, cleared site
    // data). Fall back to the device with the same name, if any.
    _resolveDevice: async function (deviceId, deviceName) {
      try {
        const outs = await this._outputs();
        if (outs.some((d) => d.deviceId === deviceId)) return deviceId;
        const byName = deviceName && outs.find((d) => d.label === deviceName && d.deviceId !== 'default');
        return byName ? byName.deviceId : deviceId;
      } catch (e) {
        return deviceId;
      }
    },

    // Resolves to a JSON string: [{id, name}], or {error} on failure.
    listOutputDevices: async function (askPermission) {
      if (!this.headphonesSupported()) return JSON.stringify({ error: 'unsupported' });
      try {
        let outs = await this._outputs();
        const hidden = outs.length === 0 || outs.every((d) => !d.label);
        if (hidden && askPermission) {
          const mic = await navigator.mediaDevices.getUserMedia({ audio: true });
          mic.getTracks().forEach((t) => t.stop());
          outs = await this._outputs();
        }
        return JSON.stringify(outs
          .filter((d) => d.deviceId && d.deviceId !== 'communications')
          .map((d) => ({ id: d.deviceId, name: d.label || 'Unnamed output' })));
      } catch (e) {
        return JSON.stringify({ error: String((e && e.name) || e) });
      }
    },

    _setPhonesStatus: function (status, message) {
      this._phones.status = status;
      this._emit('headphones', '', {
        status: status, deviceId: this._phones.deviceId,
        deviceName: this._phones.deviceName, message: message || null,
      });
    },

    // Sends the headphone mix to [deviceId]; null or '' turns it off.
    // Call from a user gesture (a click) so play() is allowed.
    setHeadphoneSink: async function (deviceId, deviceName) {
      const ph = this._phones;
      if (!deviceId) {
        if (ph.el) { ph.el.pause(); ph.el.srcObject = null; }
        ph.deviceId = null; ph.deviceName = null;
        this._setPhonesStatus('off');
        return;
      }
      if (!this.headphonesSupported()) { this._setPhonesStatus('unsupported'); return; }
      ph.deviceId = deviceId; ph.deviceName = deviceName || null;
      this._setPhonesStatus('connecting');
      try {
        const m = this.initMaster();
        if (!ph.el) ph.el = new Audio();
        const requested = deviceId;
        deviceId = await this._resolveDevice(deviceId, deviceName);
        if (ph.deviceId !== requested) return; // a newer choice replaced this one
        ph.deviceId = deviceId;
        await ph.el.setSinkId(deviceId);
        ph.el.srcObject = m.phonesOut.stream;
        await this._playPhones(deviceId);
      } catch (e) {
        if (ph.el) ph.el.pause();
        this._setPhonesStatus('error', String((e && e.message) || e));
      }
    },

    // play() needs a user gesture until the page has had one. When it is
    // blocked (e.g. a device restored at start-up), wait for the next click
    // or key press and try again.
    _playPhones: async function (deviceId) {
      const ph = this._phones;
      try {
        await ph.el.play();
        if (ph.deviceId === deviceId) this._setPhonesStatus('playing');
      } catch (e) {
        if (!e || e.name !== 'NotAllowedError') throw e;
        this._setPhonesStatus('waitingForClick');
        const retry = () => {
          document.removeEventListener('pointerdown', retry, true);
          document.removeEventListener('keydown', retry, true);
          if (ph.deviceId === deviceId) {
            this._playPhones(deviceId).catch((err) =>
              this._setPhonesStatus('error', String((err && err.message) || err)));
          }
        };
        document.addEventListener('pointerdown', retry, true);
        document.addEventListener('keydown', retry, true);
      }
    },

    getHeadphoneStatus: function () {
      return this._phones.status;
    },

    // ── Master (speakers) output device ──────────────────────────────────
    // The master stays on the AudioContext's own output, the lowest-latency
    // path; only its device changes. '' / null = the system default.
    _masterSink: { deviceId: null, deviceName: null },

    masterSinkSupported: function () {
      return typeof Tone.getContext().rawContext.setSinkId === 'function';
    },

    setMasterSink: async function (deviceId, deviceName) {
      this.initMaster();
      const ctx = Tone.getContext().rawContext;
      const ms = this._masterSink;
      if (typeof ctx.setSinkId !== 'function') {
        this._emit('masterOutput', '', { status: 'unsupported' });
        return;
      }
      try {
        if (deviceId) deviceId = await this._resolveDevice(deviceId, deviceName);
        await ctx.setSinkId(deviceId || '');
        ms.deviceId = deviceId || null;
        ms.deviceName = deviceId ? (deviceName || null) : null;
        this._emit('masterOutput', '', { status: 'ok', deviceId: ms.deviceId, deviceName: ms.deviceName });
      } catch (e) {
        this._emit('masterOutput', '', {
          status: 'error', deviceId: ms.deviceId, deviceName: ms.deviceName,
          message: String((e && e.message) || e),
        });
      }
    },

    // Follows plug / unplug: pause when the chosen device goes away and
    // resume when it (or a device with the same name) comes back.
    _watchOutputDevices: function () {
      if (!this.headphonesSupported() || this._watching) return;
      this._watching = true;
      navigator.mediaDevices.addEventListener('devicechange', async () => {
        const ph = this._phones;
        this._emit('outputDevicesChanged', '', {});
        const outs = await this._outputs();
        const ms = this._masterSink;
        const ctx = Tone.getContext().rawContext;
        if (ms.deviceId && ctx.sinkId !== ms.deviceId &&
            outs.some((d) => d.deviceId === ms.deviceId)) {
          this.setMasterSink(ms.deviceId, ms.deviceName); // came back: re-apply
        }
        if (!ph.deviceId) return;
        const same = outs.find((d) => d.deviceId === ph.deviceId) ||
          (ph.deviceName && outs.find((d) => d.label === ph.deviceName));
        if (!same) {
          if (ph.el) ph.el.pause();
          this._setPhonesStatus('lost');
        } else if (ph.status !== 'playing' && ph.status !== 'connecting') {
          this.setHeadphoneSink(same.deviceId, same.label || ph.deviceName);
        }
      });
    },

    setEQ: function (deckId, band, value) {
      // DJ kill-EQ mapping (value -1..+1 from Dart):
      //   -1.0  → -Infinity dB  (complete kill — no signal through this band)
      //   -1..0 → linear -40..0 dB  (progressive cut)
      //    0    → 0 dB           (flat — no change to the signal)
      //    0..+1 → linear 0..+6 dB (standard DJ boost range)
      //
      // Tone.EQ3 splits the signal via MultibandSplit, so all three bands at
      // -Infinity together reconstruct to silence (no frequency bleed).
      const deck = this.decks[deckId];
      if (!deck || !deck.eq3) return;
      let db;
      if (value <= -1.0) {
        db = -Infinity;          // true kill: gain node → 0 linear
      } else if (value < 0) {
        db = value * 40;         // -0.99 → -39.6 dB, 0 → 0 dB
      } else {
        db = value * 6;          // 0 → 0 dB, +1 → +6 dB
      }
      deck.eq3[band].value = db;
    },

    getMasterLevel: function () {
      if (!this._master) return -100;
      const val = this._master.meter.getValue();
      if (typeof val === 'number') return isFinite(val) ? val : -100;
      // Stereo array — take the louder channel
      if (Array.isArray(val)) {
        const db = Math.max(isFinite(val[0]) ? val[0] : -100, isFinite(val[1]) ? val[1] : -100);
        return db;
      }
      return -100;
    },

    // Speed multiplier from the pitch controls (1.04 = +4%). Re-anchors the
    // playhead first so position tracking stays exact across speed changes.
    setPlaybackRate: function (deckId, rate) {
      const deck = this.decks[deckId];
      if (!deck || !(rate > 0)) return;
      if (deck.isPlaying) {
        deck.offset    = this._seconds(deck);
        deck.startTime = Tone.now();
      }
      deck.rate = rate;
      deck.player.playbackRate = rate;
    },

    // Sets the cue at a given playhead (0..1), e.g. where a pad was first pressed.
    setCuePointAt: function (deckId, normalized) {
      const deck = this.decks[deckId];
      if (!deck) return;
      const n = Math.max(0, Math.min(1, normalized));
      deck.cuePoint = n * deck.duration;
      this._emit('cue', deckId, { cuePoint: n });
    },

    getPosition: function (deckId) {
      const deck = this.decks[deckId];
      if (!deck) return 0;
      if (!deck.isPlaying) return deck.duration > 0 ? deck.offset / deck.duration : 0;
      const s = this._seconds(deck);
      return deck.duration > 0 ? Math.min(s / deck.duration, 1) : 0;
    },

    _startTicker: function (deckId) {
      const deck = this.decks[deckId];
      this._stopTicker(deckId);
      deck.ticker = setInterval(() => {
        if (!deck.isPlaying) return;
        const seconds  = this._seconds(deck);
        const position = deck.duration > 0 ? Math.min(seconds / deck.duration, 1) : 0;
        this._emit('position', deckId, { position: position, seconds: seconds });
        if (seconds >= deck.duration && deck.duration > 0) {
          this.stop(deckId);
          this._emit('ended', deckId, {});
        }
      }, 50);
    },

    _stopTicker: function (deckId) {
      const deck = this.decks[deckId];
      if (deck && deck.ticker) {
        clearInterval(deck.ticker);
        deck.ticker = null;
      }
    },
  };

  window.YuViDVS = YuViDVS;
})();

'use strict';

// YuVi Rays - Digital Vinyl System
// Audio graph per deck: Player → EQ3 (Hi / Mid / Low) → Volume → Destination

(function () {
  const YuViDVS = {
    decks: {},
    _cb: null,

    initDeck: function (deckId) {
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
      const vol    = new Tone.Volume(0);
      const player = new Tone.Player({ loop: false });

      player.connect(eq3);
      eq3.connect(vol);
      vol.toDestination();

      this.decks[deckId] = {
        player:    player,
        eq3:       eq3,
        vol:       vol,
        cuePoint:  0,
        startTime: 0,
        offset:    0,
        _volume:   0.8,
        isPlaying: false,
        duration:  0,
        ticker:    null,
      };
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
        await deck.player.load(url);
        deck.duration = deck.player.buffer.duration;
        const waveform = this._extractWaveform(deck.player.buffer, 512);
        this._emit('loaded',   deckId, { duration: deck.duration });
        this._emit('waveform', deckId, { points: Array.from(waveform) });
      } catch (e) {
        console.error('[YuViDVS] loadUrl error:', e);
        this._emit('error', deckId, { message: String(e) });
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
      deck.offset    += Tone.now() - deck.startTime;
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
      const seconds    = deck.isPlaying ? deck.offset + (Tone.now() - deck.startTime) : deck.offset;
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
      const db = deck._volume <= 0.0001 ? -60 : 20 * Math.log10(deck._volume);
      deck.vol.volume.value = db;
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

    setPitch: function (deckId, semitones) {
      const deck = this.decks[deckId];
      if (!deck) return;
      deck.player.playbackRate = Math.pow(2, semitones / 12);
    },

    getPosition: function (deckId) {
      const deck = this.decks[deckId];
      if (!deck) return 0;
      if (!deck.isPlaying) return deck.duration > 0 ? deck.offset / deck.duration : 0;
      const s = deck.offset + (Tone.now() - deck.startTime);
      return deck.duration > 0 ? Math.min(s / deck.duration, 1) : 0;
    },

    _startTicker: function (deckId) {
      const deck = this.decks[deckId];
      this._stopTicker(deckId);
      deck.ticker = setInterval(() => {
        if (!deck.isPlaying) return;
        const seconds  = deck.offset + (Tone.now() - deck.startTime);
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

'use strict';

// YuVi Rays - MIDI-Learn bridge (Web MIDI API)
// Supported in Chrome/Edge/Opera; NOT supported in Safari/Firefox — see
// DJ_INSTRUCTIONS.md.
(function () {
  const YuViMIDI = {
    _cb: null,
    isSupported: typeof navigator !== 'undefined' && !!navigator.requestMIDIAccess,

    setDartCallback: function (fn) {
      this._cb = fn;
    },

    _emit: function (type, channel, number, value) {
      if (this._cb) {
        try {
          this._cb(JSON.stringify({ type: type, channel: channel, number: number, value: value }));
        } catch (e) {
          console.error('[YuViMIDI] callback error:', e);
        }
      }
    },

    requestAccess: function () {
      if (!this.isSupported) {
        console.warn('[YuViMIDI] Web MIDI API not supported in this browser (Chrome/Edge/Opera only).');
        return;
      }
      const self = this;
      navigator.requestMIDIAccess().then(function (access) {
        self._bindInputs(access);
        access.onstatechange = function () { self._bindInputs(access); };
      }).catch(function (e) {
        console.error('[YuViMIDI] MIDI access denied:', e);
      });
    },

    _bindInputs: function (access) {
      const self = this;
      access.inputs.forEach(function (input) {
        input.onmidimessage = function (msg) { self._handleMessage(msg); };
      });
    },

    _handleMessage: function (msg) {
      const data = msg.data;
      const status = data[0];
      const channel = status & 0x0f;
      const command = status & 0xf0;
      const number = data[1];
      const value = data.length > 2 ? data[2] : 0;

      if (command === 0xB0) {
        this._emit('cc', channel, number, value);
      } else if (command === 0x90) {
        // Note On with velocity 0 is conventionally treated as Note Off.
        this._emit('note', channel, number, value);
      } else if (command === 0x80) {
        this._emit('note', channel, number, 0);
      }
    },
  };

  window.YuViMIDI = YuViMIDI;
})();

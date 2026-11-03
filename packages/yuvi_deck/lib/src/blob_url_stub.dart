import 'dart:typed_data';

/// Native builds don't use blob URLs — file_picker returns a real
/// filesystem path instead (see deck_widget.dart's `_pickFile`). Native
/// file loading through the audio engine is future work alongside the
/// native VST engine (see native/yuvi_vst_host/README.md).
String? bytesToBlobUrl(Uint8List bytes, String mimeType) => null;

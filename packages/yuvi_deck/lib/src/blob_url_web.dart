import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Wraps picked bytes in a `blob:` URL the Tone.js bridge can `load()`.
String? bytesToBlobUrl(Uint8List bytes, String mimeType) {
  final blobParts = <JSAny>[bytes.toJS].toJS;
  final blob = web.Blob(blobParts, web.BlobPropertyBag(type: mimeType));
  return web.URL.createObjectURL(blob);
}

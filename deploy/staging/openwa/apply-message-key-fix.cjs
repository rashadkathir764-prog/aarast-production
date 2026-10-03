'use strict';

// Build-time correction of the actual ID extraction in the reviewed 1.34.7
// dependency. No runtime monkey patch, polling, ACK synthesis, or transport retry.
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const expectedHash = '0d0f88565f481dbfeb9493b04b24033a2cb60f5fd2fd0e84e543b461d98878fe';
const appRoot = process.argv[2] || process.cwd();
const libraryRoot = path.join(appRoot, 'node_modules/whatsapp-web.js');
const app = JSON.parse(fs.readFileSync(path.join(appRoot, 'package.json'), 'utf8'));
const library = JSON.parse(fs.readFileSync(path.join(libraryRoot, 'package.json'), 'utf8'));
if (app.name !== 'openwa' || app.version !== '0.8.17' || library.version !== '1.34.7') {
  throw new Error('Unreviewed OpenWA/library version; refuse to apply the ID correction');
}
const sourcePath = path.join(libraryRoot, 'src/util/Injected/Utils.js');
const original = fs.readFileSync(sourcePath, 'utf8');
if (createHash('sha256').update(original).digest('hex') !== expectedHash) {
  throw new Error('Unreviewed library source; refuse to apply the ID correction');
}

function replaceOnce(source, from, to) {
  if (source.split(from).length !== 2) throw new Error('ID correction anchor is not unique');
  return source.replace(from, to);
}

let corrected = replaceOnce(original, '.Msg.get(newMsgKey._serialized);',
  '.Msg.get(window.WWebJS.getSerializedMessageKey(newMsgKey));');
corrected = replaceOnce(corrected, '        delete msg.pendingAckUpdate;',
  `        // WhatsApp Web renamed only the serialized message-key field to $1.
        // Normalize the real identifier at the library serialization boundary;
        // all downstream consumers, including message_ack, keep their contract.
        if (msg.id && typeof msg.id === 'object' && msg.id._serialized == null) {
            const serialized = window.WWebJS.getSerializedMessageKey(msg.id);
            if (serialized) msg.id = Object.assign({}, msg.id, { _serialized: serialized });
        }

        delete msg.pendingAckUpdate;`);
corrected = replaceOnce(corrected, '    window.WWebJS.getMessageModel = (message) => {',
  `    window.WWebJS.getSerializedMessageKey = (key) => {
        const serialized = key?._serialized ?? key?.$1;
        return typeof serialized === 'string' && serialized.trim() ? serialized : undefined;
    };

    window.WWebJS.getMessageModel = (message) => {`);
fs.writeFileSync(sourcePath, corrected);
console.log('PASS reviewed message-key extraction correction; delivery ACK contract unchanged');

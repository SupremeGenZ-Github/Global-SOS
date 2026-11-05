const encoder = new TextEncoder();
const table = Array.from({length: 256}, (_, value) => {
  for (let bit = 0; bit < 8; bit++) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  return value >>> 0;
});
function checksum(bytes) {
  let value = 0xffffffff;
  for (const byte of bytes) value = table[(value ^ byte) & 255] ^ (value >>> 8);
  return (value ^ 0xffffffff) >>> 0;
}
function safeName(name) {
  return name.replace(/[^a-zA-Z0-9._-]/g, '_').replace(/^\.+/, '').slice(-100) || 'attachment';
}

export function incidentText(record) {
  return [record.title, 'Created: ' + record.createdAt, 'Updated: ' + record.updatedAt, '', record.notes,
    '', ...record.attachments.map((item, index) => `${index + 1}. ${item.name} (${item.type}, ${item.size} bytes)`)].join('\n');
}

// ZIP with uncompressed entries preserves the original media bytes.
export async function incidentArchive(record) {
  const files = [{name: 'notes.txt', bytes: encoder.encode(incidentText(record))}];
  const metadata = {...record, attachments: record.attachments.map(({blob, ...item}, index) => ({...item, exportedAs: `${index + 1}-${safeName(item.name)}`}))};
  files.push({name: 'incident.json', bytes: encoder.encode(JSON.stringify(metadata, null, 2))});
  for (const [index, item] of record.attachments.entries()) {
    files.push({name: `${index + 1}-${safeName(item.name)}`, bytes: new Uint8Array(await item.blob.arrayBuffer())});
  }
  let offset = 0;
  const local = [], directory = [];
  for (const file of files) {
    const name = encoder.encode(file.name), crc = checksum(file.bytes);
    const header = new Uint8Array(30), view = new DataView(header.buffer);
    view.setUint32(0, 0x04034b50, true); view.setUint16(4, 20, true); view.setUint16(6, 0x800, true);
    view.setUint16(12, 33, true); view.setUint32(14, crc, true);
    view.setUint32(18, file.bytes.length, true); view.setUint32(22, file.bytes.length, true); view.setUint16(26, name.length, true);
    local.push(header, name, file.bytes);
    const entry = new Uint8Array(46), central = new DataView(entry.buffer);
    central.setUint32(0, 0x02014b50, true); central.setUint16(4, 20, true); central.setUint16(6, 20, true);
    central.setUint16(8, 0x800, true); central.setUint16(14, 33, true); central.setUint32(16, crc, true);
    central.setUint32(20, file.bytes.length, true); central.setUint32(24, file.bytes.length, true);
    central.setUint16(28, name.length, true); central.setUint32(42, offset, true);
    directory.push(entry, name); offset += header.length + name.length + file.bytes.length;
  }
  const size = directory.reduce((total, item) => total + item.length, 0);
  const end = new Uint8Array(22), footer = new DataView(end.buffer);
  footer.setUint32(0, 0x06054b50, true); footer.setUint16(8, files.length, true); footer.setUint16(10, files.length, true);
  footer.setUint32(12, size, true); footer.setUint32(16, offset, true);
  return new Blob([...local, ...directory, end], {type: 'application/zip'});
}

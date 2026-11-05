export const MAX_ATTACHMENT_BYTES = 100 * 1024 * 1024;
export const MAX_JOURNAL_BYTES = 500 * 1024 * 1024;
export const MAX_ATTACHMENTS = 10;
export const MAX_INCIDENTS = 50;
export const MEDIA_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'video/mp4', 'video/webm', 'video/quicktime', 'video/3gpp']);

export function validateAttachment(file) {
  if (!MEDIA_TYPES.has(file.type)) throw Error('Choose a supported photo or video.');
  if (!Number.isFinite(file.size) || file.size <= 0 || file.size > MAX_ATTACHMENT_BYTES) {
    throw Error('Each attachment must be between 1 byte and 100 MB.');
  }
}

export function journalBytes(records) {
  return records.reduce((total, record) => total + record.attachments.reduce((sum, file) => sum + file.size, 0), 0);
}

export function makeIncident(title, notes, files, previous = null) {
  if (title.length > 100 || notes.length > 4000) throw Error('Use a title of up to 100 characters and notes of up to 4,000 characters.');
  if (files.length > MAX_ATTACHMENTS) throw Error('Use up to 10 attachments per incident.');
  files.forEach(validateAttachment);
  if (files.reduce((total, file) => total + file.size, 0) > 200 * 1024 * 1024) throw Error('Keep each incident under 200 MB.');
  return {
    id: previous?.id ?? crypto.randomUUID(),
    title: title.trim() || 'Untitled incident',
    notes: notes.trim(),
    createdAt: previous?.createdAt ?? new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    attachments: files.map(file => ({id: file.id ?? crypto.randomUUID(), name: file.name, type: file.type, size: file.size, blob: file.blob ?? file})),
  };
}

function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('global-sos-incidents', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('incidents', {keyPath: 'id'});
    request.onerror = () => reject(Error('Incident storage is unavailable. Try a regular browser window or free some device space.'));
    request.onblocked = () => reject(Error('Close other Global SOS tabs and try again.'));
    request.onsuccess = () => resolve(request.result);
  });
}

export async function listIncidents() {
  const database = await openDatabase();
  try {
    return await new Promise((resolve, reject) => {
      const transaction = database.transaction('incidents', 'readonly');
      const request = transaction.objectStore('incidents').getAll();
      transaction.oncomplete = () => resolve(request.result.sort((a, b) => b.createdAt.localeCompare(a.createdAt)));
      transaction.onabort = transaction.onerror = () => reject(Error('Saved incidents could not be read.'));
    });
  } finally { database.close(); }
}

// Read and update inside one transaction so simultaneous tabs obey the limits.
export async function saveIncident(record) {
  const database = await openDatabase();
  try {
    return await new Promise((resolve, reject) => {
      const transaction = database.transaction('incidents', 'readwrite');
      const store = transaction.objectStore('incidents');
      let failure = 'The incident could not be saved. Your draft is still open.';
      const request = store.getAll();
      request.onsuccess = () => {
        const remaining = request.result.filter(item => item.id !== record.id);
        if (remaining.length >= MAX_INCIDENTS || journalBytes([...remaining, record]) > MAX_JOURNAL_BYTES) {
          failure = 'Journal limit reached (50 incidents or 500 MB). Export and delete older entries before saving.';
          transaction.abort();
          return;
        }
        store.put(record);
      };
      transaction.oncomplete = () => resolve();
      transaction.onabort = transaction.onerror = () => reject(Error(failure));
    });
  } finally { database.close(); }
}

export async function deleteIncident(id) {
  const database = await openDatabase();
  try {
    await new Promise((resolve, reject) => {
      const transaction = database.transaction('incidents', 'readwrite');
      transaction.objectStore('incidents').delete(id);
      transaction.oncomplete = () => resolve();
      transaction.onabort = transaction.onerror = () => reject(Error('The incident could not be deleted.'));
    });
  } finally { database.close(); }
}

import type {Incident} from './incident-store.mjs';
export function incidentText(record:Incident): string;
export function incidentArchive(record:Incident): Promise<Blob>;

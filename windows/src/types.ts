export type OpenFile = {
  id: string;
  path: string;
  name: string;
  kind: "note" | "reading";
  format: string;
  url: string;
  content?: string;
  hash?: string;
  converted?: boolean;
};
export type Style = {
  fontSize: number;
  lineHeight: number;
  width: number;
  justify: boolean;
  fontFamily?: string;
  color?: string;
  background?: string;
  paragraphSpacing?: number;
  strongColor?: string;
  strongSize?: number;
  headings?: { size: number; color: string }[];
};
export type Preferences = {
  layout: "tabs" | "split";
  splitRatio: number;
  sidebarWidth: number;
  syntax: boolean;
  whitespace: boolean;
  readingZoom: number;
  styles: Record<"reading" | "visual" | "source", Style>;
  recent: {
    reading?: string | null;
    note?: string | null;
    openedAt?: number;
  }[];
  bookmarks: { title: string; url: string }[];
  positions: Record<string, { top: number; page: number; cfi?: string }>;
};
export type StudioAPI = {
  openFile: () => Promise<OpenFile | null>;
  openFolder: () => Promise<{
    name: string;
    files: { name: string; path: string }[];
  } | null>;
  openPath: (path: string) => Promise<OpenFile>;
  saveNote: (
    id: string | null,
    text: string,
    saveAs?: boolean,
  ) => Promise<OpenFile | null>;
  readBytes: (id: string) => Promise<Uint8Array>;
  importImage: (id: string, bytes: number[], name: string) => Promise<string>;
  preferences: () => Promise<Preferences>;
  storePreferences: (value: Preferences) => Promise<void>;
  setDirty: (dirty: boolean) => void;
  readyToClose: () => void;
  recovery: (
    value: { path: string | null; content: string } | null,
  ) => Promise<void>;
  readRecovery: () => Promise<{ path: string | null; content: string } | null>;
  webOpen: (url: string) => Promise<void>;
  webBounds: (bounds: {
    x: number;
    y: number;
    width: number;
    height: number;
    visible: boolean;
  }) => void;
  webAction: (
    action: string,
    value?: string | number,
  ) => Promise<string | void>;
  onCommand: (callback: (command: string) => void) => void;
  onFile: (callback: (file: OpenFile) => void) => void;
  onWeb: (
    callback: (state: {
      url: string;
      title: string;
      loading: boolean;
      error?: string;
    }) => void,
  ) => void;
};
declare global {
  interface Window {
    studio: StudioAPI;
  }
}

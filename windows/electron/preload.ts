import { contextBridge, ipcRenderer } from "electron";
const invoke = (channel: string, ...args: unknown[]) =>
  ipcRenderer.invoke(channel, ...args);
contextBridge.exposeInMainWorld("studio", {
  openFile: () => invoke("file:choose"),
  openFolder: () => invoke("folder:choose"),
  openPath: (path: string) => invoke("file:open", path),
  saveNote: (id: string | null, text: string, saveAs = false) =>
    invoke("note:save", id, text, saveAs),
  readBytes: (id: string) => invoke("file:bytes", id),
  importImage: (id: string, bytes: number[], name: string) =>
    invoke("note:image", id, bytes, name),
  preferences: () => invoke("prefs:get"),
  storePreferences: (value: unknown) => invoke("prefs:set", value),
  setDirty: (value: boolean) => ipcRenderer.send("note:dirty", value),
  readyToClose: () => ipcRenderer.send("window:close-ready"),
  recovery: (value: unknown) => invoke("recovery:set", value),
  readRecovery: () => invoke("recovery:get"),
  webOpen: (url: string) => invoke("web:open", url),
  webBounds: (bounds: unknown) => ipcRenderer.send("web:bounds", bounds),
  webAction: (action: string, value: unknown) =>
    invoke("web:action", action, value),
  onCommand: (cb: (value: string) => void) =>
    ipcRenderer.on("command", (_event, value) => cb(value)),
  onFile: (cb: (value: unknown) => void) =>
    ipcRenderer.on("file:opened", (_event, value) => cb(value)),
  onWeb: (cb: (value: unknown) => void) =>
    ipcRenderer.on("web:state", (_event, value) => cb(value)),
});

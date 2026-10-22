import { epubCSS, bestPDFZoom } from "./presentation";
import * as pdfjs from "pdfjs-dist";
import pdfWorker from "pdfjs-dist/build/pdf.worker.min.mjs?url";
import "pdfjs-dist/web/pdf_viewer.css";
import ePub from "epubjs";
import { renderAsync } from "docx-preview";
import type { OpenFile, Style } from "./types";
pdfjs.GlobalWorkerOptions.workerSrc = pdfWorker;

type Location = { top: number; page: number; cfi?: string };
export class Reader {
  private readingStyle: Style = {
    fontSize: 20,
    lineHeight: 1.7,
    width: 900,
    justify: false,
  };
  setStyle(style: Style) {
    this.readingStyle = { ...style };
    this.applyEPUBStyle();
  }
  private applyEPUBStyle() {
    if (!this.rendition) return;
    this.host.style.background = this.readingStyle.background ?? "#ffffff";
    const target = this.host.querySelector<HTMLElement>(".epub-content");
    if (target) {
      target.style.maxWidth = this.readingStyle.width + "px";
      target.style.background = this.readingStyle.background ?? "#ffffff";
    }
    for (const contents of this.rendition.getContents())
      this.styleEPUBContents(contents);
  }
  private styleEPUBContents(contents: any) {
    const doc = contents.document as Document;
    let sheet = doc.getElementById("studio-reading-style");
    if (!sheet) {
      sheet = doc.createElement("style");
      sheet.id = "studio-reading-style";
      doc.head.append(sheet);
    }
    sheet.textContent = epubCSS(this.readingStyle, this.zoom);
  }
  private epubResize: ResizeObserver | null = null;
  private generation = 0;
  private pdf: pdfjs.PDFDocumentProxy | null = null;
  private loading: pdfjs.PDFDocumentLoadingTask | null = null;
  private tasks = new Set<pdfjs.RenderTask>();
  private book: any = null;
  private rendition: any = null;
  private observer: IntersectionObserver | null = null;
  private file: OpenFile | null = null;
  private pageElements: HTMLElement[] = [];
  private currentPage = 1;
  private zoom = 100;
  private cfi: string | undefined;
  private saveTimer: ReturnType<typeof setTimeout> | undefined;
  private documentBody: HTMLElement | null = null;
  constructor(
    readonly host: HTMLElement,
    readonly status: (message: string) => void,
    readonly onLocation: (value: Location) => void,
    readonly onTOC: (
      items: { title: string; href: string; depth: number }[],
    ) => void,
    readonly onPage: (page: number, total: number) => void,
    readonly onFocus: () => void,
  ) {
    host.addEventListener("pointerdown", () => onFocus());
    host.addEventListener(
      "scroll",
      () => {
        this.updatePage();
        clearTimeout(this.saveTimer);
        this.saveTimer = setTimeout(
          () => this.onLocation(this.location()),
          400,
        );
      },
      { passive: true },
    );
  }
  location(): Location {
    return { top: this.host.scrollTop, page: this.currentPage, cfi: this.cfi };
  }
  clear() {
    this.generation++;
    this.epubResize?.disconnect();
    this.epubResize = null;
    this.host.style.removeProperty("background");
    this.observer?.disconnect();
    this.observer = null;
    for (const task of this.tasks) task.cancel();
    this.tasks.clear();
    void this.loading?.destroy().catch(() => {});
    this.loading = null;
    this.pdf = null;
    this.book?.destroy();
    this.book = null;
    this.rendition = null;
    this.host.replaceChildren();
    this.file = null;
    this.pageElements = [];
    this.documentBody = null;
    this.cfi = undefined;
    this.currentPage = 1;
    clearTimeout(this.saveTimer);
    this.onTOC([]);
    this.onPage(1, 1);
  }
  async open(file: OpenFile, zoom: number, position?: Location) {
    this.clear();
    const generation = this.generation;
    this.file = file;
    this.zoom = zoom;
    this.status(file.converted ? "已转换为只读阅读副本，原文件未改动。" : "");
    if (file.format === "pdf") {
      const bytes = await window.studio.readBytes(file.id);
      if (generation !== this.generation) return;
      this.loading = pdfjs.getDocument({
        data: bytes,
        cMapUrl: new URL("./pdf-assets/cmaps/", document.baseURI).href,
        cMapPacked: true,
        standardFontDataUrl: new URL(
          "./pdf-assets/standard_fonts/",
          document.baseURI,
        ).href,
        wasmUrl: new URL("./pdf-assets/wasm/", document.baseURI).href,
      });
      const pdf = await this.loading.promise;
      if (generation !== this.generation) {
        return;
      }
      this.pdf = pdf;
      this.currentPage = position?.page ?? 1;
      await this.buildPDF(generation);
      if (generation !== this.generation) return;
      this.goPage(this.currentPage);
      if (position?.top) this.host.scrollTop = position.top;
      void this.pdfOutline(pdf, generation);
    } else if (file.format === "epub") {
      const bytes = await window.studio.readBytes(file.id);
      if (generation !== this.generation) return;
      this.book = ePub(
        bytes.buffer.slice(
          bytes.byteOffset,
          bytes.byteOffset + bytes.byteLength,
        ) as ArrayBuffer,
      );
      await this.book.ready;
      if (generation !== this.generation) return;
      const toc: any[] = [];
      const flatten = (items: any[], depth = 0) => {
        for (const item of items) {
          toc.push({ title: item.label.trim(), href: item.href, depth });
          if (item.subitems) flatten(item.subitems, depth + 1);
        }
      };
      flatten(this.book.navigation.toc ?? []);
      this.onTOC(toc);
      const target = document.createElement("div");
      target.className = "epub-content";
      this.host.append(target);
      this.rendition = this.book.renderTo(target, {
        width: "100%",
        height: "100%",
        flow: "paginated",
        spread: "none",
        allowScriptedContent: false,
        allowPopups: false,
      });
      this.rendition.hooks.content.register((contents: any) =>
        this.styleEPUBContents(contents),
      );
      this.applyEPUBStyle();
      this.epubResize = new ResizeObserver(() => {
        if (
          generation === this.generation &&
          target.clientWidth &&
          target.clientHeight
        )
          this.rendition?.resize(target.clientWidth, target.clientHeight);
      });
      this.epubResize.observe(target);
      this.rendition.on("relocated", (location: any) => {
        this.cfi = location.start.cfi;
        this.currentPage = (location.start.index ?? 0) + 1;
        this.onPage(this.currentPage, this.book.spine.items.length);
        this.onLocation(this.location());
      });
      this.rendition.on("keydown", (event: KeyboardEvent) => {
        if (
          ["ArrowLeft", "ArrowRight"].includes(event.key) &&
          !event.ctrlKey &&
          !event.altKey &&
          !event.shiftKey &&
          !event.metaKey
        ) {
          const selection = (
            event.target as HTMLElement
          )?.ownerDocument?.getSelection();
          if (selection && !selection.isCollapsed) return;
          event.preventDefault();
          event.key === "ArrowRight" ? void this.next() : void this.previous();
        }
      });
      this.rendition.on("click", () => this.onFocus());
      await this.rendition.display(position?.cfi || undefined);
    } else if (file.format === "docx") {
      const bytes = await window.studio.readBytes(file.id);
      if (generation !== this.generation) return;
      const wrapper = document.createElement("div");
      wrapper.className = "office-shadow";
      this.host.append(wrapper);
      const shadow = wrapper.attachShadow({ mode: "open" });
      const content = document.createElement("article");
      const styles = document.createElement("div");
      shadow.append(styles, content);
      this.documentBody = content;
      await renderAsync(bytes, content, styles, {
        className: "docx",
        inWrapper: true,
        breakPages: true,
        ignoreLastRenderedPageBreak: false,
        renderHeaders: true,
        renderFooters: true,
        renderFootnotes: true,
        renderEndnotes: true,
        useBase64URL: true,
      });
      if (generation !== this.generation) return;
      // Remove active content while preserving document style and page geometry.
      for (const node of Array.from(
        content.querySelectorAll("script,iframe,object,embed"),
      ))
        node.remove();
      for (const element of Array.from(content.querySelectorAll("*")))
        for (const attr of Array.from(element.attributes))
          if (
            /^on/i.test(attr.name) ||
            ((attr.name === "href" || attr.name === "src") &&
              /^javascript:/i.test(attr.value))
          )
            element.removeAttribute(attr.name);
      const safe = document.createElement("style");
      safe.textContent =
        ":host{display:block;} .docx-wrapper{padding:24px;background:#eceef2;}section.docx{box-shadow:0 2px 9px #0001;margin:0 auto 20px!important;} *{user-select:text;}a{pointer-events:none;}";
      shadow.append(safe);
      this.pageElements = Array.from(
        content.querySelectorAll<HTMLElement>("section.docx"),
      );
      this.setOfficeZoom();
      this.currentPage = position?.page ?? 1;
      this.onPage(this.currentPage, this.pageElements.length || 1);
      this.host.scrollTop = position?.top ?? 0;
      this.status(
        "DOCX 只读预览：保留显式分页与已记录分页；自动分页可能与 Word 不同。",
      );
    } else throw new Error("此格式未得到可阅读的副本。");
  }
  private async pdfOutline(pdf: pdfjs.PDFDocumentProxy, generation: number) {
    try {
      const result: { title: string; href: string; depth: number }[] = [];
      const visit = async (items: any[], depth = 0) => {
        for (const item of items) {
          try {
            const dest =
              typeof item.dest === "string"
                ? await pdf.getDestination(item.dest)
                : item.dest;
            if (dest) {
              const page =
                typeof dest[0] === "number"
                  ? dest[0]
                  : await pdf.getPageIndex(dest[0]);
              result.push({
                title: item.title,
                href: `pdf:${page + 1}`,
                depth,
              });
            }
          } catch {}
          if (item.items?.length) await visit(item.items, depth + 1);
        }
      };
      await visit((await pdf.getOutline()) ?? []);
      if (generation === this.generation) this.onTOC(result);
    } catch {}
  }
  private async buildPDF(generation: number) {
    const pdf = this.pdf;
    if (!pdf) return;
    for (const task of this.tasks) task.cancel();
    this.tasks.clear();
    this.observer?.disconnect();
    this.host.replaceChildren();
    this.pageElements = [];
    const pages = document.createElement("div");
    pages.className = "pdf-pages";
    this.host.append(pages);
    const first = await pdf.getPage(1);
    if (generation !== this.generation) return;
    const viewport = first.getViewport({ scale: this.zoom / 100 });
    for (let number = 1; number <= pdf.numPages; number++) {
      const page = document.createElement("section");
      page.className = "pdf-page";
      page.dataset.number = String(number);
      page.style.width = `${viewport.width}px`;
      page.style.height = `${viewport.height}px`;
      page.setAttribute("aria-label", `第 ${number} 页`);
      pages.append(page);
      this.pageElements.push(page);
    }
    this.onPage(this.currentPage, pdf.numPages);
    this.observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          const element = entry.target as HTMLElement;
          if (entry.isIntersecting) {
            if (!element.dataset.rendered) {
              element.dataset.rendered = "pending";
              void this.renderPDFPage(element, generation).catch((error) => {
                if (
                  error?.name !== "RenderingCancelledException" &&
                  generation === this.generation
                )
                  this.status(`此页加载失败：${error.message}`);
              });
            }
          }
        }
      },
      { root: this.host, rootMargin: "600px 0px", threshold: [0, 0.2, 0.6] },
    );
    for (const page of this.pageElements) this.observer.observe(page);
    this.updatePage();
  }
  private async renderPDFPage(element: HTMLElement, generation: number) {
    const pdf = this.pdf;
    if (!pdf) return;
    const page = await pdf.getPage(Number(element.dataset.number));
    if (generation !== this.generation) return;
    const viewport = page.getViewport({ scale: this.zoom / 100 });
    element.style.width = `${viewport.width}px`;
    element.style.height = `${viewport.height}px`;
    const canvas = document.createElement("canvas");
    const ratio = Math.max(window.devicePixelRatio || 1, 1);
    canvas.width = Math.ceil(viewport.width * ratio);
    canvas.height = Math.ceil(viewport.height * ratio);
    canvas.style.width = `${viewport.width}px`;
    canvas.style.height = `${viewport.height}px`;
    element.append(canvas);
    const text = document.createElement("div");
    text.className = "textLayer";
    text.style.setProperty("--scale-factor", String(viewport.scale));
    text.style.setProperty("--total-scale-factor", String(viewport.scale));
    element.style.setProperty("--scale-factor", String(viewport.scale));
    element.style.setProperty("--total-scale-factor", String(viewport.scale));
    element.append(text);
    const task = page.render({
      canvas,
      viewport,
      transform: ratio === 1 ? undefined : [ratio, 0, 0, ratio, 0, 0],
    });
    this.tasks.add(task);
    try {
      await task.promise;
      if (generation !== this.generation) return;
      const layer = new pdfjs.TextLayer({
        textContentSource: await page.getTextContent(),
        container: text,
        viewport,
      });
      await layer.render();
      element.dataset.rendered = "true";
      for (const old of this.pageElements) {
        if (
          Math.abs(
            Number(old.dataset.number) - Number(element.dataset.number),
          ) > 8 &&
          old.dataset.rendered === "true"
        ) {
          old.replaceChildren();
          delete old.dataset.rendered;
        }
      }
    } finally {
      this.tasks.delete(task);
    }
  }
  private updatePage() {
    if ((!this.pdf && !this.documentBody) || !this.pageElements.length) return;
    const target =
      this.host.getBoundingClientRect().top +
      Math.min(120, this.host.clientHeight / 4);
    let low = 0,
      high = this.pageElements.length - 1;
    while (low < high) {
      const mid = Math.ceil((low + high) / 2);
      if (this.pageElements[mid].getBoundingClientRect().top <= target)
        low = mid;
      else high = mid - 1;
    }
    this.currentPage = low + 1;
    this.onPage(
      this.currentPage,
      this.pdf?.numPages ?? this.pageElements.length,
    );
  }
  async fit(axis: "width" | "height") {
    if (!this.pdf) return this.zoom;
    const page = await this.pdf.getPage(this.currentPage);
    const base = page.getViewport({ scale: 1 });
    return Math.max(
      25,
      Math.min(
        400,
        100 *
          (axis === "width"
            ? (this.host.clientWidth - 48) / base.width
            : (this.host.clientHeight - 40) / base.height),
      ),
    );
  }
  async best() {
    if (!this.pdf) return { zoom: this.zoom, reason: "请先打开 PDF。" };
    const generation = this.generation;
    const page = await this.pdf.getPage(this.currentPage);
    const base = page.getViewport({ scale: 1 });
    const ops = await page.getOperatorList();
    let matrix = [1, 0, 0, 1, 0, 0];
    const stack: number[][] = [];
    let raster:
      | {
          width: number;
          height: number;
          pixelsWidth: number;
          pixelsHeight: number;
        }
      | undefined;
    let bestArea = 0;
    for (let i = 0; i < ops.fnArray.length; i++) {
      const op = ops.fnArray[i],
        args = ops.argsArray[i];
      if (op === pdfjs.OPS.save) stack.push([...matrix]);
      else if (op === pdfjs.OPS.restore)
        matrix = stack.pop() ?? [1, 0, 0, 1, 0, 0];
      else if (op === pdfjs.OPS.transform)
        matrix = pdfjs.Util.transform(matrix, args);
      else if (op === pdfjs.OPS.paintFormXObjectBegin) {
        stack.push([...matrix]);
        if (args[0]) matrix = pdfjs.Util.transform(matrix, args[0]);
      } else if (op === pdfjs.OPS.paintFormXObjectEnd)
        matrix = stack.pop() ?? [1, 0, 0, 1, 0, 0];
      else if (
        op === pdfjs.OPS.paintImageXObject ||
        op === pdfjs.OPS.paintInlineImageXObject
      ) {
        const image =
          op === pdfjs.OPS.paintInlineImageXObject
            ? args[0]
            : { width: args[1], height: args[2] };
        const width = Math.hypot(matrix[0], matrix[1]),
          height = Math.hypot(matrix[2], matrix[3]);
        const area = Math.abs(matrix[0] * matrix[3] - matrix[1] * matrix[2]);
        if (
          area > base.width * base.height * 0.75 &&
          area > bestArea &&
          width &&
          height &&
          image?.width &&
          image?.height
        ) {
          bestArea = area;
          raster = {
            width,
            height,
            pixelsWidth: image.width,
            pixelsHeight: image.height,
          };
        }
      }
    }
    if (generation !== this.generation)
      throw new Error("阅读文件已切换，请重新点击最佳显示。");
    return bestPDFZoom(
      base.width,
      base.height,
      this.host.clientWidth,
      this.host.clientHeight,
      window.devicePixelRatio,
      raster,
    );
  }
  async setZoom(value: number) {
    this.zoom = Math.max(25, Math.min(400, value));
    if (this.pdf) {
      const page = this.currentPage;
      await this.buildPDF(this.generation);
      this.goPage(page);
    } else if (this.rendition) this.applyEPUBStyle();
    else this.setOfficeZoom();
  }
  private setOfficeZoom() {
    if (this.documentBody)
      this.documentBody.style.zoom = String(this.zoom / 100);
  }
  goPage(page: number) {
    if (this.pdf || this.documentBody) {
      this.currentPage = Math.max(
        1,
        Math.min(
          this.pdf?.numPages ?? this.pageElements.length,
          Math.round(page),
        ),
      );
      this.pageElements[this.currentPage - 1]?.scrollIntoView({
        block: "start",
      });
      this.onPage(
        this.currentPage,
        this.pdf?.numPages ?? this.pageElements.length,
      );
    }
  }
  async previous() {
    if (this.rendition) await this.rendition.prev();
    else if (this.pdf || this.documentBody) this.goPage(this.currentPage - 1);
    else
      this.host.scrollBy({
        top: -this.host.clientHeight * 0.85,
        behavior: "smooth",
      });
  }
  async next() {
    if (this.rendition) await this.rendition.next();
    else if (this.pdf || this.documentBody) this.goPage(this.currentPage + 1);
    else
      this.host.scrollBy({
        top: this.host.clientHeight * 0.85,
        behavior: "smooth",
      });
  }
  async chapter(href: string) {
    if (this.pdf && href.startsWith("pdf:")) this.goPage(Number(href.slice(4)));
    else if (this.rendition) await this.rendition.display(href);
  }
  focus() {
    if (this.rendition) {
      this.host.querySelector("iframe")?.contentWindow?.focus();
    } else this.host.focus();
  }
}

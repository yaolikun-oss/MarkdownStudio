import test from "node:test";
import assert from "node:assert/strict";
import { JSDOM } from "jsdom";
import JSZip from "jszip";
import epubModule from "epubjs";
import { renderAsync } from "docx-preview";
const dom = new JSDOM('<!doctype html><div id="styles"></div><main></main>', {
  pretendToBeVisual: true,
  url: "https://studio.test/",
});
for (const key of [
  "window",
  "document",
  "Node",
  "Element",
  "HTMLElement",
  "DOMParser",
  "XMLSerializer",
  "FileReader",
  "Blob",
  "navigator",
  "getComputedStyle",
])
  Object.defineProperty(globalThis, key, {
    value:
      key === "getComputedStyle"
        ? dom.window.getComputedStyle.bind(dom.window)
        : dom.window[key],
    configurable: true,
  });
const ePub = epubModule.default ?? epubModule;
test("EPUB archive parser retains both chapters and navigation with modern XML parser", async () => {
  const zip = new JSZip();
  zip.file("mimetype", "application/epub+zip");
  zip.file(
    "META-INF/container.xml",
    '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="book.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
  );
  zip.file(
    "book.opf",
    '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">qa</dc:identifier><dc:title>QA 电子书</dc:title><dc:language>zh</dc:language></metadata><manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="one" href="one.xhtml" media-type="application/xhtml+xml"/><item id="two" href="two.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="one"/><itemref idref="two"/></spine></package>',
  );
  zip.file(
    "nav.xhtml",
    '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>目录</title></head><body><nav epub:type="toc"><ol><li><a href="one.xhtml">第一章</a></li><li><a href="two.xhtml">第二章</a></li></ol></nav></body></html>',
  );
  for (const name of ["one", "two"])
    zip.file(
      name + ".xhtml",
      `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>${name}</title></head><body><p>中文原文 ${name}</p></body></html>`,
    );
  const bytes = await zip.generateAsync({ type: "arraybuffer" });
  const book = ePub(bytes);
  await book.ready;
  assert.equal(book.spine.items.length, 2);
  assert.equal(book.navigation.toc[1].label, "第二章");
  const section = await book.spine.get(0).load(book.load.bind(book));
  assert.match(section.textContent, /中文原文 one/);
  book.destroy();
});
test("DOCX renderer preserves two explicit pages, Chinese text and table cells", async () => {
  const zip = new JSZip();
  zip.file(
    "[Content_Types].xml",
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
  );
  zip.file(
    "_rels/.rels",
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="r1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
  );
  zip.file(
    "word/document.xml",
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>第一页中文原文</w:t></w:r></w:p><w:p><w:r><w:br w:type="page"/></w:r></w:p><w:p><w:r><w:t>第二页内容</w:t></w:r></w:p><w:tbl><w:tblPr/><w:tblGrid><w:gridCol w:w="4000"/></w:tblGrid><w:tr><w:tc><w:tcPr/><w:p><w:r><w:t>表格单元格</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:bottom="1440" w:left="1440" w:right="1440"/></w:sectPr></w:body></w:document>',
  );
  const bytes = await zip.generateAsync({ type: "uint8array" });
  const host = document.querySelector("main");
  await renderAsync(bytes, host, document.getElementById("styles"), {
    breakPages: true,
    ignoreLastRenderedPageBreak: false,
    useBase64URL: true,
  });
  assert.equal(host.querySelectorAll("section.docx").length, 2);
  assert.match(host.textContent, /第一页中文原文/);
  assert.match(host.textContent, /第二页内容/);
  assert.equal(host.querySelector("td").textContent, "表格单元格");
  dom.window.close();
});

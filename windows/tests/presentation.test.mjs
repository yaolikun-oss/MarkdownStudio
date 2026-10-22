import test from "node:test";
import assert from "node:assert/strict";
import { build } from "esbuild";
import { JSDOM } from "jsdom";
import { normalizePreferences, webURL } from "../electron/core.mjs";
const output = await build({
  entryPoints: ["src/presentation.ts"],
  bundle: true,
  write: false,
  format: "esm",
  platform: "node",
});
const { epubCSS, applyVisualStyle, bestPDFZoom } = await import(
  "data:text/javascript;base64," +
    Buffer.from(output.outputFiles[0].text).toString("base64")
);
test("extended style migration retains manual settings independently and sanitizes CSS input", () => {
  const prefs = normalizePreferences({
    styles: {
      reading: {
        background: "#faf0dd",
        fontFamily: "KaiTi",
        width: 720,
        headings: [{ size: 60, color: "#123456" }],
      },
      source: { color: "#112233", fontFamily: "bad; color:red" },
    },
  });
  assert.equal(prefs.styles.reading.background, "#faf0dd");
  assert.equal(prefs.styles.visual.background, "#ffffff");
  assert.equal(prefs.styles.reading.headings[0].size, 60);
  assert.equal(prefs.styles.source.color, "#112233");
  assert.equal(prefs.styles.source.fontFamily, "monospace");
  assert.deepEqual(normalizePreferences(prefs), prefs);
  prefs.styles.reading.headings[0].size = 55;
  assert.equal(prefs.styles.visual.headings[0].size, 52);
});
test("EPUB injected stylesheet applies background, font, paragraph and title rules after zoom", () => {
  const style = normalizePreferences({
    styles: {
      reading: {
        background: "#faf0dd",
        fontFamily: "KaiTi",
        fontSize: 24,
        justify: true,
        strongColor: "#123456",
      },
    },
  }).styles.reading;
  const css = epubCSS(style, 125);
  assert.match(css, /background:#faf0dd!important/);
  assert.match(css, /font-size:30px!important/);
  assert.match(css, /font-family:"KaiTi"/);
  assert.match(css, /text-align:justify/);
  assert.match(css, /h1\{font-size:65px/);
  assert.match(css, /strong,b\{color:#123456/);
});
test("visual style changes are scoped to editor host and retain independent title sizes", () => {
  const d = new JSDOM('<div id="one"></div><div id="two"></div>');
  const one = d.window.document.getElementById("one"),
    two = d.window.document.getElementById("two");
  applyVisualStyle(
    one,
    normalizePreferences({
      styles: { visual: { color: "#123456", background: "#faf0dd" } },
    }).styles.visual,
  );
  assert.equal(one.style.getPropertyValue("--text-color"), "#123456");
  assert.equal(one.style.getPropertyValue("--h1-size"), "52px");
  assert.equal(two.style.length, 0);
  d.window.close();
});
test("best PDF recalculates from display DPR for raster and both viewport dimensions for vector", () => {
  const raster = {
    width: 600,
    height: 800,
    pixelsWidth: 2400,
    pixelsHeight: 3200,
  };
  assert.equal(bestPDFZoom(600, 800, 1000, 900, 2, raster).zoom, 200);
  assert.equal(bestPDFZoom(600, 800, 1000, 900, 1, raster).zoom, 400);
  assert.equal(bestPDFZoom(600, 800, 1000, 900, 2).zoom, 107.5);
  assert.equal(bestPDFZoom(600, 800, 500, 900, 2).zoom, (100 * 452) / 600);
  assert.match(bestPDFZoom(600, 800, 500, 900, 2).reason, /没有唯一/);
});
test("address normalization accepts bare hosts, ports, paths, Chinese and protocol-relative URLs", () => {
  for (const [input, expected] of [
    ["example.com/a?q=1", "https://example.com/a?q=1"],
    ["localhost:8080/a", "https://localhost:8080/a"],
    ["127.0.0.1:8000", "https://127.0.0.1:8000/"],
    ["//example.com", "https://example.com/"],
    ["http://example.com", "http://example.com/"],
  ])
    assert.equal(webURL(input), expected);
  assert.match(webURL("例子.中国/目录"), /^https:\/\/xn--/);
  assert.throws(() => webURL("file://etc/passwd"));
});

import test, { after } from "node:test";
import assert from "node:assert/strict";
import { JSDOM } from "jsdom";
import { build } from "esbuild";
import os from "node:os";
import path from "node:path";
import fs from "node:fs/promises";
const output = path.join(os.tmpdir(), `studio-splitter-${process.pid}.mjs`);
await build({
  entryPoints: ["src/splitter.ts"],
  outfile: output,
  bundle: true,
  format: "esm",
  platform: "node",
  logLevel: "silent",
});
const { drag } = await import(output);
after(() => fs.rm(output, { force: true }));
function setup() {
  const dom = new JSDOM(
    '<div id="split" tabindex="0"></div><div id="outside"></div>',
  );
  const element = dom.window.document.getElementById("split");
  let end = 0;
  const points = [];
  drag(
    element,
    (x) => points.push(x),
    () => end++,
  );
  const send = (name, x, target = element) =>
    target.dispatchEvent(
      new dom.window.PointerEvent(name, {
        bubbles: true,
        button: 0,
        pointerId: 1,
        clientX: x,
      }),
    );
  return { dom, element, points, send, ends: () => end };
}
test("fast splitter drag commits the release point even when no final move event arrives", () => {
  const s = setup();
  s.send("pointerdown", 100);
  s.send("pointerup", 400, s.dom.window.document.getElementById("outside"));
  assert.deepEqual(s.points, [400]);
  assert.equal(s.ends(), 1);
  assert.equal(s.dom.window.document.activeElement, s.element);
  s.dom.window.close();
});
test("splitter continues outside the handle and removes its document listeners after release", () => {
  const s = setup();
  const outside = s.dom.window.document.getElementById("outside");
  s.send("pointerdown", 100);
  s.send("pointermove", 300, outside);
  s.send("pointerup", 400, outside);
  s.send("pointermove", 800, outside);
  assert.deepEqual(s.points, [300, 400]);
  assert.equal(s.ends(), 1);
  assert.equal(s.element.classList.contains("dragging"), false);
  s.dom.window.close();
});
test("pointer cancellation does not apply a bogus release position", () => {
  const s = setup();
  s.send("pointerdown", 100);
  s.send("pointermove", 200);
  s.send("pointercancel", 0);
  assert.deepEqual(s.points, [200]);
  assert.equal(s.ends(), 1);
  s.dom.window.close();
});

/** Bounded splitter gestures; no document-wide resize cursor or key interception. */
export function drag(
  element: HTMLElement,
  callback: (x: number) => void,
  end: () => void,
) {
  element.onpointerdown = (event) => {
    if (event.button !== 0) return;
    event.preventDefault();
    element.focus({ preventScroll: true });
    element.setPointerCapture?.(event.pointerId);
    element.classList.add("dragging");
    const doc = element.ownerDocument;
    const move = (e: PointerEvent) => {
      if (e.pointerId === event.pointerId) callback(e.clientX);
    };
    const up = (e: PointerEvent) => {
      if (e.pointerId !== event.pointerId) return;
      // Use the release point as well: fast/coalesced moves may omit the final move event.
      if (e.type !== "pointercancel") callback(e.clientX);
      element.classList.remove("dragging");
      doc.removeEventListener("pointermove", move);
      doc.removeEventListener("pointerup", up);
      doc.removeEventListener("pointercancel", up);
      end();
    };
    doc.addEventListener("pointermove", move);
    doc.addEventListener("pointerup", up);
    doc.addEventListener("pointercancel", up);
  };
  element.onkeydown = (event) => {
    if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      callback(
        element.getBoundingClientRect().x +
          (event.key === "ArrowLeft" ? -20 : 20),
      );
      end();
      event.preventDefault();
    }
  };
}

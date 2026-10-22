import type { Style } from "./types";
const sizes = [52, 40, 36, 28, 24, 20];
const colors = [
  "#0498b7",
  "#0498b7",
  "#29664a",
  "#087cba",
  "#df8d12",
  "#596d62",
];
export function applyVisualStyle(host: HTMLElement, style: Style) {
  host.style.background = style.background ?? "#ffffff";
  host.style.setProperty("--text-color", style.color ?? "#37434d");
  host.style.setProperty("--font-family", style.fontFamily ?? "system-ui");
  host.style.setProperty(
    "--paragraph-spacing",
    `${style.paragraphSpacing ?? 0.6}em`,
  );
  host.style.setProperty("--strong-color", style.strongColor ?? "#087b72");
  host.style.setProperty("--strong-size", `${style.strongSize ?? 18}px`);
  for (let i = 0; i < 6; i++) {
    host.style.setProperty(
      `--h${i + 1}-size`,
      `${style.headings?.[i]?.size ?? sizes[i]}px`,
    );
    host.style.setProperty(
      `--h${i + 1}-color`,
      style.headings?.[i]?.color ?? colors[i],
    );
  }
}
export function epubCSS(style: Style, zoom: number) {
  return `html,body{background:${style.background ?? "#ffffff"}!important;color:${style.color ?? "#37434d"}!important;}
body{font-size:${(style.fontSize * zoom) / 100}px!important;font-family:${style.fontFamily && !["system-ui", "serif", "sans-serif", "monospace"].includes(style.fontFamily) ? JSON.stringify(style.fontFamily) : (style.fontFamily ?? "system-ui")},sans-serif!important;line-height:${style.lineHeight}!important;}
body p,body li,body div,body span{color:inherit!important;font-family:inherit!important;font-size:inherit!important;line-height:inherit!important;}
p{margin-block:${style.paragraphSpacing ?? 0.6}em!important;text-align:${style.justify ? "justify" : "start"}!important;}
strong,b{color:${style.strongColor ?? "#087b72"}!important;}
${sizes.map((size, i) => `h${i + 1}{font-size:${((style.headings?.[i]?.size ?? size) * zoom) / 100}px!important;color:${style.headings?.[i]?.color ?? colors[i]}!important;font-family:inherit!important;line-height:1.4!important;text-align:start!important;}`).join("\n")}`;
}
/** Raster dimensions are PDF user-space points; DPR is the real display pixel ratio. */
export function bestPDFZoom(
  width: number,
  height: number,
  hostWidth: number,
  hostHeight: number,
  dpr: number,
  raster?: {
    width: number;
    height: number;
    pixelsWidth: number;
    pixelsHeight: number;
  },
) {
  const clamp = (n: number) => Math.max(25, Math.min(400, n));
  if (raster)
    return {
      zoom: clamp(
        (100 *
          Math.min(
            raster.pixelsWidth / raster.width,
            raster.pixelsHeight / raster.height,
          )) /
          Math.max(1, dpr),
      ),
      reason:
        "扫描页：按原图像素与当前屏幕倍率计算；超出范围时限制为 25%–400%。",
    };
  return {
    zoom: clamp(
      100 * Math.min((hostWidth - 48) / width, (hostHeight - 40) / height),
    ),
    reason:
      "此页未检测到覆盖主体的扫描图，使用完整页面显示；矢量页面没有唯一的最佳清晰度比例。",
  };
}

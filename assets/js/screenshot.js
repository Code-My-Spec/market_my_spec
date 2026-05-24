import { toCanvas } from "html-to-image";

export async function captureScreenshot() {
  // Suppress 404 noise from html-to-image trying to fetch url(#id) SVG refs
  const origFetch = window.fetch;
  window.fetch = function(input, init) {
    const url = typeof input === "string" ? input : input?.url || "";
    if (url.includes("%23") || url.includes("#")) {
      return Promise.resolve(new Response("", { status: 200 }));
    }
    return origFetch.call(this, input, init);
  };

  try {
    const canvas = await toCanvas(document.body, {
      pixelRatio: Math.min(window.devicePixelRatio, 2),
      skipFonts: true,
      width: window.innerWidth,
      height: window.innerHeight,
      style: {
        transform: `translate(-${window.scrollX}px, -${window.scrollY}px)`,
      },
      canvasWidth: window.innerWidth,
      canvasHeight: window.innerHeight,
      filter: (node) => {
        if (node.id === "cms-feedback") return false;
        return true;
      },
    });
    return canvas.toDataURL("image/png");
  } finally {
    window.fetch = origFetch;
  }
}

window.__captureScreenshot = captureScreenshot;

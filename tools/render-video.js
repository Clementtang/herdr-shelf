#!/usr/bin/env node
// Render assets/shelf-demo.svg to PNG frames through headless Chrome, and
// optionally to MP4 with ffmpeg.
//
//   node tools/render-video.js --at 3.5,11,14 --out /tmp/frames   # stills
//   node tools/render-video.js --fps 30 --mp4 assets/shelf-demo.mp4
//
// Every animation in the SVG shares one loop, so pausing all of them with a
// negative animation-delay freezes the exact instant; no real-time capture.
// Talks to Chrome over the DevTools protocol with Node's built-in WebSocket,
// so there is nothing to npm install.

const { spawn, execFileSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const SVG = path.join(__dirname, "..", "assets", "shelf-demo.svg");
const LOOP_SECONDS = 18;
const WIDTH = 1280;
const HEIGHT = 830;
const PORT = 9333;

function parseArgs() {
  const args = { fps: 30, at: null, out: null, mp4: null };
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i].replace(/^--/, "");
    args[key] = argv[i + 1];
  }
  args.fps = Number(args.fps);
  return args;
}

async function waitForTarget() {
  for (let attempt = 0; attempt < 50; attempt++) {
    try {
      const response = await fetch(`http://127.0.0.1:${PORT}/json/list`);
      const targets = await response.json();
      const page = targets.find((t) => t.type === "page");
      if (page) return page.webSocketDebuggerUrl;
    } catch {
      // Chrome is still starting.
    }
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  throw new Error(`Chrome did not expose a page on port ${PORT}`);
}

function connect(url) {
  const socket = new WebSocket(url);
  let nextId = 1;
  const pending = new Map();
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(JSON.stringify(message.error)));
      else resolve(message.result);
    }
  });
  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = nextId++;
      pending.set(id, { resolve, reject });
      socket.send(JSON.stringify({ id, method, params }));
    });
  return new Promise((resolve, reject) => {
    socket.addEventListener("open", () => resolve({ send, socket }));
    socket.addEventListener("error", reject);
  });
}

async function main() {
  const args = parseArgs();
  const times = args.at
    ? args.at.split(",").map(Number)
    : Array.from(
        { length: Math.round(LOOP_SECONDS * args.fps) },
        (_, i) => i / args.fps,
      );
  const outDir =
    args.out || fs.mkdtempSync(path.join(os.tmpdir(), "shelf-frames-"));
  fs.mkdirSync(outDir, { recursive: true });

  // Inline the SVG so the freeze stylesheet reaches its elements; an <img>
  // would sandbox them. Paused from the first paint: an animation that ran
  // before pausing keeps that elapsed time on top of the negative delay.
  const page = path.join(outDir, "page.html");
  fs.writeFileSync(
    page,
    `<html><body style="margin:0;background:#101118"><style>svg *{animation-play-state:paused!important}</style><style id="freeze"></style>${fs.readFileSync(SVG, "utf8")}</body></html>`,
  );

  const profile = fs.mkdtempSync(path.join(os.tmpdir(), "shelf-chrome-"));
  const chrome = spawn(CHROME, [
    "--headless=new",
    "--disable-gpu",
    "--hide-scrollbars",
    `--remote-debugging-port=${PORT}`,
    `--user-data-dir=${profile}`,
    `--window-size=${WIDTH},${HEIGHT}`,
    "about:blank",
  ]);

  try {
    const { send, socket } = await connect(await waitForTarget());
    await send("Emulation.setDeviceMetricsOverride", {
      width: WIDTH,
      height: HEIGHT,
      deviceScaleFactor: 1,
      mobile: false,
    });
    await send("Page.enable");
    await send("Page.navigate", { url: `file://${page}` });
    await new Promise((resolve) => setTimeout(resolve, 1000));

    for (let index = 0; index < times.length; index++) {
      const seconds = times[index];
      const css = `svg *{animation-play-state:paused!important;animation-delay:-${seconds}s!important}`;
      await send("Runtime.evaluate", {
        expression:
          `document.getElementById("freeze").textContent=${JSON.stringify(css)};` +
          "new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))",
        awaitPromise: true,
      });
      const shot = await send("Page.captureScreenshot", { format: "png" });
      const name = args.at
        ? `t${seconds}.png`
        : `frame-${String(index).padStart(4, "0")}.png`;
      fs.writeFileSync(
        path.join(outDir, name),
        Buffer.from(shot.data, "base64"),
      );
    }
    socket.close();
  } finally {
    chrome.kill();
  }

  if (args.mp4) {
    execFileSync("ffmpeg", [
      "-y",
      "-loglevel",
      "error",
      "-framerate",
      String(args.fps),
      "-i",
      path.join(outDir, "frame-%04d.png"),
      "-c:v",
      "libx264",
      "-pix_fmt",
      "yuv420p",
      "-crf",
      "18",
      "-movflags",
      "+faststart",
      args.mp4,
    ]);
    console.log(args.mp4);
  } else {
    console.log(outDir);
  }
}

main().catch((error) => {
  console.error(`render-video: ${error.message}`);
  process.exit(1);
});

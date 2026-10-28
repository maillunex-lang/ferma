// Renders every SVG produced by gen_art.py into a transparent PNG using the
// bundled Chromium (full SVG filter support: soft shadows, blur, gradients).
// Usage: node render.js <svg_dir> <project_root>
// Each SVG carries a data-out attribute with its destination path (relative to project root).
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const svgDir = process.argv[2];
  const root = process.argv[3];
  const only = process.argv[4] || '';
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const files = fs.readdirSync(svgDir).filter(f => f.endsWith('.svg') && f.includes(only)).sort();
  for (const f of files) {
    const svg = fs.readFileSync(path.join(svgDir, f), 'utf8');
    const out = /data-out="([^"]+)"/.exec(svg)[1];
    const w = parseInt(/width="(\d+)"/.exec(svg)[1]);
    const h = parseInt(/height="(\d+)"/.exec(svg)[1]);
    await page.setViewportSize({ width: w, height: h });
    await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
    const el = await page.$('svg');
    const dest = path.join(root, out);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    await el.screenshot({ path: dest, omitBackground: true });
    console.log('rendered', out, `${w}x${h}`);
  }
  await browser.close();
})();

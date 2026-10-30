'use strict';
// Actual UI.lua -> strict WoW mocks -> recorded frame/texture/font geometry -> SVG.
// This is a MOCK LAYOUT PREVIEW, not a WoW screenshot or native keyboard proof.
const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const luaparse = require('luaparse');
const root = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const value = (key, fallback) => args.includes(key) ? args[args.indexOf(key) + 1] : fallback;
const scene = value('--scene', 'solo');
if (!['solo', 'raid', 'boss', 'spectator', 'victory', 'brawl', 'hazard', 'ko', 'boss-patrol', 'boss-windup', 'boss-impact', 'hit-before', 'hit-impact', 'hit-settle', 'hit-reduced', 'hit-team', 'hit-shield', 'flow-watch', 'flow-fight', 'flow-info', 'flow-settings', 'flow-idle', 'flow-solo', 'flow-ai', 'flow-ai-settings'].includes(scene)) throw new Error('Unknown scene');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
function execute(source, name) {
  const bytes = to_luastring(source);
  let status = lauxlib.luaL_loadbuffer(L, bytes, bytes.length, to_luastring(name));
  if (status === lua.LUA_OK) status = lua.lua_pcall(L, 0, lua.LUA_MULTRET, 0);
  if (status !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
}
const tocVersion = fs.readFileSync(path.join(root, 'Rampage.toc'), 'utf8').match(/^## Version:\s*(\S+)/m)?.[1];
if (!tocVersion || !/^\d+\.\d+\.\d+$/.test(tocVersion)) throw new Error('Invalid TOC version');
execute(`unpack=table.unpack; TEST_COUNT=0; EXPECTED_VERSION='${tocVersion}'
function check(name,fn) local ok,err=pcall(fn); if not ok then error('FAIL: '..name..'\\n'..tostring(err),0) end TEST_COUNT=TEST_COUNT+1; print('PASS: '..name) end
function eq(a,b) assert(a==b,'expected '..tostring(b)..', got '..tostring(a)) end`, '@bootstrap');
const mockSource = fs.readFileSync(path.join(root, 'tests/wow-smoke.lua'), 'utf8');
luaparse.parse(mockSource, { luaVersion: '5.1' });
execute(mockSource, '@wow-mock');
const runtime = fs.readFileSync(path.join(root, 'Rampage.toc'), 'utf8').split(/\r?\n/).map(x => x.trim()).filter(x => x && !x.startsWith('#'));
for (const file of runtime) {
  const source = fs.readFileSync(path.join(root, file), 'utf8');
  luaparse.parse(source, { luaVersion: '5.1' });
  execute(`assert(load([====[${source}]====], '@${file}'))('Rampage',Addon)`, '@load-' + file);
}
if (args.includes('--smoke')) {
  execute('runWoWSmoke(); print("SMOKE PASSED: "..TEST_COUNT)', '@run-smoke');
  lua.lua_close(L);
  process.exit(0);
}
execute(`prepareWoWPreview('${scene}'); return captureWoWPreview()`, '@capture-actual-ui');
const capture = JSON.parse(to_jsstring(lua.lua_tostring(L, -1)));
lua.lua_close(L);
const esc = s => String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const num = n => Number(n.toFixed(2));
const fill = shape => `rgb(${[shape.r, shape.g, shape.b].map(n => Math.round(n * 255)).join(',')})`;
const layers = { BACKGROUND: 0, BORDER: 1, ARTWORK: 2, OVERLAY: 3, HIGHLIGHT: 4 };
capture.shapes.sort((a, b) => a.level - b.level || (layers[a.layer] ?? 2) - (layers[b.layer] ?? 2) || (a.sublevel ?? 0) - (b.sublevel ?? 0));
const shapes = capture.shapes.map(s => {
  if (s.kind === 'rect') return `<rect x="${num(s.x)}" y="${num(s.y)}" width="${num(s.w)}" height="${num(s.h)}" fill="${fill(s)}" opacity="${num(s.alpha)}"/>`;
  const align = s.align === 'CENTER' ? 'middle' : s.align === 'RIGHT' ? 'end' : 'start';
  const x = s.x + (s.align === 'CENTER' ? s.w / 2 : s.align === 'RIGHT' ? s.w : 0);
  return `<text x="${num(x)}" y="${num(s.y + s.size)}" font-family="Arial, sans-serif" font-size="${num(s.size)}" text-anchor="${align}" fill="${fill(s)}" opacity="${num(s.alpha)}">${s.text.split('\n').map((line, i) => `<tspan x="${num(x)}" dy="${i ? num(s.size * 1.4) : 0}">${esc(line)}</tspan>`).join('')}</text>`;
}).join('\n');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${capture.width}" height="${capture.height + 28}" viewBox="0 0 ${capture.width} ${capture.height + 28}"><title>Rampage actual UI mock — ${scene}</title><rect width="100%" height="100%" fill="#16121a"/>${shapes}<text x="12" y="${capture.height + 18}" fill="#baa98b" font-size="11" font-family="Arial,sans-serif">MOCK LAYOUT · real UI.lua geometry · ${esc(scene)} fixture · NOT a WoW screenshot / native input test</text></svg>`;
const output = value('--output', null);
if (output) {
  const file = path.resolve(output);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, svg);
  console.log(`Wrote actual-layout mock: ${file} (${capture.shapes.length} visible shapes)`);
} else process.stdout.write(svg);

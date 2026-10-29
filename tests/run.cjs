'use strict';
const fs = require('node:fs');
const path = require('node:path');
const luaparse = require('luaparse');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const root = path.resolve(__dirname, '..');
const toc = fs.readFileSync(path.join(root, 'Rampage.toc'), 'utf8');
const runtime = toc.split(/\r?\n/).map(x => x.trim()).filter(x => x && !x.startsWith('#'));
if (!toc.includes('## Interface: 20506')) throw new Error('Wrong TBC interface');
const tocVersion = toc.match(/^## Version:\s*(\S+)/m)?.[1];
if (!tocVersion || !/^\d+\.\d+\.\d+$/.test(tocVersion)) throw new Error('Invalid TOC release version');
if (runtime.some(x => !x.endsWith('.lua') || !fs.existsSync(path.join(root, x)))) throw new Error('Missing TOC file');
const suites = { model: 'tests/model.lua', protocol: 'tests/protocol.lua', wow: 'tests/wow-smoke.lua' };
const suite = process.argv.find(x => x.startsWith('--suite='))?.split('=')[1];
if (suite && !suites[suite]) throw new Error('Unknown suite: ' + suite);
const tests = suite ? [suites[suite]] : Object.values(suites);
const selectedRuntime = suite && suite !== 'wow' ? runtime.slice(0, 2) : runtime;
for (const file of [...selectedRuntime, ...tests]) {
  luaparse.parse(fs.readFileSync(path.join(root, file), 'utf8'), { luaVersion: '5.1' });
  console.log(`Lua 5.1 syntax OK: ${file}`);
}
if (process.argv.includes('--parse-only')) process.exit(0);
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
function execute(source, label) {
  const bytes = to_luastring(source);
  let status = lauxlib.luaL_loadbuffer(L, bytes, bytes.length, to_luastring(label));
  if (status === lua.LUA_OK) status = lua.lua_pcall(L, 0, lua.LUA_MULTRET, 0);
  if (status !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
}
function moduleSource(file) {
  return `assert(load([====[${fs.readFileSync(path.join(root, file), 'utf8')}]====], '@${file}'))('Rampage', Addon)\n`;
}
execute(`
  unpack = table.unpack -- Fengari uses Lua 5.3; WoW supplies Lua 5.1 unpack.
  Addon = {}
  TEST_COUNT = 0
  EXPECTED_VERSION = '${tocVersion}'
  function check(name, run)
    local ok, err = pcall(run)
    if not ok then error('FAIL: ' .. name .. '\\n' .. tostring(err), 0) end
    TEST_COUNT = TEST_COUNT + 1
    print('PASS: ' .. name)
  end
  function eq(actual, expected, message)
    assert(actual == expected, (message or 'values differ') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
  end
`, '@test-bootstrap');
for (const file of runtime.slice(0, 2)) execute(moduleSource(file), '@load-' + file);
for (const file of tests.filter(x => x !== suites.wow)) execute(fs.readFileSync(path.join(root, file), 'utf8'), '@' + file);
if (tests.includes(suites.wow)) {
  // Smoke test defines API mocks before exercising the real TOC load order in a fresh addon namespace.
  execute(fs.readFileSync(path.join(root, suites.wow), 'utf8'), '@' + suites.wow);
  for (const file of runtime) execute(moduleSource(file), '@toc-' + file);
  execute('runWoWSmoke()', '@wow-finish');
}
execute('print("ALL " .. TEST_COUNT .. " TESTS PASSED (Fengari Lua 5.3 semantics; separate Lua 5.1 syntax checks above)")', '@finish');
lua.lua_close(L);

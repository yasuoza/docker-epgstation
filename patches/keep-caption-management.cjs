const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const moduleRoot = process.argv[2];
assert(moduleRoot, 'arib-subtitle-timedmetadaterのディレクトリが必要です');
const manifest = JSON.parse(fs.readFileSync(path.join(moduleRoot, 'package.json'), 'utf8'));
assert.equal(manifest.version, '4.0.10', '依存更新時は字幕管理情報の処理を再確認してください');

const target = path.join(moduleRoot, 'dist/index.js');
const source = fs.readFileSync(target, 'utf8');
const before = 'if ((data_group_id & 0x0F) != 1) { // FIXME!';
assert.equal(source.split(before).length, 2, '字幕フィルターの実装が変わっています');

// aribb24.js 2.xは管理情報を受信してから本文を復号する。先頭言語の本文(1)に加え、
// 元のPTSを持つ管理情報(0)もID3化しないと、v3のHLS字幕が表示されない。
const after = '// aribb24.js 2.x requires CaptionManagement (0) before CaptionStatement (1).\n' +
    '          if ((data_group_id & 0x0F) > 1) {';
fs.writeFileSync(target, source.replace(before, after));

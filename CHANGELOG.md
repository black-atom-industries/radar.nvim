# Changelog

## [0.6.0](https://github.com/black-atom-industries/radar.nvim/compare/v0.5.0...v0.6.0) (2026-05-15)


### Features

* add git and LSP indicators to radar view ([e9615d9](https://github.com/black-atom-industries/radar.nvim/commit/e9615d97dedb78c7d5c7382401a8091a39f2b624))
* align tabs and edit windows to radar's row position ([2b8fe33](https://github.com/black-atom-industries/radar.nvim/commit/2b8fe3385ee35c077f59cf2ebcda9ac417ec5e6b))
* **config:** add win_preset to radar config ([c6e0f49](https://github.com/black-atom-industries/radar.nvim/commit/c6e0f49b3dba578c14be73e548f4e8f4e0bc058e))
* **radar:** add 't' key to open tabs sidebar from radar window ([103fafd](https://github.com/black-atom-industries/radar.nvim/commit/103fafde9aac77e6064e832caec0bea97b864f76))
* **radar:** add structural highlights and solid background to unified window ([849e01c](https://github.com/black-atom-industries/radar.nvim/commit/849e01ca431a7c7cde5ec766855a4f5d2c804f26))
* **radar:** replace multi-window grid with unified single-window layout ([94b4cd2](https://github.com/black-atom-industries/radar.nvim/commit/94b4cd2ba9d0b8dd94a042f75c77f5d4a7f59f0d))
* replace footer hints with '?' help popup ([04ace3d](https://github.com/black-atom-industries/radar.nvim/commit/04ace3d171b635d19d54f529c2fa3c8ce8ad0be2))
* **tabs:** add 'r' key to return to radar from tabs sidebar ([b173d0a](https://github.com/black-atom-industries/radar.nvim/commit/b173d0a6b183f40a027ff8aadf0099802b5f1d79))
* **tabs:** add bold + background styling to tab header lines ([bfcef9e](https://github.com/black-atom-industries/radar.nvim/commit/bfcef9e27e54f716045f1cbbdd49c6c9f5c25743))
* **tabs:** add cut/paste (dd/p/P) for rearranging tabs and buffers ([2547904](https://github.com/black-atom-industries/radar.nvim/commit/254790460347d8c0040cec3ac743f3851d28e513))
* **tabs:** add n key to create new tab/vertical split ([c604fc0](https://github.com/black-atom-industries/radar.nvim/commit/c604fc01b913e46519f7163bbf710dd9be7ee1dd))
* **tabs:** add o key for only/tabonly and border footer with hints ([e68edca](https://github.com/black-atom-industries/radar.nvim/commit/e68edcaf9fe6aa3258288ee0f15f68b82009572f))
* **tabs:** add solid border to tabs window ([8fd2623](https://github.com/black-atom-industries/radar.nvim/commit/8fd2623399cb058e189808b9db2984073af8203a))
* **tabs:** add v for vsplit, s for hsplit on buffer lines; n is now only for new tab ([94e4c35](https://github.com/black-atom-industries/radar.nvim/commit/94e4c3566a56987a354f01b2b0584fca3778688c))
* **tabs:** left-align border title with icon ([067fe01](https://github.com/black-atom-industries/radar.nvim/commit/067fe01582522a717a24bdf8ed3730037df97ccb))
* **tabs:** open with cursor on the current buffer's line ([16e4bb4](https://github.com/black-atom-industries/radar.nvim/commit/16e4bb47799f1f27d8ef9ffb31a7464c398b7735))
* **tabs:** style indicator badges with theme-derived pill/badge colors ([b7fcb13](https://github.com/black-atom-industries/radar.nvim/commit/b7fcb135b680a934c068236422fe38910e1dee3d))
* **ui:** add configurable padding to radar window, use presets ([a514010](https://github.com/black-atom-industries/radar.nvim/commit/a5140107d97d4093c76915734bc7489f5d49c7d6))
* **ui:** add even left/right padding to radar window ([006aacd](https://github.com/black-atom-industries/radar.nvim/commit/006aacd0090e37d1fbe792141990bd7132fd9f83))
* **ui:** make radar grid responsive to terminal size ([a9b3da3](https://github.com/black-atom-industries/radar.nvim/commit/a9b3da374aaf71ad7aa9bebe55176071769cbce9))


### Bug Fixes

* **ci:** remove last-release-sha, use v0.5.0 tag as anchor instead ([1eeb56b](https://github.com/black-atom-industries/radar.nvim/commit/1eeb56b6ebc26598aa4acd58b11db768d08d6d1e))
* **indicators:** add neutral bracket color in indicator pills ([6c624a4](https://github.com/black-atom-industries/radar.nvim/commit/6c624a4701a251a0079eba64108f78c5e754ed9c))
* **radar:** color key labels, clean up alt line, fix footer and spacing ([e9c18b1](https://github.com/black-atom-industries/radar.nvim/commit/e9c18b12755c9a4830ff31a992184f4d99ac8b54))
* **radar:** fix off-by-one in current file highlight for lock and recent entries ([22c8cf7](https://github.com/black-atom-industries/radar.nvim/commit/22c8cf7723958fd1fe7c34156b01a7ff6f1eb99f))
* **radar:** left-align window border title ([19ef6b9](https://github.com/black-atom-industries/radar.nvim/commit/19ef6b924b7f93e3139f69cb3d234c171daec30b))
* **radar:** lock file under cursor instead of source buffer ([c0279de](https://github.com/black-atom-industries/radar.nvim/commit/c0279de4ac0deff3eb6b5624d15a6570b06194c8))
* **radar:** position cursor on current buffer when opening ([3d1687c](https://github.com/black-atom-industries/radar.nvim/commit/3d1687cb91f37fe12641cfaeec1bdaaf0eac3547))
* **radar:** remove double header, fix footer overflow, use content width ([6179757](https://github.com/black-atom-industries/radar.nvim/commit/6179757ddb7ab00a2185f2ffb5f6a9a89a07355b))
* **radar:** remove inline radar header, use content width for all text ([b35db6f](https://github.com/black-atom-industries/radar.nvim/commit/b35db6fc272d9c656ec95a42c3b123f23d834f2f))
* **tabs:** adjust tab header colors and add StyLua pre-commit hook ([12b751a](https://github.com/black-atom-industries/radar.nvim/commit/12b751a26d7341a7472500b1881abcd556838816))
* **tabs:** restore focus to floating window after paste, add cut line highlight ([82e620b](https://github.com/black-atom-industries/radar.nvim/commit/82e620bce8d074363a74a9b8719ab9e9ee969d9b))
* **ui:** correct radar padding and window presets ([391c8f3](https://github.com/black-atom-industries/radar.nvim/commit/391c8f3770dcbc350db80b4ce19a841161989cd3))
* **ui:** harden edit buffer cleanup against ghost buffer names ([d3e4112](https://github.com/black-atom-industries/radar.nvim/commit/d3e4112bcc63765e14609fcf89f43905271c8c95))


### Documentation

* add development dependencies section to README ([c5c8736](https://github.com/black-atom-industries/radar.nvim/commit/c5c87361785c0d031286db473ebcfcbff7ec7313))
* reformat configuration table in README.md ([39199d3](https://github.com/black-atom-industries/radar.nvim/commit/39199d331ad779cd7527fc28aac3a77f179a2b07))
* update README and AGENTS.md to reflect current codebase ([5bcd9cb](https://github.com/black-atom-industries/radar.nvim/commit/5bcd9cb99344989531896ee32f666315b5acf584))

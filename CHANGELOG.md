# Changelog

## [0.6.0](https://github.com/black-atom-industries/radar.nvim/compare/v0.5.0...v0.6.0) (2026-10-16)


### ⚠ BREAKING CHANGES

* **ui:** hud.icons is gone.
* <space><space> no longer opens anything. The radar.* options (except the recent cap) and keys.vertical, keys.horizontal, keys.tab, keys.float and keys.line.* are gone. radar.max_recent_files moves to recent.max_files.
* **ui:** hud.width is gone; the pane width decides the HUD width.
* **keys:** <space><Tab> and - no longer open the alternative file; use <space>o outside and o inside the radar.
* **ui:** <space><space> opens the radar instead of the alternative file, and keys.alternative defaults to "-" inside the radar.

### Features

* add git and LSP indicators to radar view ([e9615d9](https://github.com/black-atom-industries/radar.nvim/commit/e9615d97dedb78c7d5c7382401a8091a39f2b624))
* align tabs and edit windows to radar's row position ([2b8fe33](https://github.com/black-atom-industries/radar.nvim/commit/2b8fe3385ee35c077f59cf2ebcda9ac417ec5e6b))
* **autocmd:** reload locks and recent files on directory change ([6942cf4](https://github.com/black-atom-industries/radar.nvim/commit/6942cf4a4f4c870cf04a1201d9fdfcebf59d4ffe))
* **config:** add win_preset to radar config ([c6e0f49](https://github.com/black-atom-industries/radar.nvim/commit/c6e0f49b3dba578c14be73e548f4e8f4e0bc058e))
* **keys:** edit locks and show help straight from the prefix ([690a504](https://github.com/black-atom-industries/radar.nvim/commit/690a5048048075fc3f9f71e3987bb0f680eef34e))
* **keys:** open the alternative file with o ([9e63c7a](https://github.com/black-atom-industries/radar.nvim/commit/9e63c7a859eec6c838261cfea4f5e2761fa2e165))
* **locks:** relabel locks by position after a removal ([#11](https://github.com/black-atom-industries/radar.nvim/issues/11)) ([a489e3a](https://github.com/black-atom-industries/radar.nvim/commit/a489e3a016d2b02cf6203d1c59102f7c7716f57b))
* **radar:** add 't' key to open tabs sidebar from radar window ([103fafd](https://github.com/black-atom-industries/radar.nvim/commit/103fafde9aac77e6064e832caec0bea97b864f76))
* **radar:** add structural highlights and solid background to unified window ([849e01c](https://github.com/black-atom-industries/radar.nvim/commit/849e01ca431a7c7cde5ec766855a4f5d2c804f26))
* **radar:** replace multi-window grid with unified single-window layout ([94b4cd2](https://github.com/black-atom-industries/radar.nvim/commit/94b4cd2ba9d0b8dd94a042f75c77f5d4a7f59f0d))
* **recent:** keep recent files per project and branch ([aa225b8](https://github.com/black-atom-industries/radar.nvim/commit/aa225b8ba005b7265d6601c5cb98e9f4e4a4bdf2))
* replace footer hints with '?' help popup ([04ace3d](https://github.com/black-atom-industries/radar.nvim/commit/04ace3d171b635d19d54f529c2fa3c8ce8ad0be2))
* replace the radar window with the HUD and the &lt;space&gt; prefix ([9e52a94](https://github.com/black-atom-industries/radar.nvim/commit/9e52a9416c0604a99882705ce59cb4adab9f362f))
* support Oil directory buffers in locks and recent files ([7d1d76a](https://github.com/black-atom-industries/radar.nvim/commit/7d1d76a115dbb9efe9eed31c9be75fcbd5dd8179))
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
* **ui:** anchor the HUD to the bottom of the active pane ([d95f9a7](https://github.com/black-atom-industries/radar.nvim/commit/d95f9a7eb63fd518c439b99b839d8e4263c3dee9))
* **ui:** dodge to the bottom center and prefer it with a vertical split ([7c846be](https://github.com/black-atom-industries/radar.nvim/commit/7c846be14a72e05f782840e9586b6dd0fcc8888d))
* **ui:** give the HUD a fixed width ([404ac4d](https://github.com/black-atom-industries/radar.nvim/commit/404ac4da4459e9e059170929c8f2408991f24ee0))
* **ui:** keep locks in sight with a corner HUD and a &lt;space&gt; prefix ([#8](https://github.com/black-atom-industries/radar.nvim/issues/8)) ([1971253](https://github.com/black-atom-industries/radar.nvim/commit/1971253856d682b44b18bff239a5fe4f93ce033a))
* **ui:** keep the HUD visible next to the radar ([1f275dc](https://github.com/black-atom-industries/radar.nvim/commit/1f275dc35120dc1954147b148329170633c0fa2b))
* **ui:** make radar grid responsive to terminal size ([a9b3da3](https://github.com/black-atom-industries/radar.nvim/commit/a9b3da374aaf71ad7aa9bebe55176071769cbce9))
* **ui:** mark HUD lines with their section icon ([009ee6a](https://github.com/black-atom-industries/radar.nvim/commit/009ee6a308a2d694c9f05836bddc9ed6650cecf1))
* **ui:** reserve the alternative line and space the HUD sections ([8c5a8da](https://github.com/black-atom-industries/radar.nvim/commit/8c5a8da6b788401f2ae4840bf36556c339bce652))
* **ui:** show bare keys in the HUD gutter ([5a560fa](https://github.com/black-atom-industries/radar.nvim/commit/5a560fa09ab8658f48d72dadb6398adfc9409f2c))
* **ui:** show the current file at the top of the HUD ([425c84d](https://github.com/black-atom-industries/radar.nvim/commit/425c84dfbaee31fe925b0043c33efb167218401a))
* **ui:** widen the HUD to 50 cells by default ([0271bae](https://github.com/black-atom-industries/radar.nvim/commit/0271bae4b1f329f1adc502838f74e95c1021b600))
* **ui:** widen the HUD to 64 cells by default ([a9902bf](https://github.com/black-atom-industries/radar.nvim/commit/a9902bf6b1f8819ebd80d3c09c5436e64537bcbe))


### Refactors

* architecture deepening — help popup, file float, persistence seam, state encapsulation ([1b3e10c](https://github.com/black-atom-industries/radar.nvim/commit/1b3e10c6f2a78326b6762ebf89291f5c53ed1e92))
* drop dead code and build the help from configured keys ([2f07a3c](https://github.com/black-atom-industries/radar.nvim/commit/2f07a3c513d834b1dacec1259a0d1e47b4811c80))
* reorganize into ui/, data/, persist/ folders ([52355c8](https://github.com/black-atom-industries/radar.nvim/commit/52355c80697d6ed4b58c9a81c89cd9381df91ceb))
* **ui:** scope indicator_sections and fix module loading ([3ac67a4](https://github.com/black-atom-industries/radar.nvim/commit/3ac67a44f7a14062df1609a4989863cd46be3fcf))


### Bug Fixes

* **alternative:** return nil when no alternate buffer exists ([4cd41f1](https://github.com/black-atom-industries/radar.nvim/commit/4cd41f1160adc61a38fa2e005187277bd05ef0ec))
* **ci:** remove last-release-sha, use v0.5.0 tag as anchor instead ([1eeb56b](https://github.com/black-atom-industries/radar.nvim/commit/1eeb56b6ebc26598aa4acd58b11db768d08d6d1e))
* **debug:** implement buffered logging with config gating ([f83f95f](https://github.com/black-atom-industries/radar.nvim/commit/f83f95f58da8db1f72506c50334ecda0fd102b88))
* **indicators:** add neutral bracket color in indicator pills ([6c624a4](https://github.com/black-atom-industries/radar.nvim/commit/6c624a4701a251a0079eba64108f78c5e754ed9c))
* **locks:** remove locks whose file no longer exists ([0f3cb7b](https://github.com/black-atom-industries/radar.nvim/commit/0f3cb7b004edf271651146f5cdd565088d9f1f55))
* **persistence:** keep locks tied to the project and branch they belong to ([dda3f24](https://github.com/black-atom-industries/radar.nvim/commit/dda3f249df4e994ae2b49d54bf9a12680775e08a))
* **persistence:** key projects by git root and store root-relative paths ([0b3e379](https://github.com/black-atom-industries/radar.nvim/commit/0b3e379ed4f57ece8a76482a28ab85415e7d6922))
* **persistence:** never let a deferred lock save overwrite a newer one ([f68a66d](https://github.com/black-atom-industries/radar.nvim/commit/f68a66d9a2d14d3afe34c49200d65e4ef1bdbdca))
* **persistence:** never lose saved locks to a bad read or write ([d379ed9](https://github.com/black-atom-industries/radar.nvim/commit/d379ed9c79f02ec9cd34d3d1849985140730e4bc))
* **persistence:** relabel locks by position when loading ([a268229](https://github.com/black-atom-industries/radar.nvim/commit/a26822929d2cec908f20d7c414beb3b691b352cf))
* **persistence:** resolve the git branch inside worktrees ([7433128](https://github.com/black-atom-industries/radar.nvim/commit/7433128e90da3b8907215555c86d093fb43b960e))
* **radar:** color key labels, clean up alt line, fix footer and spacing ([e9c18b1](https://github.com/black-atom-industries/radar.nvim/commit/e9c18b12755c9a4830ff31a992184f4d99ac8b54))
* **radar:** fix off-by-one in current file highlight for lock and recent entries ([22c8cf7](https://github.com/black-atom-industries/radar.nvim/commit/22c8cf7723958fd1fe7c34156b01a7ff6f1eb99f))
* **radar:** left-align window border title ([19ef6b9](https://github.com/black-atom-industries/radar.nvim/commit/19ef6b924b7f93e3139f69cb3d234c171daec30b))
* **radar:** lock file under cursor instead of source buffer ([c0279de](https://github.com/black-atom-industries/radar.nvim/commit/c0279de4ac0deff3eb6b5624d15a6570b06194c8))
* **radar:** position cursor on current buffer when opening ([3d1687c](https://github.com/black-atom-industries/radar.nvim/commit/3d1687cb91f37fe12641cfaeec1bdaaf0eac3547))
* **radar:** remove double header, fix footer overflow, use content width ([6179757](https://github.com/black-atom-industries/radar.nvim/commit/6179757ddb7ab00a2185f2ffb5f6a9a89a07355b))
* **radar:** remove inline radar header, use content width for all text ([b35db6f](https://github.com/black-atom-industries/radar.nvim/commit/b35db6fc272d9c656ec95a42c3b123f23d834f2f))
* **recent:** keep the current file in NEAR when no alternate exists ([64b47bc](https://github.com/black-atom-industries/radar.nvim/commit/64b47bc1590d4a7fbf03622b747a25fbfe1ce1a0))
* **recent:** leave the current file out of recent files ([9d8a962](https://github.com/black-atom-industries/radar.nvim/commit/9d8a9628cea7676d1655285db2042784734d7e42))
* **recent:** leave the current file out of recent files ([507137f](https://github.com/black-atom-industries/radar.nvim/commit/507137f6ba8477b6681dd3e901b9d73508226432))
* **recent:** use stored source alt file for consistent exclusion ([20ebbb9](https://github.com/black-atom-industries/radar.nvim/commit/20ebbb9b60d6b7308dc295d998b78697c6d3cf07))
* **tabs:** adjust tab header colors and add StyLua pre-commit hook ([12b751a](https://github.com/black-atom-industries/radar.nvim/commit/12b751a26d7341a7472500b1881abcd556838816))
* **tabs:** restore focus to floating window after paste, add cut line highlight ([82e620b](https://github.com/black-atom-industries/radar.nvim/commit/82e620bce8d074363a74a9b8719ab9e9ee969d9b))
* **ui:** correct radar padding and window presets ([391c8f3](https://github.com/black-atom-industries/radar.nvim/commit/391c8f3770dcbc350db80b4ce19a841161989cd3))
* **ui:** dodge the cursor line, not just the cursor cell ([cce0f6a](https://github.com/black-atom-industries/radar.nvim/commit/cce0f6a28eb4680dc5347743d390ab7f1500d5e1))
* **ui:** fit the HUD inside its pane and keep it under other floats ([61a880c](https://github.com/black-atom-industries/radar.nvim/commit/61a880c5f1a6efc35db992743f1ed2c2b26ed7ac))
* **ui:** harden edit buffer cleanup against ghost buffer names ([d3e4112](https://github.com/black-atom-industries/radar.nvim/commit/d3e4112bcc63765e14609fcf89f43905271c8c95))
* **ui:** keep the current file among the HUD locks, highlighted ([5f12e76](https://github.com/black-atom-industries/radar.nvim/commit/5f12e76f640e7fe021127edfcab8b5b76074c993))
* **ui:** keep the HUD opaque under a global winblend ([1216902](https://github.com/black-atom-industries/radar.nvim/commit/121690261254f7094d9d0e517f5b7fbcca283fb8))
* **ui:** leave the current file out of the HUD ([e4bf764](https://github.com/black-atom-industries/radar.nvim/commit/e4bf764cff7eef89deced90656d92cead313f246))
* **ui:** render the radar in place and map lines to entries once ([81b4755](https://github.com/black-atom-industries/radar.nvim/commit/81b4755bbe49515d9b1c9fdf127791683d31cf95))
* **ui:** reserve the HUD's recent slots ([eb49d5c](https://github.com/black-atom-industries/radar.nvim/commit/eb49d5cc63ef7d8546b0d7fba6786ecd1b194673))
* **ui:** skip stale file entries in locks section ([0e096f2](https://github.com/black-atom-industries/radar.nvim/commit/0e096f2fcac40b25b41686f3e5fa29e20213a5bf))


### Documentation

* add development dependencies section to README ([c5c8736](https://github.com/black-atom-industries/radar.nvim/commit/c5c87361785c0d031286db473ebcfcbff7ec7313))
* describe the single radar window and git-root persistence ([819f4a2](https://github.com/black-atom-industries/radar.nvim/commit/819f4a259c2f77aef7f4d5938eb9d3a95cace643))
* drop the screenshots of the removed radar window ([201913d](https://github.com/black-atom-industries/radar.nvim/commit/201913db0e5590c478bb590c7dd215d6073cbe81))
* reformat configuration table in README.md ([39199d3](https://github.com/black-atom-industries/radar.nvim/commit/39199d331ad779cd7527fc28aac3a77f179a2b07))
* show the HUD in the README with clips and a still ([50ad1bb](https://github.com/black-atom-industries/radar.nvim/commit/50ad1bb998ac16a3c27659c18fb4b5dfd91b4333))
* update README and AGENTS.md to reflect current codebase ([5bcd9cb](https://github.com/black-atom-industries/radar.nvim/commit/5bcd9cb99344989531896ee32f666315b5acf584))


### Performance

* **init:** defer persistence loading until after startup ([aa82337](https://github.com/black-atom-industries/radar.nvim/commit/aa8233749aac2e67141297c2ab2d454a9f70e997))
* **persistence:** read git branch from .git/HEAD instead of spawning git ([7eed534](https://github.com/black-atom-industries/radar.nvim/commit/7eed534ef3f756dae0378c0fe36cd9e01d22fe37))

## Changelog

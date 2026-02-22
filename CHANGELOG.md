# Changelog

## [1.0.0](https://github.com/black-atom-industries/radar.nvim/compare/v0.5.0...v1.0.0) (2026-02-22)


### ⚠ BREAKING CHANGES

* **config:** Configuration structure has been completely restructured

### refactor

* **config:** flatten config structure and implement window preset system ([7fd415c](https://github.com/black-atom-industries/radar.nvim/commit/7fd415cab6ddc116d540e7ddb4925f24359a5f74))


### Features

* add center_large preset and set as file_float default ([da09522](https://github.com/black-atom-industries/radar.nvim/commit/da0952297de8b344a9fe31c577a5f2b0cb34b052))
* add cleanup command to remove stale persistence data ([bc87caf](https://github.com/black-atom-industries/radar.nvim/commit/bc87caf7bc911aeab1e447c29c807df1a32fadc3))
* add grid view ([dfaf81f](https://github.com/black-atom-industries/radar.nvim/commit/dfaf81fbb4bec13290b7af569a7010fefea1e210))
* add lastAccessed tracking and data versioning ([216de96](https://github.com/black-atom-industries/radar.nvim/commit/216de96be56b116fb8cb7aa2538b50647e63b9b1))
* add union types for preset names ([0edf82f](https://github.com/black-atom-industries/radar.nvim/commit/0edf82f9e8e8c0c9e4f98c084c5c4b996e948470))
* add win_opts to window configs ([5cd9859](https://github.com/black-atom-industries/radar.nvim/commit/5cd9859b7128287fe81c201bfef45c0eb60ca104))
* add x keymap to close windows/tabs from tabs view ([7a4037d](https://github.com/black-atom-industries/radar.nvim/commit/7a4037d76c21ae3bfae74ba01a516d436d8dae25))
* **alternative:** add alternative file navigation support ([6223260](https://github.com/black-atom-industries/radar.nvim/commit/6223260ed94e412ae3e279f88384001613bf9bd4))
* **collision:** implement floating window collision detection ([e179871](https://github.com/black-atom-industries/radar.nvim/commit/e179871c3bfc5a94a1d20c17b23e6c03b7d00704))
* **collision:** implement floating window collision detection ([4590033](https://github.com/black-atom-industries/radar.nvim/commit/4590033745120d7ad29348ca55c944adcd9fa7ff))
* **config:** change alternative keymap from &lt;space&gt; to o ([d44e96f](https://github.com/black-atom-industries/radar.nvim/commit/d44e96f5ebd6ac162bf7bac49ef3f3cbd0197d1f))
* **core:** add path utilities, testing infrastructure, and development tools ([42afd45](https://github.com/black-atom-industries/radar.nvim/commit/42afd45cc1c3d42cbcd2827bf03ed7e86ea38708))
* ensure fully deterministic JSON output ([8919de9](https://github.com/black-atom-industries/radar.nvim/commit/8919de99534218a4976e7bf7f8fdcfdd784900ff))
* improve edit mode, protocol URL support, and alternative key ([6036f70](https://github.com/black-atom-industries/radar.nvim/commit/6036f709f252ce8fe52d65a1470013cdbe9239a8))
* initial commit ([77961de](https://github.com/black-atom-industries/radar.nvim/commit/77961de1d60d3834f9105e9c05a268370d48bf07))
* **keys:** add line-based navigation keymaps ([54d705a](https://github.com/black-atom-industries/radar.nvim/commit/54d705a080347b187c3f0acccd5fb6a65eb460d5))
* maintain alphabetical project sorting in persistence ([6f52154](https://github.com/black-atom-industries/radar.nvim/commit/6f521545edd041694de9ab7a6bfbccf98fef6479))
* **makefile:** add comprehensive check target for project validation ([595cc8e](https://github.com/black-atom-industries/radar.nvim/commit/595cc8eead8096096d9e8fd5cdb7cce3b2b50fdb))
* **navigation:** add floating window file editing support ([c9e7900](https://github.com/black-atom-industries/radar.nvim/commit/c9e7900569692f8c9ace2f2a7e047854f56cd6a7))
* **radar:** add dynamic window width calculation for locks editor ([eb4d23b](https://github.com/black-atom-industries/radar.nvim/commit/eb4d23b0d52dd4f8bde721f1703314f72ddb49cb))
* **radar:** add file navigation keymaps for locks editor ([b5698fa](https://github.com/black-atom-industries/radar.nvim/commit/b5698fa53aacfc1c717946603a255cc8d7d83c49))
* **radar:** add get_formatted_filepath helper function ([6dcb401](https://github.com/black-atom-industries/radar.nvim/commit/6dcb401c366ab1d6c18c3674284e50a09c5773c7))
* **radar:** add keymap to edit radar data file directly ([5286208](https://github.com/black-atom-industries/radar.nvim/commit/5286208d7291e0c23373c913074cfb26d30ae3b6))
* **radar:** add locks editor with floating window buffer ([cddbd38](https://github.com/black-atom-industries/radar.nvim/commit/cddbd38d056381868aa38d11b9a0521fe9996f27))
* **radar:** add multi-window open modes for locks ([12edc4e](https://github.com/black-atom-industries/radar.nvim/commit/12edc4eac0fd4ff36c002b22946cfde44f5aa640))
* **radar:** add navigation modifier keys for lock opening ([793488a](https://github.com/black-atom-industries/radar.nvim/commit/793488ad648a6ae169b34068f4fc8cbb34425cd3))
* **radar:** add optional JSON file formatting with prettier ([329ff9e](https://github.com/black-atom-industries/radar.nvim/commit/329ff9e9a46f27ebbdcbd23c4502fe015b78d573))
* **radar:** add recent files tracking and navigation support ([f0e57f8](https://github.com/black-atom-industries/radar.nvim/commit/f0e57f8c51ed3ec37699d87866de851e10f4d80d))
* **radar:** add section headers for locks and recent files ([4c40b8e](https://github.com/black-atom-industries/radar.nvim/commit/4c40b8eb934524c396b1898c4f202a6d7b1ca9f3))
* **radar:** add window transparency configuration ([b6d4cbc](https://github.com/black-atom-industries/radar.nvim/commit/b6d4cbc0f0804f5ebafd08869545c47059a08d03))
* **radar:** always show window even when empty ([52dee17](https://github.com/black-atom-industries/radar.nvim/commit/52dee17af4fecab7f9be39491ef5e828e77fe36c))
* **radar:** increase default window transparency ([be13eb9](https://github.com/black-atom-industries/radar.nvim/commit/be13eb9bd015c9007789f4786fefdfeb44f75ae5))
* **radar:** increase grid width, add border config, and show unmapped recent files ([a6df0c3](https://github.com/black-atom-industries/radar.nvim/commit/a6df0c3bb3dd295c6f1b60769c3a8397a175c641))
* **radar:** update header highlighting for locked files section ([ee5883e](https://github.com/black-atom-industries/radar.nvim/commit/ee5883eec52b9975d747ccb635ba6325dd542183))
* **radar:** update window titles and glyphs for enhanced readability ([0355209](https://github.com/black-atom-industries/radar.nvim/commit/0355209368697b08ba2589ffb65ae1576b005593))
* restructure ([684fdf2](https://github.com/black-atom-industries/radar.nvim/commit/684fdf2b83e681fda6ca24f43f0744139acd3380))


### Bug Fixes

* address code review issues before merge ([b98cf68](https://github.com/black-atom-industries/radar.nvim/commit/b98cf689f3e41371846be8329abd206f1f55f17b))
* **autocmd:** improve session loading and recent file tracking ([9bcae68](https://github.com/black-atom-industries/radar.nvim/commit/9bcae687d4569b835ed8a1d85bce0e6e1564f8a1))
* **ci:** add last-release-sha to ignore historical breaking changes ([d5306ef](https://github.com/black-atom-industries/radar.nvim/commit/d5306ef7843f1ebfc693dc7c4697d444731ae2f8))
* close radar window when opening edit window ([fa621a7](https://github.com/black-atom-industries/radar.nvim/commit/fa621a70230b8fe13b986a55f944800fa260dbce))
* **collision:** remove unnecessary config parameter in collision check ([3d84f3f](https://github.com/black-atom-industries/radar.nvim/commit/3d84f3fc431511f47f93d611b7b95c6b98b62c79))
* **config:** adjust radar float window transparency ([a192a05](https://github.com/black-atom-industries/radar.nvim/commit/a192a05ec5f588fcaafddd0803bbafba2c260d88))
* **config:** correct alternative window title icon ([093c989](https://github.com/black-atom-industries/radar.nvim/commit/093c9898837428a18feb983d4924b08a3634a0c9))
* **config:** increase collision padding to 50 for better window separation ([226b990](https://github.com/black-atom-industries/radar.nvim/commit/226b99083c2cce4302cafb8afeaed8e6b318875d))
* **config:** update default keybindings and float editor settings ([12f92b8](https://github.com/black-atom-industries/radar.nvim/commit/12f92b88e3c4f788f0af9e00658308ade5cecaf9))
* **navigation:** handle file save and window closure with improved checks ([658c794](https://github.com/black-atom-industries/radar.nvim/commit/658c79415ace33aead30ba97671a7fcf09abb3c0))
* **navigation:** handle file save and window closure with improved checks ([8cd69ce](https://github.com/black-atom-industries/radar.nvim/commit/8cd69cee64830bcafeb0146256c70b2005c49ad8))
* **radar:** consolidate highlight logic and reduce redundant updates ([1500a2a](https://github.com/black-atom-industries/radar.nvim/commit/1500a2ae6472cbc4ed510a1d5bca3ab15845b4c4))
* **radar:** improve mini window display with separator and spacing ([bcace76](https://github.com/black-atom-industries/radar.nvim/commit/bcace762072259ef5c891e5c94a0a89a1e08a2c9))
* **radar:** optimize persistence and pin board handling logic ([e4756b5](https://github.com/black-atom-industries/radar.nvim/commit/e4756b5fcccaf3ffdeb6eb387bc29bfd9802628c))
* **radar:** remove redundant empty lines when no entries exist ([2d2b256](https://github.com/black-atom-industries/radar.nvim/commit/2d2b2563bc1d2c1e0e1b5d4bfde15e912d56d4a3))
* **radar:** update 'SURROUNDING' header text to 'NEAR ([bc3ef0d](https://github.com/black-atom-industries/radar.nvim/commit/bc3ef0db1c117c2d7e4a9ab7b0d4aae21bcda520))
* resolve type check errors and simplify cleanup logic ([b9ec60d](https://github.com/black-atom-industries/radar.nvim/commit/b9ec60d0522a1007947370c5984ddb07c991e95d))
* **ui:** close mini radar window during edit cleanup ([8cd1293](https://github.com/black-atom-industries/radar.nvim/commit/8cd12936dbc968668c38ccf608ff43cfdeda0131))
* **ui:** integrate path shortening utilities in floating radar window ([1d8bccd](https://github.com/black-atom-industries/radar.nvim/commit/1d8bccd197faca8aec96cd680cd9d551e1995c78))


### Documentation

* add cleanup command documentation to README ([28d06be](https://github.com/black-atom-industries/radar.nvim/commit/28d06be23d2e82a56fbbc25754d52703200e729b))
* add comprehensive grid-based radar implementation plan ([d977a54](https://github.com/black-atom-industries/radar.nvim/commit/d977a547771bec6890a02c4a0b1725126a1e3acd))
* **changelog:** update changelog with new pending tasks and completed features ([ca709ca](https://github.com/black-atom-industries/radar.nvim/commit/ca709ca415d2d8f72350f6cf74240c38273b89cd))
* expand architecture overview and document modular structure ([b9b1d36](https://github.com/black-atom-industries/radar.nvim/commit/b9b1d368ff2e3164d07bdeed7dee8d03a524d9c0))
* **project:** add CLAUDE.md with project context and development philosophy ([f5fb9e2](https://github.com/black-atom-industries/radar.nvim/commit/f5fb9e2af1f1c90008837e74f907bc0a82cf45b6))
* **radar:** add picker integration planning document ([e56eb93](https://github.com/black-atom-industries/radar.nvim/commit/e56eb93a6e8405cc60a8ed5350deb50e5b9e908d))
* **README:** enhance project documentation with screenshots and formatting ([a3fddbe](https://github.com/black-atom-industries/radar.nvim/commit/a3fddbefeb1efcd7d7ad3da5fc6bfec129d4c021))
* **README:** update project description and add comprehensive documentation ([b016530](https://github.com/black-atom-industries/radar.nvim/commit/b0165309e099a59922509d602e4324e343f2cf83))
* remove ROADMAP.md ([6797ec6](https://github.com/black-atom-industries/radar.nvim/commit/6797ec61404e15a39fd594bfcbbedcf5ecec0b11))
* rename CLAUDE.md to AGENTS.md with symlink redirect ([65355d7](https://github.com/black-atom-industries/radar.nvim/commit/65355d7d7250c2c37b573c0b7fc2b13877ca8b9a))
* **roadmap:** update project roadmap with new features and status ([dcb91a5](https://github.com/black-atom-industries/radar.nvim/commit/dcb91a542da672638f849d4a735db5969342efc4))
* update changelog ([436b34a](https://github.com/black-atom-industries/radar.nvim/commit/436b34af1d4f818d5aac0ed9f3b178799475e298))

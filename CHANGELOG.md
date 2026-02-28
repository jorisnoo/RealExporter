# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0](https://github.com/jorisnoo/RealExporter/releases/tag/v0.2.0) (2026-02-28)

### Features

- remember last import directory in file picker panel ([902302c](https://github.com/jorisnoo/RealExporter/commit/902302c56f8b96487ba5d268f76f0ac405990fa7))
- filter conversations and comments by date range and redesign date overlay as pill badge ([383ec02](https://github.com/jorisnoo/RealExporter/commit/383ec02814d58a9313f6c82ceb1a6609588d8824))
- filter exports by date range and default video to front-main layout ([293ac6b](https://github.com/jorisnoo/RealExporter/commit/293ac6bc55ac2053298ade46d859c384ab13f197))
- add "Open in Finder" button to export completion view ([0bffdfc](https://github.com/jorisnoo/RealExporter/commit/0bffdfc9bfeed67e2733d68a78e70dd3a3c5257f))
- add year boundary snap points and labels to date range slider ([1a49f47](https://github.com/jorisnoo/RealExporter/commit/1a49f47d1d1248a86e0920b10df385790f0045c7))
- add date range slider to summary view, support front-main overlay layout, and simplify UI controls ([5bb5ab5](https://github.com/jorisnoo/RealExporter/commit/5bb5ab5fe6901814af95d41847175436ec1ac897))
- add time-lapse video generation from BeReal photos ([2c90ca0](https://github.com/jorisnoo/RealExporter/commit/2c90ca03724197468d2500ca5a5f6d9f3255e67b))

### Bug Fixes

- improve overlay position picker layout and add labelsHidden to segmented pickers ([40d7b51](https://github.com/jorisnoo/RealExporter/commit/40d7b51f8c51d4fe357ad035f6d74923f2d3cf5f))
- preserve user options on reset by only clearing destination URLs ([25b7c7e](https://github.com/jorisnoo/RealExporter/commit/25b7c7e0c292d20e146e38360f6b94d25505a773))
- rename "Back" button to "Start Over" in data summary view ([4d2bb1c](https://github.com/jorisnoo/RealExporter/commit/4d2bb1cf1e5b29d304f67ba71d1dd1f56d186b31))

### Documentation

- add brew install instructions ([23ffe64](https://github.com/jorisnoo/RealExporter/commit/23ffe64ed0e5b7d2b135f0d1c3a36a7fed561a05))

### Continuous Integration

- add automatic Homebrew cask update step to release workflow ([ade73d8](https://github.com/jorisnoo/RealExporter/commit/ade73d8bfcefc7f722e02d229d499376bb8e0e04))
## [0.1.2](https://github.com/jorisnoo/RealExporter/releases/tag/v0.1.2) (2026-02-26)

### Features

- add unit test suite and enhance image processor with body, text, and objectness detection for smarter overlay placement ([61080d0](https://github.com/jorisnoo/RealExporter/commit/61080d0e9264999435d85c04f66490777ca1cc01))

### Code Refactoring

- remove unused border drawing from image overlay ([ec3111f](https://github.com/jorisnoo/RealExporter/commit/ec3111f2003086fcc58bf5a3a58d9644d8df0cbc))
## [0.1.1](https://github.com/jorisnoo/RealExporter/releases/tag/v0.1.1) (2026-02-25)

### Features

- add location data to memory model and export ([944b667](https://github.com/jorisnoo/RealExporter/commit/944b667c854773607e40c59ae5eaefb5cb11e929))
- add export analytics tracking and video count to export progress view ([01fa872](https://github.com/jorisnoo/RealExporter/commit/01fa87289034370065326a7a4f332d26fae18cf4))
- add video support ([bb9c8e1](https://github.com/jorisnoo/RealExporter/commit/bb9c8e1ac84b1390310eba149bc1bfadd8e7bfe8))

### Bug Fixes

- disable App Sandbox for non-App Store builds ([b3b2711](https://github.com/jorisnoo/RealExporter/commit/b3b2711e584ae903a82e467d218113ab9fb9bae3))
- add apta key ([07994a4](https://github.com/jorisnoo/RealExporter/commit/07994a4ac311d1a9206d0a33f50f6f02723311ed))
## [0.1.0](https://github.com/jorisnoo/RealExporter/releases/tag/v0.1.0) (2026-02-25)

### Features

- update combined style description and simplify user section layout ([cdbadda](https://github.com/jorisnoo/RealExporter/commit/cdbadda4ac3d4ef32efa80d3a747297798866ac8))
- replace overlay position picker with collapsible DisclosureGroup ([792f8f4](https://github.com/jorisnoo/RealExporter/commit/792f8f47d2a3112af373ba34ec89c9165e3ec097))
- add "All" overlay position to export all corners and simplify export by removing destination section ([e238a3e](https://github.com/jorisnoo/RealExporter/commit/e238a3e527835bf968502d1a17ddbc8d1a041053))
- add README, face detection for overlay positioning, and set deployment target to macOS 14.0 ([77c40e3](https://github.com/jorisnoo/RealExporter/commit/77c40e31309c0072bae36cafe013d814e8dee487))
- use Vision saliency for overlay positioning, convert chat images to JPEG, and rename app icon ([472e3d9](https://github.com/jorisnoo/RealExporter/commit/472e3d9ba39c5ac5cce7828732cabb8bc30a7762))
- add auto overlay position that picks the least busy corner ([a7e4f86](https://github.com/jorisnoo/RealExporter/commit/a7e4f8632ca3c216c3d93fbdbc828e161de48d63))
- refactor to @Observable pattern, add app icon, demo data, and improve export cancellation ([5aa388f](https://github.com/jorisnoo/RealExporter/commit/5aa388f045f3ef94c99b9eb4c92856cdf654dfd5))
- better export ([bfbad9d](https://github.com/jorisnoo/RealExporter/commit/bfbad9da51e24e0c89cdf40748fae6f0f8202411))
- first version ([6af4974](https://github.com/jorisnoo/RealExporter/commit/6af49741deabbf14627e4806629053ca03376d07))

### Bug Fixes

- resolve auto overlay position independently per image and reject non-empty export folders ([b09a896](https://github.com/jorisnoo/RealExporter/commit/b09a896066c8a55ab5b5ff83a5c991eb924571c9))

### Documentation

- update README screenshots and description, ignore hidden files in empty folder check ([1692f4c](https://github.com/jorisnoo/RealExporter/commit/1692f4c02e6d0fc8a7c1bd5f8365f47cc0640ceb))

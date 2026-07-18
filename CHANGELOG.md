# Changelog

## 0.2.2

- Add fully local photo palette analysis for customer packages.
- Detect light/dark mode and extract a dominant accent color from the customer's image.
- Generate coordinated canvas, sidebar, surface, card, text, border and control colors with readable contrast.
- Make `自动匹配照片（推荐）` the default Customer Pack Studio option while preserving manual palette overrides.
- Add dark/light palette tests and automatic-palette customer-package validation.

## 0.2.1

- Promote the full-window theme system to a stable release.
- Theme the sidebar, menu bar, home canvas, cards, composer, task pages and profile avatar as one palette.
- Fix light-theme readability in task titles and chat messages.
- Add an explicit `切换 WorkBuddy 主题` Desktop shortcut.
- Add a graphical customer-pack builder that turns a local photo into a private, installable ZIP.
- Preselect the customer's theme after installation and include local install instructions plus SHA256 verification.

## 0.2.1-rc.1

- Add a single-window graphical Theme Studio with theme previews.
- Add local image import for JPG, PNG, WebP, and GIF backgrounds.
- Add a current-user installer with Desktop and Start Menu shortcuts.
- Add a safe uninstaller and preserve local themes during reinstall/update.
- Add reproducible Release ZIP and SHA256 generation.
- Add promotion-candidate integration tests and a manual acceptance guide.

## 0.2.0

- Add automatic discovery of public and local themes.
- Add `Switch Theme.cmd` and remember the last selected theme.
- Add separate home/task overlay strengths with live page-mode detection.
- Add an original Sakura Night preset.
- Add local-only theme shells for Shorekeeper, Changli, Luffy Gear 5, and the Straw Hat crew.
- Add local theme installer and theme-system tests.
- Make JSON and CSS loading explicitly UTF-8 for Windows PowerShell 5.1.

## 0.1.0

- Initial Windows CDP injector, Dream Glass theme, restore command, and smoke test.

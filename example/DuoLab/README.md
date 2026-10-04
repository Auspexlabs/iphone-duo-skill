# DuoLab — the measuring instrument behind the skill

A lab, not a pattern. Every claim in `iphone-duo/references/*.md` about the iPhone Duo was read off this app
on the simulator. It needs Xcode 27.1+ (it uses the iOS 27.1 APIs unguarded).

```bash
xcodegen && DEVELOPER_DIR=<Xcode 27.1>/Contents/Developer xcodebuild -project DuoLab.xcodeproj -scheme DuoLab \
  -destination "id=<iPhone Duo udid>" -derivedDataPath /tmp/duolab build
xcrun simctl install <udid> /tmp/duolab/Build/Products/Debug-iphonesimulator/DuoLab.app
xcrun simctl launch <udid> com.example.DuoLab -fold          # one launch argument picks the page
```

| Launch argument | Page |
|---|---|
| `-fold` (default when tapping the icon) | The two arrangements (固定式 / 混合式) and a dropped third one, switchable at the top of Main, plus a "cover landscape" toggle for the orientation rule (off by default; on, it shows the simulator's settle rotation at the end of a fold). Writes every orientation / bar / hinge / size change to `Documents/log.txt` (read it with `xcrun simctl get_app_container <udid> com.example.DuoLab data`). |
| `-hstack` | Hand-written `HStack { if regular { Fold }; Main }` with a "born" timestamp in Main: proves Main's state survives fold, unfold and rotation. |
| `-split`, `-rtl`, `-overlay`, `-auto` | `ArrangementView(primary: Main, secondary: Fold)` with each style; `-rtl` adds the right-to-left trick. The evidence behind the ArrangementView table in `references/api.md`. |
| `-bar1` … `-bar8` | The vertical-bar gallery behind `references/bar.md`: grouping, styles, content kinds, overflow, placements, axis behavior + search, tab bar, square buttons. |

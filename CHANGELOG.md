# Changelog

格式依 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，未發版的變更放在 Unreleased。

## [Unreleased]

### Fixed

- herdr 重啟後，側欄變成停在 plugin 根目錄的空 shell：herdr 還原版面時不會重跑 plugin pane 的指令。`prefix+f` 原本只認得正在跑 shelf.sh 的 pane，碰到空殼會在旁邊再開一個。現在以 pane 的 label（`Files`）加上工作目錄辨識空殼：`prefix+f` 會把它關掉，startup hook 在 herdr 啟動時也會一併清掉。

## [0.2.0] - 2026-10-06

### Added

- `prefix+f` 改為開關：同一個 tab 已有側欄時再按一次會關閉，疊了多個也一併關掉。窄側欄看不到結尾的關閉提示，使用者再按一次想關，原本會疊出第二個側欄。
- 安裝後自動綁定 `prefix+f`：startup hook 在 herdr 啟動後寫入 `config.toml` 並 reload，也可以用 `install-keybind` action 立即執行。側欄已綁在任何按鍵上，或 `prefix+f` 被別的指令佔用時，不動設定檔。
- 以 herdr 回報的 Claude session id（`agent_session.value`）找逐字檔。兩個 session 同名、或沒有用 `/rename` 命名時，原本的標題比對會認錯。pane 的工作目錄換過時，會到其他專案資料夾找。
- `/clear` 或 `/resume` 讓 pane 換到新的 session id 時，側欄在下一次輪詢自動切過去。
- 讀 herdr-nap 公開的 `napped.tsv`：pane 被休眠後 herdr 不再回報 session id，改從紀錄取得，休眠的 pane 也看得到睡前送過的檔案。只在 herdr 回報該 pane 沒有 agent 時採用，也只採用 claude 的紀錄。
- 側欄標題改用逐字檔的 `customTitle`，不再受 pane 標題的裝飾影響（例如 herdr-nap 的 `[nap]` 前綴）。
- 支援 Linux：逐字檔 mtime 改用 GNU 與 BSD 都能用的寫法，沒有 `SHELF_OPEN_CMD` 時 Linux 用 `xdg-open` 開檔。
- 側欄寬度改變後重畫（SIGWINCH，最多等一次輪詢）。
- bats 測試（46 項）：資料來源、側欄的鍵盤與滑鼠操作、開關、自動綁定、跨平台工具。
- MIT 授權。

### Changed

- 找不到這個 pane 的 session 時，側欄顯示 `no session found for this pane`，不再拿專案內最近寫入的逐字檔來猜。猜錯會把別的 session 的檔案當成這個 pane 的。
- 按鍵提示以 `q close` 開頭，改用 ASCII。窄側欄會截掉結尾，部分終端機把箭頭等符號畫成兩格寬，造成換行。

### Fixed

- 同一個檔案重送時位置不變，只更新說明文字。現在會移到清單最上面。
- `SendUserFile` 的 `files` 被誤傳成一整個 JSON 字串時，側欄逐字拆開，多出一排單一字元的項目。現在略過格式錯誤的呼叫，工具回報失敗的呼叫也不列入。
- Linux 上逐字檔 mtime 取錯：GNU `stat -f` 是檔案系統狀態且回傳成功，退回的寫法永遠跑不到。

### Docs

- README 重整：開頭的動畫、herdr 內的示意圖、`--yes` 的非互動安裝、Linux 需求、自動綁定的說明、相關專案。
- `tools/make-demo.py` 產生 README 的動畫，`tools/render-video.js` 輸出影片。

## [0.1.0] - 2026-09-23

### Added

- 常駐檔案側欄：讀 Claude Code 的 session 逐字檔，列出 `SendUserFile` 送出的檔案，最新的在最上面，同一路徑只列一次。
- 綁定開啟時所在的 pane，以 pane 標題比對逐字檔的 `customTitle` 辨識 session，對不上時取最近寫入的逐字檔。
- 每個項目兩行：檔名與上一層資料夾，底部顯示送檔時的說明文字。
- 開檔交給 `SHELF_OPEN_CMD`（預設 `~/.local/bin/semantic-open`），double fork 加 setsid 脫離 pane 的程序群組，pane 關閉時開出的視窗不會跟著被關。
- 鍵盤與滑鼠操作（SGR 滑鼠追蹤，按下即開、滾輪捲動），側欄寬度自動調成 tab 的 0.21。

[Unreleased]: https://github.com/Clementtang/herdr-shelf/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Clementtang/herdr-shelf/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Clementtang/herdr-shelf/tree/v0.1.0

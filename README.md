# herdr-shelf

常駐的檔案側欄：列出隔壁那個 Claude Code session 送給你的每一個檔案，最新的在最上面，按 Enter 用你自己的開檔路由打開。

做這個是因為 Claude Code 在終端機裡把檔案印成 `› [file] ~/....m4a`，要聽要看都得自己想辦法。掃描當下畫面的做法（例如 herdr-quicklook 的 hint）會隨著畫面捲動而失去舊檔案，所以這裡改讀 session 的逐字檔。

## 安裝

需要 `jq` 與 `python3`。

```
herdr plugin link ~/herdr-shelf
```

在 `~/.config/herdr/config.toml` 綁快捷鍵：

```toml
[[keys.command]]
key = "prefix+f"
type = "plugin_action"
command = "clementtang.herdr-shelf.shelf"
```

改完執行 `herdr server reload-config`。

## 操作

| 按鍵              | 動作                     |
| ----------------- | ------------------------ |
| `j` / `k`、上下鍵 | 移動選取                 |
| `Enter`           | 用 `SHELF_OPEN_CMD` 開啟 |
| `r`               | 重新載入                 |
| `q`               | 關閉側欄                 |

每個項目佔兩行：檔名，底下一行是它的上一層資料夾（例如錄音日期）。點兩行的任何一行都是開同一個檔案。

底部會顯示選取檔案的說明文字，也就是 Claude 送檔時附的 caption。

## 它怎麼知道要看哪個 session

一個專案資料夾底下放著這個 repo 跑過的每一個 session，而且常常好幾個同時開著，所以「取最新的逐字檔」會抓錯。側欄改成綁定開啟時所在的那個 pane：讀它的 pane 標題（就是 `/rename` 的名字），去比對逐字檔裡最後一筆 `customTitle`。session 沒有命名時，退回取最近寫入的那一份。

清單只收 `SendUserFile` 送出的檔案，也就是真的被推到你面前的那些。

## 設定

| 環境變數             | 預設                         | 說明                                            |
| -------------------- | ---------------------------- | ----------------------------------------------- |
| `SHELF_OPEN_CMD`     | `~/.local/bin/semantic-open` | 開檔指令，收到一個絕對路徑。不存在時退回 `open` |
| `SHELF_POLL_SECONDS` | `2`                          | 幾秒檢查一次逐字檔有沒有更新                    |
| `SHELF_ORIGIN_PANE`  | 由 herdr 提供                | 要跟隨的 pane，測試時可手動指定                 |

開檔會先脫離 pane 的程序群組再執行（double fork 加 setsid）。herdr 在 pane 關閉時會停掉整個程序群組，不這樣做的話 Quick Look 會跟著被殺。

## 已知限制

- 綁在 Claude Code 的逐字檔格式上（`SendUserFile` 的 `tool_use` 紀錄與 `custom-title`）。Claude Code 改格式就要跟著修。
- 以 `/rename` 的名字辨識 session。兩個 session 取同一個名字時會認錯。
- 全程使用 macOS 內建的 bash 3.2，因為 herdr 就是用它執行 plugin。

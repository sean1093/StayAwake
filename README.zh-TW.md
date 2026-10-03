# StayAwake

[English](README.md) · **繁體中文**

> macOS 選單列小工具：讓螢幕不休眠，並在你閒置時自動微移滑鼠，
> Microsoft Teams 就不會把你的狀態切成「離開」。

<div align="center">

[下載最新版](https://github.com/sean1093/StayAwake/releases/latest) · [問題回報](https://github.com/sean1093/StayAwake/issues)

</div>

---

## 特色

- **螢幕不休眠**：執行期間螢幕和系統都不會因閒置而休眠（效果等同 `caffeinate -d`）。
- **Teams 不顯示離開**：新版 Teams 在螢幕鎖定或電腦睡眠時會切成「離開」。StayAwake 讓螢幕保護程式不會因閒置啟動，
  螢幕也就不會被自動鎖定。
- **閒置時微移滑鼠**：你閒置超過設定時間時，滑鼠會右移 1 像素再移回原位，系統閒置時間歸零。
  肉眼看不出來，游標也停在原處；你在用電腦時它完全不會動。
- **可調整的閒置時間**：30 秒、1 分鐘（預設）、2 分鐘、4 分鐘，都短於常見的 5 分鐘閒置判定與螢幕保護程式時間。
- **常駐選單列**：不佔 Dock，一鍵暫停／恢復。
- 約 200 行原生 Swift，沒有第三方套件。

## 系統需求

- macOS 13 Ventura 以上（在 macOS 26 上測試）
- Apple Silicon 與 Intel Mac 皆可（universal binary）

## 安裝

### 方法一：一行指令（推薦）

打開「終端機」，貼上並執行：

```sh
curl -fsSL -o /tmp/StayAwake.zip https://github.com/sean1093/StayAwake/releases/latest/download/StayAwake.zip \
  && ditto -x -k /tmp/StayAwake.zip /Applications \
  && open /Applications/StayAwake.app
```

用 `curl` 下載的檔案不會被加上「從網路下載」的標記，所以 macOS 不會擋下這個未經 Apple 公證的 App。
沒有管理員權限、無法寫入 `/Applications` 的話，把指令裡的兩個 `/Applications` 都換成 `~/Applications`。

### 方法二：手動下載

1. 到 [Releases](https://github.com/sean1093/StayAwake/releases/latest) 下載 `StayAwake.zip`，
   解壓縮後把 `StayAwake.app` 拖到「應用程式」資料夾。
2. 第一次打開時，macOS 會說無法驗證開發者（這個 App 沒有付費的 Apple 開發者簽章）。
   按「完成」，到 **系統設定 → 隱私權與安全性**，捲到最下面的「安全性」，按 **強制打開**（Open Anyway）並確認。

   也可以在終端機執行這行來移除隔離標記，之後就能直接打開：

   ```sh
   xattr -dr com.apple.quarantine /Applications/StayAwake.app
   ```

### 授予「輔助使用」權限（移動滑鼠需要）

macOS 規定 App 必須取得「輔助使用」權限才能移動滑鼠。

1. 第一次打開 StayAwake 會跳出授權視窗，按 **打開系統設定**。
2. 在 **系統設定 → 隱私權與安全性 → 輔助使用** 打開 **StayAwake** 的開關。
3. 選單列的圖示從 ⚠️ 變成實心咖啡杯就完成了，不用重開 App。

StayAwake 只用這個權限送出移動滑鼠的事件，不會記錄你的鍵盤或滑鼠輸入。

## 使用方式

打開後，StayAwake 會出現在螢幕右上角的選單列，並且馬上開始運作。

| 圖示 | 狀態 |
|---|---|
| 實心咖啡杯 | 運作中：螢幕不休眠，閒置時會移動滑鼠 |
| 空心咖啡杯 | 已暫停：恢復系統原本的休眠設定 |
| ⚠️ 三角形 | 缺少「輔助使用」權限：螢幕仍不會休眠，但不會移動滑鼠 |

點圖示會打開選單（系統偏好語言是中文時顯示中文，其他語言顯示英文）：

```
StayAwake 運作中
上次移動滑鼠：下午3:41:36
──────────────────────
✓ 保持清醒
  閒置多久後移動滑鼠       ▸  30 秒 / ✓1 分鐘 / 2 分鐘 / 4 分鐘
──────────────────────
  結束 StayAwake          ⌘Q
```

- **保持清醒**：勾選代表運作中，取消就暫停。
- **閒置多久後移動滑鼠**：你沒碰鍵盤滑鼠超過這段時間，就移動一次滑鼠。設定會被記住。
- **上次移動滑鼠**：最近一次自動移動的時間，可以用來確認它有在工作。

### 開機自動執行

**系統設定 → 一般 → 登入項目**（較新的 macOS 為「登入項目與延伸功能」），在「登入時打開」按 **+**，選擇 StayAwake。

## 運作原理

- **防止休眠與自動鎖定**：透過 `ProcessInfo.beginActivity(options: [.userInitiated, .idleDisplaySleepDisabled])`
  持有 `PreventUserIdleDisplaySleep` 與 `PreventUserIdleSystemSleep`。持有期間 macOS 不會因閒置啟動螢幕保護程式
  （`loginwindow` 會記錄 `PMNoDisplaySleepEnabled so do not launch screen saver`），螢幕也就不會因此被鎖定。可以用這行確認：

  ```sh
  pmset -g assertions | grep StayAwake
  ```

- **閒置時間歸零**：StayAwake 每 5 秒讀一次系統閒置時間（最後一次鍵盤或滑鼠輸入到現在多久），超過門檻就在 HID 層送出
  「右移 1 像素、再移回原位」兩個滑鼠事件，閒置時間歸零。以閒置時間判斷在線狀態的 App 也會因此把你當成在線。

**實測**：在公司 MDM 強制「閒置 5 分鐘啟動螢幕保護程式並立即鎖定」的 MacBook（macOS 26、新版 Teams）上，
沒開 StayAwake 時閒置滿 300 秒，螢幕保護程式啟動並鎖定，Teams 約一秒內變成「離開」；
開著 StayAwake 不碰電腦 6 分鐘，螢幕沒有鎖定、Teams 一直是「有空」，滑鼠約每 65 秒微移一次。

## 常見問題

**已經打開權限，圖示還是 ⚠️？**
更新或自行重新編譯後，App 的簽章通常會改變，舊的授權就不再有效（系統設定裡看起來仍是開啟）。
先從選單結束 StayAwake，執行下面這行，再打開 App 重新授權：

```sh
tccutil reset All io.github.sean1093.StayAwake
```

**Teams 還是顯示「離開」？**
鎖定螢幕、闔上筆電、手動讓電腦睡眠時，Teams 一定會顯示離開，這些不屬於閒置，StayAwake 管不到。
另外確認圖示不是 ⚠️，以及閒置時間設定短於 5 分鐘。

**公司的電腦沒辦法打開「輔助使用」？**
修改這個權限需要管理員身分，有些公司管理的電腦會限制。這種情況下 StayAwake 仍會防止螢幕休眠，但無法移動滑鼠。

**會干擾我正常使用嗎？**
不會。只有閒置超過設定時間才會動，而且游標會回到原本的位置。

## 更新到新版

1. 從選單按 **結束 StayAwake**。
2. 清除舊版的授權（每一版的簽章不同，舊授權不適用於新版）：

   ```sh
   tccutil reset All io.github.sean1093.StayAwake
   ```

3. 重新執行[安裝](#安裝)的指令，再授權一次。

## 解除安裝

```sh
pkill -x StayAwake
rm -rf /Applications/StayAwake.app
tccutil reset All io.github.sean1093.StayAwake
defaults delete io.github.sean1093.StayAwake
```

## 從原始碼編譯

需要 Xcode 或 Command Line Tools（`xcode-select --install`），以及 Swift 6 以上。

```sh
git clone https://github.com/sean1093/StayAwake.git
cd StayAwake
./build.sh
open build/StayAwake.app
```

`build.sh` 會編譯 arm64 與 x86_64 兩種架構、合併成 universal binary、做 ad-hoc 簽章，
產出 `build/StayAwake.app` 和 `build/StayAwake.zip`。重新編譯後簽章通常會改變，若圖示又變回 ⚠️，請見[常見問題](#常見問題)。

用 `swift test` 執行單元測試。每次 push 與 pull request，CI 都會跑編譯、測試和 `./build.sh`。

```
Sources/StayAwakeCore/
  KeepAwake.swift     防止休眠、偵測閒置、移動滑鼠
Sources/StayAwake/
  AppDelegate.swift   選單列介面
  main.swift          進入點
Tests/StayAwakeCoreTests/
                      單元測試（swift test）
Info.plist            App 設定（LSUIElement：不顯示在 Dock）
build.sh              編譯、簽章、打包
```

### 發布新版本

1. 修改 `Info.plist` 的 `CFBundleShortVersionString`。
2. 編譯並上傳到 GitHub Release（檔名維持 `StayAwake.zip`，安裝指令的下載連結才會一直指向最新版）：

   ```sh
   ./build.sh
   gh release create v1.0.1 build/StayAwake.zip --title "v1.0.1" --notes "更新內容"
   ```

## 授權

採用 [MIT](LICENSE) 授權。

[回到主報告](../README.zh-TW.md) | [工程架構](03-build-large-3d-software.zh-TW.md) | [實作路線](04-cpp-learning-roadmap.zh-TW.md)

# 以一個操作追蹤 Blender 原始碼

更新日期：2026 年 10 月 11 日。

先理解自己的小型核心，再挑 Blender 的一個操作追蹤。第一次的問題可以是：「建立一個網格物件後，哪些資料被建立，Undo 在哪裡發生，畫面如何知道要更新？」這比依目錄順序閱讀整個程式更容易建立理解。

## 固定版本與閱讀範圍

建議對照一個正式 tag，例如 `v5.2.0`，並記錄 commit。官方原始碼在 [Blender Projects](https://projects.blender.org/blender/blender)，[GitHub 公開鏡像](https://github.com/blender/blender/tree/v5.2.0/source/blender)提供同一專案的瀏覽入口。開發文件可能隨新版更新，舊設計文章也可能含提案和待辦；遇到差異以所選 tag 的程式碼為準。

本次導讀依已核對的目錄與官方說明整理，沒有在這個研究目錄下載或建置完整 Blender，也沒有實際執行下述除錯練習。附帶的小型 C++ 核心另行建置和測試。

## 先認得主要責任區域

| 目錄 | 第一次閱讀要找的事 |
| --- | --- |
| `source/blender/windowmanager/` | 事件分派、操作註冊與執行生命週期。 |
| `source/blender/editors/` | 使用者操作與各種編輯器的工具實作。 |
| `source/blender/blenkernel/` | 核心資料操作與生命週期。 |
| `source/blender/makesdna/` | 保存資料的結構定義。 |
| `source/blender/makesrna/` | 屬性、函式與對外描述。 |
| `source/blender/depsgraph/` | 變更關係與求值。 |
| `source/blender/draw/`、`gpu/` | 視窗畫面與 GPU 抽象。 |
| `source/blender/blenloader/`、`blenloader_core/` | 檔案讀寫及相容處理。 |
| `source/blender/bmesh/` | 編輯網格拓樸的資料與操作。 |
| `intern/cycles/` | 渲染器的場景、取樣、裝置與核心。 |

責任說明見[Code Layout](https://developer.blender.org/docs/features//code_layout/)和[Cycles Layout](https://developer.blender.org/docs/features/cycles/source_layout/)。要先找公開介面與核心型別，再看內部細節。

## 練習一追蹤新增網格物件

選定 `mesh.primitive_cube_add` 作為起點。下面是搜尋方法；在你自行準備的 Blender checkout 執行，不是在本研究目錄直接執行：

```powershell
rg -n 'MESH_OT_primitive_cube_add|primitive_cube_add' source scripts
rg -n 'WM_operatortype_append' source/blender/editors/mesh
rg -n 'OPTYPE_UNDO|ot->exec|ot->invoke|ot->poll' source/blender/editors/mesh
```

找註冊函式如何設定 ID、參數和回呼，再閱讀 callback 的處理。不要把函式名稱當作已理解；要確認它接受什麼 context、建立哪些資料、對錯誤怎麼回應，以及是在物件模式還是編輯模式工作。

畫出你實際看到的呼叫路徑，並在每一段註明責任：UI 或腳本輸入、操作管理、具體新增工具、資料建立、變更通知。Undo 和求值可能由共同框架處理，不一定寫在新增立方體函式附近。[Operators 文件](https://developer.blender.org/docs/features//interface/operators/)

## 練習二追蹤同一屬性的三條路徑

找物件位置的持久資料、RNA 定義，以及介面或 Python 操作它的入口：

```powershell
rg -n 'struct Object|typedef struct Object' source/blender/makesdna
rg -n 'RNA_def_property.*location|rna_Object.*update' source/blender/makesrna
rg -n 'DEG_id_tag_update' source/blender/editors/transform source/blender/makesrna
```

回答：欄位存在哪裡、設定時會做哪些檢查、誰發出更新、渲染使用的是哪份資料。相關文件：[DNA](https://developer.blender.org/docs/features/core/dna/)、[RNA](https://developer.blender.org/docs/features/core/rna/)、[相依圖](https://developer.blender.org/docs/features/core/depsgraph/)。

這個練習能揭示「修改一個數值」和「讓所有使用該數值的系統得到正確結果」之間的差別。第一次只追一個欄位，之後再換成網格頂點或材質參數。

## 練習三觀察 Undo 與檔案相容性

先讀 Undo 文件，再在所選 tag 搜尋其提到的核心檔案和型別。文件中的檔案副檔名可能隨重構改變，因此用名稱片段搜尋：

```powershell
rg --files source/blender | rg 'undo_system|ed_undo|memfile_undo|versioning'
rg -n 'UndoType|undo_push' source/blender/blenkernel source/blender/editors/undo
```

比較一般物件操作與網格編輯使用的歷史資料。再看讀檔後的 versioning：新欄位如何補預設值、資料語意改變如何轉換。選一項小型變更閱讀它的測試，比一次研究整份格式容易。

參考[Undo 分層](https://developer.blender.org/docs/features/core/undo/)與[檔案相容性](https://developer.blender.org/docs/handbook/guidelines/compatibility_handling_for_blend_files/)。

## 需要實際除錯時再建置 Blender

官方 Windows 指南使用 Visual Studio 的桌面 C++ 工具、Git 與 CMake，並以 `make` 封裝建置。其預編譯依賴有數 GB，且不同 tag 的需求可能不同。先閱讀所選版本與[官方 Windows 指南](https://developer.blender.org/docs/handbook/building_blender/windows/)，再下載。

以下是獨立練習目錄的示意，會下載大量原始碼及相依套件；應在 Windows `cmd.exe`，依官方指南執行。本次沒有代你執行：

```bat
mkdir C:\blender-learning
cd /d C:\blender-learning
git clone https://projects.blender.org/blender/blender.git
cd blender
git checkout v5.2.0
make update
make
```

`make update` 會處理來源與相依更新。若要求可重現的 tag 建置，先看該 tag 的 wrapper 說明及官方建置選項，確認更新後的 ref 與 commit 仍是所選版本；不要把 `main` 的最新環境混入固定版本。

產生 Visual Studio 專案後，官方提醒需建置 `INSTALL` target 以備齊執行檔與 DLL。為何某個 tag 要指定工具版本，應查當時的支援矩陣，不要把本次小型範例能用 VS 2026 編譯當成完整 Blender 的相容保證。[Visual Studio 建置說明](https://developer.blender.org/docs/handbook/development_environments/visual_studio/)

## 用最小改動檢查自己的理解

第一個修改可只是加入一個只記錄事件的斷點或 log；確認操作實際走過哪些路徑。接著在獨立分支做一個小工具，例如只對選取物件設定特定位置，並檢查取消、Undo 和保存。

每次記下四項：你預期的呼叫路徑、實際觀察到的路徑、維持的不變條件，以及加入的回歸案例。若無法解釋操作為何能 Undo，先回到自己的核心範例補足理解，再擴大修改。

[工程架構](../../research/03-build-large-3d-software.zh-TW.md) | [實作路線](../../research/04-cpp-learning-roadmap.zh-TW.md)

# C++ 小型編輯器核心實驗

這個可執行範例把大型編輯器的幾個關鍵問題縮小：兩個物件共用網格、透過命令移動或刪除、Undo／Redo、按文件版本重建求值快取，以及有版本的保存和讀回。

它使用 C++20 和標準函式庫，沒有額外下載依賴。程式在命令列展示資料流程；沒有桌面視窗、GPU 渲染、滑鼠選取、旋轉、父子變換或可編輯拓樸。這些是[後續練習](../../research/04-cpp-learning-roadmap.zh-TW.md)要逐步接上的部分。

## 建置與執行

需要 CMake 3.20 以上和可編譯 C++20 的工具。以下以 Windows Visual Studio 2022 為例，在本範例目錄執行：

```powershell
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Debug
ctest --test-dir build -C Debug --output-on-failure
.\build\Debug\editor_demo.exe
```

若使用 Visual Studio 2026，且 CMake 支援該 generator，可改成 `Visual Studio 18 2026`。也可在 Developer Command Prompt 使用已安裝的 Ninja：

```bat
cmake -S . -B build/ninja -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build/ninja
ctest --test-dir build/ninja --output-on-failure
build\ninja\editor_demo.exe
```

Ninja 與 Visual Studio 使用不同建置子目錄，避免在同一個 CMake cache 變換 generator。本次在 Windows、MSVC 19.51、CMake 4.3.1 與 Ninja 上完成 Debug 建置，CTest 成功，測試程式內的 11 組工作流程案例全部通過。

Demo 的預期輸出：

```text
Initial: revision=0, first_vertex.x=-1, evaluations=1
Unchanged frame uses cache: revision=0, first_vertex.x=-1, evaluations=1
Move: revision=1, first_vertex.x=1, evaluations=2
Undo: revision=2, first_vertex.x=-1, evaluations=3
Redo: revision=3, first_vertex.x=1, evaluations=4
Roundtrip: two objects share one mesh; runtime state is rebuilt.
```

可附一個輸出路徑查看文字格式，例如 `editor_demo.exe build/demo.scene`。這是簡單輸出，會覆寫該路徑；正式產品應增加暫存、替換與備份流程。

## 建議閱讀順序

| 檔案 | 要理解的問題 |
| --- | --- |
| [core.hpp](core.hpp) | 作者資料、命令、求值資料與文件各自持有什麼。 |
| [core.cpp](core.cpp) | 一個操作如何先驗證再提交；歷史、載入與快取如何串接。 |
| [demo.cpp](demo.cpp) | 移動、Undo、Redo、保存再載入的完整流程。 |
| [tests.cpp](tests.cpp) | 失敗操作、快取、參照與歷史分支如何驗證。 |
| [CMakeLists.txt](CMakeLists.txt) | 核心函式庫與 demo／tests 的依賴方向。 |

先在 `Document::execute()` 停住，確認修改的是候選資料。再看 `undo()` 如何恢復原場景但提高 revision，最後看 `evaluate()` 為何重新建立快取。

Undo／Redo 保留 ID 分配器的最高進度，避免復原新增操作後，把先前發出的 ID 配給另一個新物件。這與恢復被刪除物件時保留原有身份，是不同的情況。

`save()` 只輸出作者資料。GPU handle、求值快取和 Undo 都不在檔案裡。`load()` 先解析與驗證，成功後才替換文件並清除舊歷史；失敗則保持現有文件。

## 這個設計如何逐步擴大

| 目前簡化 | 規模變大後的方向 |
| --- | --- |
| 每次操作複製整個 Scene | 差異歷史、資料共享、記憶體預算。 |
| 一個整體 revision | 按物件、幾何、變換與材質分類的版本及 dirty。 |
| 求值展開每個實例的世界頂點 | 共用局部網格，保留世界矩陣給渲染器。 |
| 同一種整數 ID | 強型別 ID、文件身份與執行期 generation handle。 |
| 只支援格式 v1 | 明確的 v1→v2 遷移與相容檔案測試。 |
| 每段元素上限 | 全檔記憶體／字串／時間預算及更完整的解析防護。 |
| 歷史不設上限，版本以整數遞增 | 歷史裁切、資源預算及完整工作版本識別。 |
| 沒有工作執行緒 | 快照、取消、結果過期與主執行緒提交。 |

`evaluate()` 和 `scene()` 返回借用參照；呼叫者不能在文件變動後繼續保存其內部指標。這個範例也沒有處理進程中斷或記憶體不足時的完整產品復原策略。

## 第一個自行修改的練習

增加 `RenameObject` 命令。先查找 ID，再改名稱，讓既有 execute 路徑處理驗證與歷史。測試含空白與 Unicode 的名稱、Undo／Redo，以及保存再載入。這能驗證一個新功能是否沿用既有架構，而不是繞過它另寫一條流程。

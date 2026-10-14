# 來源與證據範圍

查核日期：2026 年 10 月 14 日。返回[主報告](../README.zh-TW.md)。只以官方文件及專案公開程式碼支持產品行為；架構組合、遷移範例和驗收政策為本研究建議。

| 來源 | 支持的内容 | 查核與限制 |
| --- | --- | --- |
| [Blender DNA](https://developer.blender.org/docs/features/core/dna/) | SDNA 的結構描述與嵌入、讀取時比較結構 | 官方搜尋索引可讀；直接擷取頁面回傳 402，未取得完整頁面 |
| [Blender Blend File Compatibility](https://developer.blender.org/docs/handbook/guidelines/compatibility_handling_for_blend_files/) | 檔案版本、最低版本及增量 versioning；向前相容可有損失 | 官方搜尋索引可讀；直接擷取回傳 402；具體版本門檻應再核對完整文件 |
| [Blender Compatibility release notes](https://developer.blender.org/docs/release_notes/compatibility/) | 存在格式相容性中斷 | 搜尋索引；主報告不據此推定所有版本可互開 |
| [OpenTTD saveload.h](https://github.com/OpenTTD/OpenTTD/blob/master/src/saveload/saveload.h) | ChunkHandler、保存與載入、引用索引及 FixPointers | 已讀取原始碼頁面；master 為可變分支，重現時應固定 commit |
| [OpenTTD afterload.cpp](https://github.com/OpenTTD/OpenTTD/blob/master/src/saveload/afterload.cpp) | 版本條件、舊設定回填、天到秒的換算 | 已讀取原始碼相關段落；未宣稱所有舊檔支援範圍 |
| [OpenTTD Script Save and Load](https://wiki.openttd.org/en/Development/Script/Save%20and%20Load) | 腳本保存資料與 Load 的版本參數 | 官方 wiki 搜尋內容；不能外推成外掛任意版本自動相容 |
| [Unreal Saving and Loading Your Game](https://dev.epicgames.com/documentation/en-us/unreal-engine/saving-and-loading-your-game-in-unreal-engine) | USaveGame、世界資料搬移、slot、同步與非同步操作 | 已讀取文件；不是所有已上市遊戲內部存檔格式的證據 |
| [Protocol Buffers proto3 guide](https://protobuf.dev/programming-guides/proto3/) | 新欄位、tag 保留、unknown fields 及 JSON 轉換的損失 | 已讀取指南相關段落；wire 相容不能取代語意遷移 |
| [FlatBuffers Evolution](https://flatbuffers.dev/evolution/) | table 演進、欄位棄用、預設值及 struct 限制 | 已讀取文件；沒有提供本研究場景的效能比較 |
| [SQLite Atomic Commit](https://sqlite.org/atomiccommit.html) | 交易提交、刷新與故障假設 | 已讀取文件；主題主要說明 rollback journal，不代替 WAL 設定文件 |
| [SQLite Database File Format](https://sqlite.org/fileformat.html) | user_version 與應用版本責任 | 已讀取相關段落；SQLite 不使用 user_version 來遷移應用資料 |
| [SQLite Online Backup API](https://sqlite.org/backup.html) | 一致的資料庫備份流程 | 已讀取文件；執行期仍須處理鎖定及錯誤回傳 |
| [FlatBuffers Schema](https://flatbuffers.dev/schema/) | struct 欄位不可新增或棄用；預設值變更的解讀影響 | 已讀取相關段落，補充 Evolution 文件 |
| [Windows ReplaceFileW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilew) | 替換檔案、備份及錯誤行為 | 已讀取規格；未做實際檔案系統故障測試 |
| [Windows Flushing System Buffered I/O Data](https://learn.microsoft.com/en-us/windows/win32/fileio/flushing-system-buffered-i-o-data-to-disk) | FlushFileBuffers 與系統緩衝 | 官方搜尋內容；不構成所有硬體斷電耐久性保證 |
| [Steamworks Steam Cloud](https://partner.steamgames.com/doc/features/cloud?language=english) | 檔案同步、Auto Cloud 與 API | 已讀取文件；不支持應用語意自動合併的主張 |
| [Steam Support Steam Cloud](https://help.steampowered.com/en/faqs/view/68D2-35AB-09A9-7678) | 本機與雲端不同時的衝突選擇 | 官方搜尋內容；主報告的世代設計為應用建議 |

## 證據邊界

公開的引擎 API 說明能證明提供什麼介面，不能證明所有使用該引擎的遊戲都用同一持久模型。序列化框架的 schema 演進文件能證明特定編碼規則，不能保證任務、資產或模擬結果保持不變。

主報告沒有將商業宣傳當成性能結論，也未給格式速度排名。效能、容量與支持年限須按產品需求及實際測試決定。若要把研究轉成具體系統設計，還需選定語言、引擎、世界規模、支援平台及相容年限。

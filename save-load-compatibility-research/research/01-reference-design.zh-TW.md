# 存讀檔參考架構與遷移流程

研究日期：2026 年 10 月 14 日。以下為建議設計與偽碼，供桌面軟體、編輯器及遊戲調整使用；尚未實作或執行。返回[主報告](../README.zh-TW.md)。

## 分層責任

| 層 | 責任 | 應避免的耦合 |
| --- | --- | --- |
| Domain | 文件與遊戲規則 | 直接依賴檔案布局 |
| Snapshot | 擷取一致且可保存的狀態 | 背景工作讀取持續變動的物件 |
| Save Model | 固定 ID、明確型別、單位與缺值語意 | 沿用指標、類別布局及列舉順序 |
| Codec | 編解碼、長度限制、壓縮與驗證 | 執行任務補償等業務規則 |
| Migration | 舊模型轉成目前模型 | 根據當前 UI 設定改寫歷史資料 |
| Storage | 提交、備份、世代與同步 | 決定刪掉哪個歷史任務 |
| Hydration | 建立物件、接引用、重建衍生狀態 | 在驗證完成前修改目前世界 |

讀檔失敗時，仍應保留目前開啟的文件或遊戲。把解析、遷移與物件建立先放在獨立候選狀態，成功後才切換，可避免半套讀取結果污染現有工作。

## 建議容器

以下以「固定前導資訊加 manifest 加資料區塊」表達契約；實際偏移、欄位寬度、位元組序與編碼必須另寫規格，不可用 C++ struct 的記憶體布局代替。

```text
Prefix
  magic                  辨識檔案種類
  container_version      先判斷能否解碼容器
  manifest_length        設定上限後才讀取

Manifest
  document_id            文件或遊戲局的穩定識別
  generation_id          本次保存的唯一識別
  parent_generation_id   上一份保存的識別
  writer_build           除錯用途的產生程式版本
  required_features      缺少就不能安全操作的功能
  content_revision       資產或規則資料版本
  chunks[]
    id, schema_version, codec
    offset, stored_size, decoded_size, checksum

Chunks
  objects, world_regions, inventory, quests, extensions...
```

`generation_id` 是唯一值，跨裝置不能只靠本機遞增整數避免碰撞。容器版本表達布局變更，模組版本表達資料變更，`required_features` 表達必要能力；對未來格式只能在已理解的前導布局內讀取資訊，不能先用舊解析器硬讀全部。

checksum 可偵測損壞，不能證明檔案可信。若需要防止修改，另評估具金鑰的驗證；本機客戶端持有金鑰並不等同可信的伺服器。普通離線存檔的第一目標通常是資料完整性及可恢復性。

## 物件圖與穩定 ID

例如場景節點 `node-123` 參照網格 `mesh-45`，保存它們的 ID。讀取時先建立 ID 對物件的表，再接回引用，可支援循環引用與多個節點共用同一網格。

```text
objects:
  mesh-45:  { type: Mesh, vertices: ... }
  node-123: { type: Node, mesh_id: mesh-45, parent_id: node-100 }
```

型別也應使用受控且穩定的名稱或數值，不依賴編譯器 RTTI 名稱。刪掉欄位或 enum 值後保留其編號，避免未來把同一個數字解釋成不同事物。Protobuf 的欄位 reserved 規則可作為此原則的具體例子。[官方 schema 指南](https://protobuf.dev/programming-guides/proto3/)

載入分成幾步：先检查重複 ID 和型別，建立物件殼，再填欄位、解析引用、檢查禁止的循環，最後重建索引。一般有向圖可允許循環，但場景父子樹若禁止循環就要單獨驗證。必要引用缺失應停止載入；可選資產可用占位物件並保留原 ID 供修復。

OpenTTD 的公開介面明確區分載入與 `FixPointers`，是保存索引、讀取後接回引用的案例。[來源](https://github.com/OpenTTD/OpenTTD/blob/master/src/saveload/saveload.h)

## 逐版遷移範例

假設舊遊戲 v1 以整數 `gold` 保存貨幣，新 v2 改成最小單位 `gold_minor`，比例為 100；v3 增加任務模型。數值僅為示範政策。

```json
{"schema_version": 1, "player": {"id": "p-1", "gold": 12}}
```

```text
migrate_v1_to_v2(input):
  output = deep_copy(input)           # 保留其他欄位
  check old gold is a bounded integer
  output.player.gold_minor = checked_multiply(input.player.gold, 100)
  remove output.player.gold
  output.schema_version = 2
  return output

migrate_v2_to_v3(input):
  output = deep_copy(input)
  output.quests = make_legacy_quest_state(input)
  output.schema_version = 3
  return output

load(path):
  bytes = read_with_limit(path)
  container = validate_and_decode_container(bytes)
  require supported container and required_features
  dto = decode_using_recorded_schema(container)
  require oldest_supported_schema <= dto.version <= current_schema
  while dto.version < current_schema:
    validate_for_recorded_version(dto)
    next_dto = migrations[dto.version](dto)
    require next_dto.version == dto.version + 1
    dto = next_dto
  validate_current_schema_and_references(dto)
  candidate = build_world_in_isolation(dto)
  rebuild_derived_state(candidate)
  activate(candidate)
```

v1 的 12 枚貨幣因此轉成 1200 最小單位。不能直接改名稱並保留 12，否則讀取雖成功，數值意義已錯。

遷移應由來源版本控制，只執行需要的步驟；每步對相同輸入產生相同結果，不依賴時間、網路或目前的新遊戲預設。單步函式不必對「已遷移資料」再次執行仍相同，但調度器必須避免重複套用。長遷移中斷時可重新從原檔開始；若分段持久化，則保存進度與版本並用交易保護每一步。

所有受支援舊版需有完整路徑，v1 使用者可能直接更新到 v20。各模組分別遷移時還要處理依賴，例如先轉換物品 ID 再轉換任務所參照的物品。不要因每個模組單獨驗證成功，就忽略整份世界的跨模組一致性。

## 安全提交與恢復

建議的單檔流程是先保留最近一份已驗證版本，寫入同一檔案系統內的暫存檔，完成編碼及檢查後刷新，再執行平台的檔案替換。首次建立檔案與替換既有檔案可能使用不同 API；檢查每個回傳結果，只有提交成功才顯示保存完成。

Windows 可使用 `ReplaceFileW` 的替換及備份能力，並透過 `FlushFileBuffers` 刷新適當控制代碼；但 API 語意、失敗後殘留檔案、檔案系統及硬體仍須實測。POSIX 系統則另處理同檔案系統 rename 與檔案及父目錄的同步。不能把不同平台都縮成一句「rename 就保證斷電安全」。[Windows 替換規格](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilew)、[寫入緩衝刷新](https://learn.microsoft.com/en-us/windows/win32/fileio/flushing-system-buffered-i-o-data-to-disk)

升級舊存檔時，讀取與遷移先在記憶體或新世代完成，不在原檔上逐欄修改。保留升級前的檔案，使回退仍有資料可用。啟動恢復時檢查正式檔、已提交世代及備份，按完整性及提交資訊選擇；不要自動採用「修改時間最新」但只寫了一半的暫存檔。

同一 slot 的提交應經過單一佇列或版本比較，避免先發出的慢保存覆蓋後發出的新快照。背景編碼可並行，正式提交仍需按產品政策排序。多程序寫入另需檔案鎖或資料庫並行控制；程序內的佇列無法阻止另一個程序覆寫。

SQLite 方案應在適合的交易中提交資料與應用 schema 版本。若使用 WAL，不可將正在使用的主資料庫檔單獨複製當成完整備份；採用 SQLite Online Backup API 或其他官方支援的一致快照流程。[交易提交](https://sqlite.org/atomiccommit.html)、[Online Backup API](https://sqlite.org/backup.html)

## 大型文件與世界

區塊化可減少局部讀寫與記憶體峰值，但需要整體提交邊界。可把變動區塊寫成新世代不可變檔案，未變區塊沿用舊版本，最後提交指向完整集合的新 manifest。保留仍被任何已保留世代引用的區塊，稍後才回收。

跨區塊的交易，例如角色從區塊 A 移到 B，必須讓 manifest 同時指向一致的 A、B 和角色紀錄。不能只保存 dirty chunk 然後任意組合各區塊最新版本。多人線上遊戲的權威資料還需要伺服器交易與並行控制，此設計不能取代完整的後端持久化架構。

載入可先讀 manifest 及所需區域，再依距離或使用需求串流；背景處理解析及解壓，受執行緒限制的引擎物件建立則排回適當執行緒。壓縮和解碼都必須限制區塊數量、解壓後大小、巢狀深度及執行時間。

完整快照、增量日誌與事件紀錄可混合使用，但重播日誌會增加歷史事件語意與重播版本的維護成本。一般「恢復目前進度」不需要因此直接採用 event sourcing；如果需求是審計或精確回放，再專門設計事件版本、checkpoint 及重播規則。

## 未知資料與外掛

遇到未知資料先判斷其角色。可選縮圖可以忽略；未知的物理規則或約束求解器可能影響整個場景，應拒絕操作或唯讀開啟。未知區塊可作為不透明資料保留，但舊版修改已知物件後，未知區塊內的引用可能失效，原樣保留也不能直接視為無損編輯。

外掛區塊使用自己的命名空間、schema 版本與必要功能宣告。未安裝外掛時，保留可選區塊並顯示占位；只有外掛提供正確遷移器，才轉換其內部狀態。若原樣 round-trip 有依賴風險，就限制編輯與重存。

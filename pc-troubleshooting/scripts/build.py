"""Build the bilingual reports and offline HTML guide from a single event catalog."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
EVENTS = json.loads((ROOT / 'data/events.json').read_text(encoding='utf-8'))
SOURCES = json.loads((ROOT / 'data/sources.json').read_text(encoding='utf-8'))

INTRO = {
 'en': '''# PC troubleshooting and solutions

Research checked: **2026-10-12**. Primary language: English; a full Traditional Chinese counterpart is available.

Open [the offline bilingual guide](dist/index.html) in a browser. It starts in English, remembers your language choice when browser storage is available, and offers search and priority filters. No installation or network service is needed. Read the [general troubleshooting workflow](research/workflow.md) for other PC symptoms and evidence collection.

New case: [Device Manager: four Other devices and USB Port Reset Failed](research/device-manager-bluetooth-usb.md). Check disabled state, missing drivers and USB enumeration separately.

## Screenshot case: 2026-10-03

The supplied `Screenshot 2026-10-03 183937.png` shows Administrative Events, with a total of **29,756 entries**. That count is neither a crash count nor a count of faults from this incident. We have the list only, not General, XML, EVTX, dumps, Windows build or hardware details. Root cause is **undetermined**. No repair was performed on the PC.

| Displayed local time | Visible observation | Interpretation boundary |
| --- | --- | --- |
| 17:28 onward | Repeated DistributedCOM 10029/10016; Application Error 1000 at 17:33:29 | May be separate app/service issues; no causal link established |
| 18:38:01 / 18:38:08 | volmgr 161 / Kernel-Power 41 | Investigate possible dump failure and unexpected shutdown first |
| 18:38:19 | Three Kernel-EventTracing 28 entries | Need the payload provider GUID and status |
| 18:38:26 | EventLog 6008 and Eventlog 1101, plus DCOM entries | Read 6008's embedded shutdown time; examine logging loss if confirmed |
| 18:38:28–18:38:31 | CodexSandboxService 1003, CoworkVMService 1, AppModel-State warnings, DCOM and registration warning | Could be startup aftermath or independent problems; chronology alone does not establish cause |

Times above are transcribed from the screenshot; its time-zone offset is unknown. The list is not strictly chronological in every row. Sort exported logs by UTC and distinguish recorded time from the shutdown time embedded in 6008. A startup cluster is a **hypothesis**, not proof that all these events caused or followed the same crash.

## Recommended order

1. Preserve the logs and confirm the user's symptom; determine the actual incident time using 6008. Do not clear evidence.
2. Investigate 41/6008 and verify 161's full message and dump configuration.
3. Identify the executable behind 1000 and the exact targets behind 10029, 28, AppModel-State, 1003 and 1. Investigate reproducible functionality failures.
4. Compare 10016 with Microsoft's documented pattern and 360 with the intended enrollment/sign-in behavior. Do not chase warning count as a repair objective.

## Event catalog

Priority is proposed triage order, not a probability estimate. Entries below distinguish established general behavior from conditional message interpretations. Linked references support the named technology/workflow; they do not necessarily define every event ID. IDs 20/21/23/24 are grouped only for investigation; inspect each result separately.
''',
 'zh-TW': '''# PC 故障分析與解決辦法

查核日期：**2026-10-12**。英文為主要語言，另提供完整繁體中文對照。

以瀏覽器開啟[離線雙語查閱頁](dist/index.html)。預設英文；瀏覽器儲存可用時記住語言選擇，並支援搜尋與優先順序篩選。不需安裝或網路服務。其他 PC 症狀及證據蒐集請見[通用排查流程](research/workflow.zh-TW.md)。

新增個案：[裝置管理員：四個 Other devices 與 USB Port Reset Failed](research/device-manager-bluetooth-usb.zh-TW.md)。分開確認停用狀態、缺驅動與 USB 列舉失敗。

## 截圖個案：2026-10-03

提供的 `Screenshot 2026-10-03 183937.png` 顯示 Administrative Events，共 **29,756 筆**。這不是崩潰次數，也不是本次事故的故障數。目前只有清單，缺少一般訊息、XML、EVTX、傾印、Windows 組建與硬體資料。根因**尚未確定**，並未在 PC 執行任何修復。

| 顯示的本機時間 | 可見觀察 | 判讀界線 |
| --- | --- | --- |
| 17:28 起 | 重複 DistributedCOM 10029／10016；17:33:29 有 Application Error 1000 | 可能是不同程式／服務問題，因果尚未建立 |
| 18:38:01／18:38:08 | volmgr 161／Kernel-Power 41 | 優先查可能的傾印失敗與非正常關機 |
| 18:38:19 | 三筆 Kernel-EventTracing 28 | 需要事件資料中的提供者 GUID 與狀態 |
| 18:38:26 | EventLog 6008、Eventlog 1101 及 DCOM | 讀取 6008 內記載的關機時間；若確認日誌遺失則調查 |
| 18:38:28–18:38:31 | CodexSandboxService 1003、CoworkVMService 1、AppModel-State、DCOM 與註冊警告 | 可能為開機後影響或獨立問題；先後順序不能證明因果 |

時間依截圖抄錄，時區偏移未知；清單部分列也未嚴格按時間排序。匯出後以 UTC 排序，區分事件記錄時間與 6008 內的關機時間。開機群組只是**假設**，不能證明全部事件都是同一崩潰的原因或結果。

## 建議順序

1. 保留日誌並確認症狀，用 6008 找出真正事故時間；不要清除證據。
2. 調查 41／6008，確認 161 的完整訊息及傾印設定。
3. 識別 1000 的執行檔，以及 10029、28、AppModel-State、1003、1 的確切目標，處理可重現的功能故障。
4. 將 10016 與 Microsoft 已記載模式比對，360 則依預期註冊／登入需求判斷；不以警告數歸零為目標。

## 事件處理表

優先順序為建議排查次序，不代表機率估計。下方區分已知一般行為與須比對完整訊息的條件解讀。來源支持相關技術／流程，不一定定義每個事件 ID。20／21／23／24 僅為方便調查而分組，仍須各別讀取結果。
'''
}

def build_reports():
    for lang, suffix, nav in [('en', '', '**English** | [繁體中文](README.zh-TW.md)'), ('zh-TW', '.zh-TW', '[English](README.md) | **繁體中文**')]:
        out = [nav, '', INTRO[lang]]
        labels = ['Meaning', 'Evidence needed', 'Steps', 'Verify', 'Avoid', 'References'] if lang == 'en' else ['意義', '所需證據', '步驟', '驗證', '避免', '參考']
        priorities = {'first': 'Investigate first', 'symptom': 'Investigate if symptomatic', 'monitor': 'Compare and monitor'} if lang == 'en' else {'first':'優先追查', 'symptom':'有症狀時追查', 'monitor':'比對後觀察'}
        for e in EVENTS:
            c = e[lang]
            out += [f"### {e['provider']} — {', '.join(map(str,e['ids']))}\n", f"**{priorities[e['priority']]}** · {e['level']} · {c['title']}\n", f"**{labels[0]}:** {c['meaning']}\n", f"**{labels[1]}:** {c['evidence']}\n", f"**{labels[2]}:**\n"]
            out += [f'{i}. {s}' for i,s in enumerate(c['steps'],1)]
            out += ['', f"**{labels[3]}:** {c['verify']}\n", f"**{labels[4]}:** {c['avoid']}\n"]
            if e['sources']:
                out += [f"**{labels[5]}:** " + ' · '.join(f'[{SOURCES[k][0]}]({SOURCES[k][1]})' for k in e['sources']) + '\n']
            else:
                out += ['Event-specific authoritative definition was not established; steps are proposed diagnostics.\n' if lang == 'en' else '尚未建立事件專屬的權威定義；步驟為建議診斷方法。\n']
        out += ['## Files and maintenance\n' if lang == 'en' else '## 檔案與維護\n',
                ('[Workflow](research/workflow.md) · [Case template](cases/case-template.md)' if lang == 'en' else '[排查流程](research/workflow.zh-TW.md) · [個案範本](cases/case-template.zh-TW.md)') + ' · [Collector](scripts/Collect-Evidence.ps1)\n',
                'Edit `data/events.json` for paired event content and `data/sources.json` for checked references. Run `python scripts/build.py` to regenerate both reports and the offline page. Edit workflow and case files in matched language pairs. Raw evidence belongs in ignored `evidence/`; do not commit identifying logs/dumps.\n' if lang == 'en' else '成對事件內容修改 `data/events.json`，查核來源修改 `data/sources.json`。執行 `python scripts/build.py` 重建雙語報告與離線頁。流程與個案檔案需成對更新；原始證據存於忽略的 `evidence/`，勿提交可識別日誌／傾印。\n',
                '## Checked references\n' if lang == 'en' else '## 已查核來源\n']
        out += [f'- [{name}]({url})' for name,url in SOURCES.values()]
        (ROOT / f'README{suffix}.md').write_text('\n'.join(out) + '\n', encoding='utf-8')

def build_html():
    template = (ROOT / 'scripts/page.html').read_text(encoding='utf-8')
    payload = json.dumps({'events':EVENTS,'sources':SOURCES}, ensure_ascii=False).replace('<', '\\u003c')
    (ROOT / 'dist').mkdir(exist_ok=True)
    (ROOT / 'dist/index.html').write_text(template.replace('__CATALOG__',payload), encoding='utf-8')

if __name__ == '__main__':
    assert len({e['key'] for e in EVENTS}) == len(EVENTS)
    for event in EVENTS:
        assert all(k in SOURCES for k in event['sources'])
        for language in ('en','zh-TW'):
            assert all(event[language].get(k) for k in ('title','meaning','evidence','steps','verify','avoid'))
    build_reports()
    build_html()
    print(f'Built {len(EVENTS)} event groups in English and Traditional Chinese.')

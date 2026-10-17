# MCU 官方文件入口

查閱日期：2026-10-18。以下入口用於理解架構與工具設計，不構成品牌或產品推薦。實作時應固定使用專案所採版本的文件；latest 頁面會隨時間變動。

| 來源 | 支援的學習內容 | 使用邊界 |
| --- | --- | --- |
| [Arm CMSIS-Core Overview](https://arm-software.github.io/CMSIS_5/Core/html/) | Cortex-M 核心介面、初始化慣例與核心文件入口 | 此入口是 CMSIS 5 文件；不能替代實際晶片的周邊手冊，也不適用所有 MCU 架構 |
| [Zephyr Devicetree](https://docs.zephyrproject.org/latest/build/dts/index.html) | 硬體描述及初始設定的用途 | 屬於 Zephyr 的具體實作，不是所有 SDK 的共同格式 |
| [Zephyr Board Porting Guide](https://docs.zephyrproject.org/latest/hardware/porting/board_porting.html) | 板級硬體與接腳配置、board port 的責任 | 實作時須對照採用的 Zephyr 版本 |

選定第一塊開發板後，再補上該板的電路圖、晶片 datasheet、reference manual、errata、SDK 與 debugger 文件。課程階段、時數與專案規模是教學安排；資料率計算使用第一課明列的假設。

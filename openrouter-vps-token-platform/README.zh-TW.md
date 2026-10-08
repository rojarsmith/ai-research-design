[English](README.md) | **繁體中文**

# VPS 上的 OpenRouter AI 用量平台快速建置研究

研究日期：2026-10-09（Asia/Taipei）。

若目標是讓客戶註冊、儲值、取得平台 API Key，再按模型用量扣款，**New API 是本次比較中最接近現成平台的起點**。採單台 Linux VPS 與 Docker Compose，先限制模型與客戶數，可減少自行開發會員、錢包與管理後台的工作。

但 **OpenRouter 現行條款第 7.4 節明文禁止轉售模型 API 存取**，不能將一般帳戶直接視為轉售授權。應先取得明確涵蓋此商業模式的另行書面協議，或改用允許相應用途的上游；若先驗證產品，可以研究客戶自帶 OpenRouter Key 的自有 AI 應用。條款第 5 節對應用整合的描述不會自動排除轉售限制。[OpenRouter 條款](https://openrouter.ai/terms)

## 建議選擇

| 需求 | 建議起點 | 主要需補工作 |
| --- | --- | --- |
| 最快做出會員與用量額度平台 | New API | 上游授權、模型價格核對、支付設定、對帳與部署驗收 |
| 自有品牌前台與複雜路由 | LiteLLM 加自製會員及帳務服務 | 充值訂單、收款回調、不可重複入帳、退款與帳本 |
| 尚未取得 API 轉售授權，先驗證應用 | 自有 AI 應用加 OpenRouter OAuth | 用戶自行支付 OpenRouter 用量；平台收取應用服務費，仍須符合適用條款 |

New API 的錢包文件涵蓋儲值與訂閱；LiteLLM 提供虛擬 Key、預算和用量管理；OpenRouter OAuth 可取得用戶控制的 Key。以上是功能依據，商業適用性仍取決於實際產品與授權。[New API 錢包](https://docs.newapi.pro/zh/docs/guide/feature-guide/user/wallet)、[LiteLLM 虛擬 Key](https://docs.litellm.ai/docs/proxy/virtual_keys)、[OpenRouter OAuth](https://openrouter.ai/docs/guides/overview/auth/oauth)

## 文件導覽

- [方案比較與成本試算](research/01-feasibility-and-options.zh-TW.md)：商業模式、工具能力、授權差異、毛利與選擇理由。
- [VPS 建置路線與驗收](research/02-vps-mvp-roadmap.zh-TW.md)：部署步驟、最小產品範圍、工期估算、扣款與故障驗收。
- [查證來源與待確認事項](research/03-sources-and-open-questions.zh-TW.md)：官方資料、版本差異及可提交給 OpenRouter 的詢問草稿。

工期、VPS 規格與試算數字是規劃假設；本目錄交付研究文件，尚未部署服務或執行付費 API 呼叫。

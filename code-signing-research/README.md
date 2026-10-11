**English** | [繁體中文](README.zh-TW.md)

# SSL.com OV Code Signing Organization Validation

See also [OV prices, ten purchasing options, short terms, and provider reviews](pricing-and-providers.md), checked October 11, 2026.

Research date: October 11, 2026 (Asia/Taipei). This request concerns EMERGING DISPLAY TECHNOLOGIES CORP., Chinese registered name 全台晶像股份有限公司, Taiwan stock code 3038, Unified Business Number 89261652. The applicant confirms acting on behalf of the company. The scope is the three pending document categories and subsequent callback.

Three PDFs organize registration and contact evidence for SSL.com's review. The legal-existence PDF also includes the unchanged seven-page English Articles published on the company website. Covers and API extracts are applicant-prepared with source links and embedded original JSON, not government-issued certificates, D&B reports or signed authorization. SSL.com decides whether further formal documents are required.

## Upload Categories

| Portal category | Prepared PDF | Qualification |
| --- | --- | --- |
| Documentation of Legal Existence | [01 Registration and original English Articles](output/pdf/01-legal-existence-public-record.pdf) | MOEA registration plus seven unchanged Articles pages from the company website; 10 pages total. Government-certified documents or an approval letter may still be requested. |
| Documentation of Physical Existence | [02 Published company address](output/pdf/02-physical-existence-address-record.pdf) | TWSE address listing cross-checked against MOEA. A listing does not by itself prove current occupancy. |
| Documentation of Order Authorization | [03 Published company contact](output/pdf/03-order-authorization-contact-record.pdf) | TWSE switchboard listing matches the portal's request for third-party contact information. It does not prove a named applicant's authority. Complete the CA's authorization verification. |

[04 Optional authorization template](output/pdf/04-order-authorization-unsigned-template.pdf) is a printable, unsigned supplement for an officer with actual authority to complete. It is not SSL.com's prescribed form. Use a CA-provided form if required, and do not submit the blank template.

## Verified Company Details

| Item | Public record |
| --- | --- |
| Registered company | 全台晶像股份有限公司 |
| English name linkage | EMERGING DISPLAY TECHNOLOGIES CORP. is shown as the import/export vendor English name in the government English profile; this does not establish an English charter name. |
| Business number / stock code | 89261652 / 3038 |
| Status / incorporation | 核准設立 (approved incorporation, informal translation) / September 23, 1994 |
| Current registration authority | 經濟部產業園區管理局; Bureau of Industrial Parks, MOEA in the government English profile. This does not identify the original 1994 approving agency. |
| Last approved change | June 4, 2025; distinct from the retrieval date |
| Address | 高雄市前鎮區中一路5號 |
| TWSE English address verbatim | No. 5, Central 1st Rd., Qianzhen Dist.,KAOHSIUNG TAIWAN R.O.C |
| Company switchboard | 07-8124832; international format +886-7-8124832 |
| TWSE issue dates | PDFs use JSON dated ROC 1151010 = October 10, 2026. The CSV is dated 1151011 = October 11, 2026; company name, business number, both addresses and switchboard agree. |

Sources: [government English profile](https://findbiz.nat.gov.tw/fts/company/89261652?fhl=en), [MOEA dataset definitions](https://data.gov.tw/dataset/22197), and [TWSE company API](https://openapi.twse.com.tw/v1/opendata/t187ap03_L). Original API downloads and a SHA-256 manifest are in `sources/`. The English-name linkage was checked through web research; direct retrieval of the government HTML was blocked and no original HTML or printout was captured.

The company [governance page](https://www.edtc.com/corporate-governance/) links the [English Articles PDF](https://www.edtc.com/wp-content/uploads/2025/08/Articles-of-Incorporation.pdf), whose last listed amendment is May 28, 2025. Company administration should confirm no later version supersedes it. Article 1 uses Emerging Display Technologies Corporation; the order and import/export name use EMERGING DISPLAY TECHNOLOGIES CORP. The difference is disclosed for CA review. Original pages are appended as pages 4 through 10 of PDF 01.

Applicant name, title, email, extension and order number remain unprovided. Public spokesperson details cannot establish the applicant's identity. The actual order has not been inspected; use these records to compare its details.

## Submission and Verification

1. Compare the order name, Taiwan address and telephone against the public records.
2. Upload 01, 02 and 03 into their respective categories, accurately describing them as public-record extracts.
3. Supply the official source links and ask the validation team whether MOEA/TWSE sources meet its requirements. TWSE is not explicitly named in the SSL.com examples reviewed. If necessary, obtain existing incorporation approval documents, registration amendments or Articles from company administration; follow the CA's requirements for translations.
4. Arrange for the switchboard to route a validation callback to the authorized applicant. Request a manual callback when needed for an extension. A personal mobile is not independently verified by the company listing.
5. Complete remaining CA checks, then activate the certificate using the purchased key-storage option.

SSL.com's [OV requirements](https://www.ssl.com/faqs/ssl-ov-validation-requirements/) allow government or reliable third-party source URLs, with D-U-N-S helping expedite checks. Its [callback procedure](https://www.ssl.com/how-to/callbacks-for-ov-certificates/) requires a validated telephone and successful contact. The order-specific request controls any additional documents; the general guidance does not guarantee acceptance of these extracts.

The [signing-certificate workflow](https://www.ssl.com/how-to/validation-process-for-document-signing-code-signing-and-ev-code-signing-certificates/) explains compliant hardware/cloud key storage and the 2026 maximum certificate validity of 458 days. A multi-year purchase may require reissuance. Determine whether the order uses eSigner, a token or an HSM after resolving validation.

The [Traditional Chinese guide](README.zh-TW.md#可直接貼給-sslcom-的英文訊息) includes an English message ready to paste to the validation team. It has not been sent.

## Files and Status

`output/pdf/` contains the evidence PDFs and template. `sources/` retains MOEA and TWSE original downloads, the unmodified 3038 row, the company-published original English Articles, and the source manifest. `build_validation_pdfs.py` reproduces the PDFs; follow the PDF skill's artifact-operation marker requirement before authoring.

The PDFs were rendered and visually inspected locally. No SSL.com login, order inspection, upload, external message, signature or subscriber agreement acceptance has been performed. Preparing documents does not establish certificate issuance.

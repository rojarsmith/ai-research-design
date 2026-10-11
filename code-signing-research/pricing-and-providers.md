**English** | [繁體中文](pricing-and-providers.zh-TW.md) | [Validation documents](README.md)

# OV code signing prices, short terms, and provider reviews

Checked October 11, 2026, Asia/Taipei. Scope: ordinary Windows Authenticode signing for organizations. Public prices are not completed checkout quotes. USD amounts generally exclude applicable taxes, exchange costs, and international delivery.

## Findings

My-SSL advertises Certum Standard with SimplySign cloud signing at US$99 for one year or US$149 total for two years. This meets a US$150 budget at the advertised pretax price, subject to CA approval. Standard supports both individuals and organizations: the company must apply under its organization identity. Public service complaints warrant caution.[Product](https://my-ssl.com/code-signing)

SSL.com charges US$129 for a one-year OV certificate, with eSigner extra. One full annual basic cloud subscription costs US$180, giving US$309 combined. SSLmentor advertises a one-year Certum cloud bundle at US$177 before VAT; its independent support reputation was not assessed here.[SSL.com certificate](https://www.ssl.com/products/software-integrity/code-signing/ov/), [eSigner pricing](https://www.ssl.com/guide/esigner-pricing-for-code-signing/), [SSLmentor](https://www.sslmentor.com/certum/certumcodecloud)

## Ten purchasing options

These are CA-direct and reseller options, not ten independent CAs or a market-share ranking. Complete cloud bundles and incomplete certificate-only quotes cannot be ranked together by total cost.

| # | Option and source | Public price | Included / unresolved costs |
| --- | --- | --- | --- |
| 1 | [My-SSL / Certum Standard Cloud](https://my-ssl.com/code-signing) | US$99 / one year; US$149 total / two years | SimplySign; no shipped token; tax and issuance approval apply |
| 2 | [SSLmentor / Certum Cloud](https://www.sslmentor.com/certum/certumcodecloud) | US$177 / one year; US$264 total / two years | Cloud included; VAT excluded; listed limit 5,000 signatures/month and two-hour authenticated sessions |
| 3 | [SSL.com OV + eSigner](https://www.ssl.com/products/software-integrity/code-signing/ov/) | US$129 + US$180 = US$309 | Certificate plus one full annual basic cloud plan; 240 signatures/year, US$1 overage; initial 30-day free trial also offered |
| 4 | [GoGetSSL Cloud / DigiCert](https://www.gogetssl.com/sslcerts/cloud-codesigning-ssl/) | US$425 / one year | Cloud, one user seat, 1,000 signatures |
| 5 | [Certum direct Cloud](https://shop.certum.eu/standard-code-signing-in-the-cloud.html) | From €209 | Cloud product; exact one-year checkout and inconsistent stock text require confirmation |
| 6 | [CheapSSLsecurity / DigiCert FastSSL](https://cheapsslsecurity.com/fastssl/code-signing-certificate.html) | US$149 / one-year certificate | Delivery method required; complete token/cloud/HSM cost not verified |
| 7 | [SignMyCode Windows OV](https://signmycode.com/windows-code-signing) | US$299.99 / one-year certificate | Delivery and storage costs require confirmation; two/three-year purchases require existing HSM |
| 8 | [SSL2BUY / Sectigo OV](https://www.ssl2buy.com/sectigo-code-signing-certificate.php) | US$300 / one-year certificate | US$225/year advertising requires three years, US$675 total; delivery cost unresolved |
| 9 | [DigiCert direct + KeyLocker](https://www.digicert.com/buy) | Formal quote needed | Page inconsistently shows US$65/month and US$996 annual total; explicitly a 12-month renewing subscription; 1,000 signatures/year |
| 10 | [GlobalSign direct OV](https://www.globalsign.com/en/code-signing-certificate) | Quote needed | Current complete price not verified; confirm token/HSM and delivery |

Multiyear service purchases do not imply a single certificate remains valid for all purchased years. Confirm reissuance terms. SimplySign operator authentication does not establish unattended CI/CD compatibility.[Certum validity policy](https://shop.certum.eu/standard-code-signing-in-the-cloud.html)

## Market-share evidence

No verifiable current global top-ten ranking specifically for OV code-signing certificates was found. TLS market share is a different market, and resellers must not be double-counted as issuers. An NDSS 2026 paper compares CA distributions in signed PE file samples; sample file share is not current global OV certificate sales, revenue, or installed publisher share.[Primary paper](https://www.ndss-symposium.org/wp-content/uploads/2026-f2857-paper.pdf)

## Six months or less

None of the traditional organization certificate purchase options verified here offers a public six-month-or-shorter term. Monthly cloud charges may still accompany an annual certificate or annual contract.

SSL.com basic eSigner is US$20/month for 20 signatures, with US$1 overage and an initial unlimited 30-day free trial. US$129 certificate plus six paid months is US$249; plus one paid month is US$149. These are arithmetic examples, not short-term certificates or confirmed safe cancellation strategies. Actual billing and trial dates depend on the order.[Rates](https://www.ssl.com/guide/esigner-pricing-for-code-signing/)

The official cancellation flow uses REVOKE and warns that a cloud-only certificate will be revoked, requiring reissuance to recover. Do not assume signing and then canceling leaves an active certificate or that timestamped signatures are unaffected by revocation. Obtain written clarification before relying on a short subscription.[Cancellation guide](https://www.ssl.com/how-to/how-to-cancel-esigner-subscription/)

Microsoft Azure Artifact Signing, formerly Trusted Signing, offers Basic at US$9.99/month for 5,000 signatures: US$59.94 for six months before overage or other Azure use. However, Taiwan is absent from the current organization eligibility list for Public Trust. Selecting a US hosting region does not change company eligibility. Private Trust is not a substitute for public distribution. This is a hosted signing service, not a conventional customer-held OV certificate.[Price](https://azure.microsoft.com/en-us/products/artifact-signing), [eligibility](https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart)

## My-SSL and SSL.com reviews

At retrieval, My-SSL's Trustpilot profile showed 2.3/5 from six reviews, including complaints about Standard Code Signing issuance, support, and refunds. SSL.com's profile showed 4.9/5 from 3,667 reviews, including code-signing support praise and some issuance, refund, and billing complaints. Its aggregate also covers other certificate products; it is not an OV success rate. Samples may be unrepresentative. Customer allegations were not independently verified and do not establish fraud or guarantee outcomes.[My-SSL reviews](https://www.trustpilot.com/review/my-ssl.com), [SSL.com reviews](https://www.trustpilot.com/review/ssl.com)

My-SSL sells Certum/SimplySign services; reseller support and CA issuance are separate responsibilities. Its refund policy names Verifold LLC and distinguishes Paddle from other payment processors. Confirm company eligibility, complete costs, and applicable refund conditions before payment.[Refund policy](https://my-ssl.com/refund-policy)

Assessment: the evidence does not support choosing My-SSL first for a deadline-sensitive company release. SSL.com remains a usable candidate with subscription and cancellation costs considered. SSLmentor is a US$177 quote candidate, not an independently established service-quality recommendation. An existing SSL.com purchaser should inspect the actual storage choice before switching; a different CA still requires organization and applicant validation.

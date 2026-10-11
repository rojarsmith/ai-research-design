"""Build traceable public-record extracts; this does not issue official certificates."""
from pathlib import Path
import json
from html import escape
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pypdf import PdfReader, PdfWriter

BASE = Path(__file__).resolve().parent
OUT = BASE / 'output' / 'pdf'
TMP = BASE / 'tmp' / 'pdfs'
SRC = BASE / 'sources'
OUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)
pdfmetrics.registerFont(TTFont('JhengHei', 'C:/Windows/Fonts/msjh.ttc', subfontIndex=0))
styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name='Mixed', fontName='JhengHei', fontSize=9, leading=14, spaceAfter=7))
styles.add(ParagraphStyle(name='SmallMixed', fontName='JhengHei', fontSize=7.5, leading=11, spaceAfter=6, splitLongWords=True))
styles['Title'].fontName = 'Helvetica-Bold'
styles['Title'].fontSize = 22
styles['Title'].leading = 26
styles['Title'].alignment = 0
styles['Heading2'].fontName = 'Helvetica-Bold'
styles['Heading2'].textColor = colors.HexColor('#184764')
styles['Heading2'].fontSize = 12
styles['Heading2'].leading = 16
gov_raw = (SRC / 'moea-company-89261652.json').read_bytes()
gov = json.loads(gov_raw)[0]
twse = json.loads((SRC / 'twse-3038-record.json').read_text(encoding='utf-8'))
manifest = json.loads((SRC / 'source-manifest.json').read_text(encoding='utf-8'))
gov_url = next(x['url'] for x in manifest if x['file'] == 'moea-company-89261652.json')
twse_url = 'https://openapi.twse.com.tw/v1/opendata/t187ap03_L'
registry_url = 'https://findbiz.nat.gov.tw/fts/company/89261652?fhl=en'
company = 'EMERGING DISPLAY TECHNOLOGIES CORP.'
assert gov['Business_Accounting_NO'] == twse['營利事業統一編號'] == '89261652'
assert gov['Company_Name'] == twse['公司名稱']
assert gov['Company_Location'] == twse['住址']

def p(text, small=False):
    return Paragraph(escape(str(text)).replace('\n', '<br/>'), styles['SmallMixed' if small else 'Mixed'])

def h(text):
    return Paragraph(escape(text), styles['Heading2'])

def table(rows, widths=(155, 344)):
    t = Table([[p(k, True), p(v)] for k, v in rows], colWidths=widths, hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#EDF3F7')),
        ('BOX', (0, 0), (-1, -1), .4, colors.HexColor('#C5D2DC')),
        ('LINEBELOW', (0, 0), (-1, -1), .3, colors.HexColor('#DCE4EA')),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    return t

def source(title, url):
    return [p(title), Paragraph('<link href="' + escape(url, quote=True) + '" color="#184764">' + escape(url) + '</link>', styles['SmallMixed'])]

def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor('#C5D2DC'))
    canvas.line(48, 40, A4[0]-48, 40)
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(colors.HexColor('#526571'))
    canvas.drawString(48, 27, 'OV Code Signing | 89261652 | Prepared 2026-10-11')
    canvas.drawRightString(A4[0]-48, 27, str(doc.page))
    canvas.restoreState()

def build(filename, story, attachments=(), append_pdfs=()):
    temp = TMP / filename
    SimpleDocTemplate(str(temp), pagesize=A4, rightMargin=48, leftMargin=48,
                      topMargin=44, bottomMargin=55, title=filename.replace('-', ' '),
                      author='Prepared for applicant review').build(story, onFirstPage=footer, onLaterPages=footer)
    writer = PdfWriter()
    writer.clone_document_from_reader(PdfReader(temp))
    for original_pdf in append_pdfs:
        writer.append(str(original_pdf), import_outline=False)
    for name, content in attachments:
        writer.add_attachment(name, content)
    with (OUT / filename).open('wb') as f:
        writer.write(f)
    print(filename, len(PdfReader(OUT / filename).pages), 'pages')

def opening(title, slot):
    return [Paragraph(title, styles['Title']), p(company), p(gov['Company_Name']),
            p('SSL.com upload category: ' + slot), p('Public-record extract | Retrieved 2026-10-11 (Asia/Taipei)'), Spacer(1, 9)]

common_twse = [
    ('出表日期 / Source issue date', twse['出表日期'] + ' (ROC 115/10/10 = 2026-10-10)'),
    ('公司代號 / Stock code', twse['公司代號']),
    ('公司名稱 / Company name', twse['公司名稱']),
    ('英文簡稱 / English abbreviation', twse['英文簡稱']),
    ('營利事業統一編號 / Business number', twse['營利事業統一編號']),
    ('住址 / Address', twse['住址']),
    ('英文通訊地址 / English mailing address', twse['英文通訊地址']),
    ('總機電話 / Switchboard', twse['總機電話']),
    ('網址 / Website', twse['網址']),
]
twse_attachment = json.dumps(twse, ensure_ascii=False, indent=2).encode('utf-8')

story = opening('Documentation of\nLegal Existence', 'Documentation of Legal Existence')
story += [h('Government registration record'), table([
    ('Chinese registered name', gov['Company_Name']), ('Requested English name', company),
    ('Unified Business Number', gov['Business_Accounting_NO']),
    ('Registration status', gov['Company_Status_Desc'] + ' / Approved incorporation (informal translation)'),
    ('Date of incorporation', '1994-09-23 (source: ROC ' + gov['Company_Setup_Date'] + ')'),
    ('Registration authority', gov['Register_Organization_Desc'] + '\nBureau of Industrial Parks, MOEA (English label from government registry)'),
    ('Registered address', gov['Company_Location']),
    ('Last approved change', '2025-06-04 (source: ROC ' + gov['Change_Of_Approval_Data'] + ')'),
]), Spacer(1, 10), h('English name linkage'),
    p('The government English company-profile page lists EMERGING DISPLAY TECHNOLOGIES CORP. as the Import Export Vendor English Name for business number 89261652. This is an import/export name linkage, not a claim that an English charter name has been certified.'),
    *source('Government public profile (English name linkage)', registry_url),
    p('The cover and API extract are applicant-prepared, not a government-issued certificate or certified translation. Appendix B includes the company-published English Articles of Incorporation, unchanged. The registration authority shown is the current registry authority, not a determination of the original 1994 approving agency. Obtain the historical approval letter if SSL.com specifically requires that agency.', True),
    PageBreak(), h('Appendix A - Government API response'),
    p('All returned fields are reproduced below. English headings on the first page are explanatory labels.'),
    table(list(gov.items())), Spacer(1, 8),
    *source('MOEA company registration API - original response', gov_url),
    *source('Government dataset description and field definitions', 'https://data.gov.tw/dataset/22197'),
    PageBreak(), h('Appendix B - Company-published Articles of Incorporation'),
    p('The following seven pages are appended from the English PDF linked by the company\'s Corporate Governance page. Original pages and their content have not been rewritten or annotated. The original downloaded PDF is also embedded as an attachment.'),
    *source('Company source index', 'https://www.edtc.com/corporate-governance/'),
    *source('Original English Articles PDF', 'https://www.edtc.com/wp-content/uploads/2025/08/Articles-of-Incorporation.pdf'),
    table([('Last amendment listed', 'May 28, 2025 (twentieth amendment, original PDF page 7)'),
           ('Downloaded on', 'October 11, 2026'),
           ('Document status', 'Company-published English version; no certification or government approval stamp is asserted.'),
           ('Name difference for CA review', 'Requested / government import-export name: EMERGING DISPLAY TECHNOLOGIES CORP.\nArticle 1 uses: Emerging Display Technologies Corporation.\nPlease confirm the accepted certificate subject name; the original has not been changed.')]),
    Spacer(1, 10), p('The file is the version currently linked on the company website at retrieval. Company administration should confirm that it remains current. This attachment is an existing published charter, not a newly drafted authorization or a company registration approval letter.', True)]
articles = SRC / 'edt-articles-of-incorporation-en-original.pdf'
build('01-legal-existence-public-record.pdf', story,
      [('moea-company-89261652.json', gov_raw), (articles.name, articles.read_bytes())], [articles])

story = opening('Documentation of\nPhysical Existence', 'Documentation of Physical Existence')
story += [h('Address published by Taiwan Stock Exchange'), table([
    ('Company / stock code', gov['Company_Name'] + ' / 3038'),
    ('Unified Business Number', twse['營利事業統一編號']),
    ('Address as published', twse['住址']),
    ('English address as published', twse['英文通訊地址']),
    ('Source issue date', '2026-10-10 (source: ' + twse['出表日期'] + ')'),
]), Spacer(1, 10), h('Sources for independent verification'),
    *source('Taiwan Stock Exchange - listed company basic information; locate company code 3038 or business number 89261652', twse_url),
    *source('Government dataset catalogue', 'https://data.gov.tw/dataset/18419'),
    *source('Government registration record - same registered address', registry_url),
    p('This PDF reproduces a public address listing. It is not a site inspection, lease, utility bill, or D&B report. The listing does not itself establish current occupancy. SSL.com must determine whether this source is acceptable and whether additional physical-presence evidence is required. Confirm the order address against the listing before upload.', True),
    PageBreak(), h('Appendix A - TWSE company record extract'), p('Original field names and values; source issue date retained.'),
    table(common_twse), Spacer(1, 10), *source('Official CSV alternative', 'https://mopsfin.twse.com.tw/opendata/t187ap03_L.csv'),
    p('The complete 3038 JSON record is embedded as twse-3038-record.json. The complete downloaded dataset and SHA-256 manifest are preserved in the local research sources directory.', True)]
build('02-physical-existence-address-record.pdf', story, [('twse-3038-record.json', twse_attachment)])

story = opening('Documentation of\nOrder Authorization', 'Documentation of Order Authorization')
story += [h('Third-party published company contact information'), table([
    ('Company / stock code', gov['Company_Name'] + ' / 3038'),
    ('Unified Business Number', twse['營利事業統一編號']),
    ('Switchboard as published', twse['總機電話']),
    ('International dialing format', '+886-7-8124832 (normalized from the published Taiwan number)'),
    ('Address as published', twse['住址']),
    ('Source issue date', '2026-10-10 (source: ' + twse['出表日期'] + ')'),
]), Spacer(1, 10), *source('Taiwan Stock Exchange company-contact listing', twse_url),
    *source('Government dataset catalogue - includes switchboard telephone field', 'https://data.gov.tw/dataset/18419'),
    h('Authorization verification remains with SSL.com'),
    p('This extract supplies the third-party contact information requested by the upload prompt. It does not establish a named applicant\'s employment or authority, and it is not a signed authorization. SSL.com should independently validate the source and perform its required callback or other authorization check. The applicant should arrange for the company switchboard to route the validation call to the actual authorized contact.'),
    p('The public contact belongs to the company. No personal name, title, applicant email, order number, extension, or signature has been inferred. An optional separate authorization template is provided for company completion only if needed.', True),
    PageBreak(), h('Appendix A - TWSE company record extract'), table(common_twse), Spacer(1, 10),
    *source('Official CSV alternative', 'https://mopsfin.twse.com.tw/opendata/t187ap03_L.csv'),
    p('Original 3038 JSON record embedded. This contact record is applicant-prepared from published data; it is not a D&B certificate or confirmation from SSL.com.', True)]
build('03-order-authorization-contact-record.pdf', story, [('twse-3038-record.json', twse_attachment)])

story = [Paragraph('Company Authorization Letter', styles['Title']),
         p('Template - complete and sign before submission. Optional supplement; not an SSL.com prescribed form.'),
         p('To: SSL.com Validation Team'), p('Organization: ' + company),
         p('Chinese registered name: ' + gov['Company_Name'] + ' | Unified Business Number: 89261652'),
         p('SSL.com order / reference number: __________________________________________________'), Spacer(1, 9),
         p('I, the undersigned, confirm that I have authority to authorize this certificate request on behalf of the organization named above. I authorize the following person to request and coordinate organization validation for an SSL.com OV Code Signing certificate for this organization.'),
         table([('Authorized requester name', '_______________________________________________'),
                ('Requester job title / department', '_______________________________________________'),
                ('Requester corporate email', '_______________________________________________'),
                ('Company callback number', '+886-7-8124832 (public record; confirm current routing)'),
                ('Requester extension', '_______________________________________________'),
                ('Order organization address', '_______________________________________________\n_______________________________________________')]),
         Spacer(1, 12), p('The organization can be contacted through its independently published company telephone number to confirm this request and the requester\'s authority. This letter supplements that verification.'),
         table([('Authorizing officer name', '_______________________________________________'),
                ('Officer title', '_______________________________________________'),
                ('Officer corporate email', '_______________________________________________'),
                ('Officer signature', '_______________________________________________'),
                ('Date (YYYY-MM-DD)', '_______________________________________________')]), Spacer(1, 12),
         p('Completion instructions: use an officer or other person with actual authority to approve the request; confirm all details; sign using the method SSL.com accepts. Add company letterhead or seal only if company procedure or SSL.com requires it. Do not submit this blank template. This letter does not independently verify a phone number and does not authorize acceptance of additional subscriber agreements.', True)]
build('04-order-authorization-unsigned-template.pdf', story)

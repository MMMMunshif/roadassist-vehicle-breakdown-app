from pathlib import Path
from playwright.sync_api import sync_playwright
r=Path.cwd();f=r/'tools/previews/payment-card';o=r/'build/previews/payment-card';o.mkdir(parents=True,exist_ok=True)
with sync_playwright() as p:
 b=p.chromium.launch(executable_path=r'C:\Users\ZIMTHI\AppData\Local\ms-playwright\chromium-1208\chrome-win64\chrome.exe',headless=True)
 page=b.new_page(viewport={'width':900,'height':1100});errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 page.goto((f/'board.html').as_uri());page.wait_for_timeout(1000);page.screenshot(path=str(o/'preview.png'),full_page=True)
 page.goto((f/'index.html').as_uri()+'?embed=1&method=bank');page.locator('#confirm-paid').click();assert page.get_by_text('SANDBOX / NO REAL CHARGE').is_visible();assert not errors,errors
 print('PASS: card demo checkout; no browser errors.');b.close()

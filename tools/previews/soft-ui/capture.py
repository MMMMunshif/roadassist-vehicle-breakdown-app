from pathlib import Path
from playwright.sync_api import sync_playwright
r=Path.cwd();out=r/'build/previews/soft-ui';url=(r/'tools/previews/soft-ui/index.html').as_uri()
with sync_playwright() as p:
 b=p.chromium.launch(executable_path=r'C:\Users\ZIMTHI\AppData\Local\ms-playwright\chromium-1208\chrome-win64\chrome.exe',headless=True)
 page=b.new_page(viewport={'width':980,'height':1040},device_scale_factor=1)
 errors=[];page.on('pageerror',lambda e:errors.append(str(e)));page.goto(url);page.wait_for_timeout(800)
 print(errors);assert page.locator('.phone').count()==2
 assert page.locator('img').evaluate_all('(xs)=>xs.every(x=>x.complete && x.naturalWidth>0)')
 page.screenshot(path=str(out/'soft-ui-light.png'),full_page=True)
 page.get_by_role('switch').click();assert page.get_by_role('switch').get_attribute('aria-checked')=='false'
 page.get_by_role('switch').click();page.get_by_role('button',name='Light / dark').click();page.wait_for_timeout(250)
 page.screenshot(path=str(out/'soft-ui-dark.png'),full_page=True)
 assert not errors,errors
 print('PASS: two dashboards, original assets loaded, sample availability switch, dark/light mode; no browser errors.')
 b.close()

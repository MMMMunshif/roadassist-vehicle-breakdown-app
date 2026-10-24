from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path.cwd();folder=root/'tools/previews/workflow-premium';out=root/'build/previews/workflow-premium';url=(folder/'index.html').as_uri()
with sync_playwright() as p:
 b=p.chromium.launch(executable_path=r'C:\Users\ZIMTHI\AppData\Local\ms-playwright\chromium-1208\chrome-win64\chrome.exe',headless=True)
 page=b.new_page(viewport={'width':1580,'height':1090},device_scale_factor=1)
 errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 page.goto(url);page.wait_for_timeout(1600)
 assert page.locator('img').evaluate_all('(imgs)=>imgs.every(i=>i.complete&&i.naturalWidth>0)')
 page.screenshot(path=str(out/'workflow-dark.png'),full_page=True)
 page.get_by_role('button',name='Light / dark',exact=True).click();page.screenshot(path=str(out/'workflow-light.png'),full_page=True)
 page.evaluate('advanceDriver()');page.locator('[data-mode=driver]').get_by_role('button',name='Confirm provider arrival').click();page.get_by_role('button',name='Yes, provider is here').click();assert page.get_by_text('You are in good hands.',exact=True).is_visible()
 page.locator('[data-mode=provider]').get_by_role('button',name='Finish service & create bill').click();page.locator('#inspection').fill('-1');page.get_by_role('button',name='Send final bill',exact=True).click();assert page.get_by_role('dialog',name='One final service bill').count()==1;page.locator('#inspection').fill('300');page.get_by_role('button',name='Send final bill',exact=True).click();assert page.get_by_text('Service finished.',exact=True).is_visible()
 page.evaluate('retryDemo()');assert page.locator('#select-next').is_disabled();page.locator('#retry-card').get_by_role('button',name='Retry',exact=True).click();assert page.locator('#select-next').is_enabled()
 page.locator('.choose-card').nth(1).click();assert '140' in page.locator('#select-next').inner_text();page.locator('#select-next').click();page.get_by_role('button',name='Send request',exact=True).click();assert page.get_by_text('Request sent.',exact=True).is_visible();page.get_by_role('dialog').get_by_role('button',name='Close',exact=True).click()
 ctx=b.new_context(viewport={'width':360,'height':820},record_video_dir=str(out/'recordings'),record_video_size={'width':360,'height':820})
 d=ctx.new_page();d.goto(url+'?screen=bill&embed=1');d.wait_for_timeout(850)
 d.get_by_role('button',name='Review & choose payment',exact=True).click();assert d.locator('#confirm-paid').is_disabled();d.wait_for_timeout(650)
 d.get_by_role('button',name='Cash',exact=True).click();d.wait_for_timeout(600);d.locator('#confirm-paid').click();d.wait_for_timeout(1300)
 assert d.get_by_text('Waiting for provider receipt',exact=True).is_visible();assert d.get_by_text('Payment received',exact=True).count()==0
 d.evaluate('receiptDemo()');d.wait_for_timeout(1100);d.get_by_role('dialog').get_by_role('button',name='View your bill',exact=True).click();d.wait_for_timeout(600)
 assert d.get_by_text('Payment received',exact=True).is_visible()
 video=d.video;ctx.close();video.save_as(str(out/'bill-payment-motion.webm'))
 ctx=b.new_context(viewport={'width':360,'height':820},record_video_dir=str(out/'recordings'),record_video_size={'width':360,'height':820})
 d=ctx.new_page();d.goto(url+'?screen=driver&embed=1');d.wait_for_timeout(1300);d.evaluate('advanceDriver()');d.wait_for_timeout(1000);d.get_by_role('button',name='Confirm provider arrival').click();d.wait_for_timeout(650);d.get_by_role('button',name='Yes, provider is here').click();d.wait_for_timeout(1100)
 video=d.video;ctx.close();video.save_as(str(out/'driver-status-motion.webm'))
 page.emulate_media(reduced_motion='reduce');page.goto(url);page.get_by_role('button',name='Review & choose payment',exact=True).click();assert page.locator('.sheet').evaluate('(e)=>parseFloat(getComputedStyle(e).animationDuration)')<.01
 page.keyboard.press('Escape');assert page.get_by_role('dialog').count()==0
 assert not errors,errors
 print({'checks':'all four previews rendered; arrival, non-negative bill validation, request selection, retry lock/recovery, payment pending vs receipt confirmed, modal escape and reduced motion passed','browser_errors':errors})
 b.close()

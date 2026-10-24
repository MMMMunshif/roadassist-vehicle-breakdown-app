from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path.cwd();folder=root/'tools/previews/payment-modern';out=root/'build/previews/payment-modern';url=(folder/'index.html').as_uri()
with sync_playwright() as p:
 b=p.chromium.launch(executable_path=r'C:\Users\ZIMTHI\AppData\Local\ms-playwright\chromium-1208\chrome-win64\chrome.exe',headless=True)
 page=b.new_page(viewport={'width':900,'height':1100},device_scale_factor=1)
 errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 page.goto((folder/'board.html').as_uri());page.wait_for_timeout(1000);page.screenshot(path=str(out/'payment-method-preview.png'),full_page=True)
 page.set_viewport_size({'width':390,'height':844});page.goto(url+'?screen=bill&embed=1');page.wait_for_timeout(650)
 assert page.get_by_role('dialog',name='Payment method').count()==1
 assert page.locator('#confirm-paid').is_disabled();assert page.locator('.pay-method[aria-pressed=true]').count()==0
 page.get_by_role('button',name='Cash Hand over directly').click();assert 'in cash' in page.locator('#confirm-paid').inner_text()
 page.get_by_role('button',name='Bank transfer Send to your provider').click();assert page.get_by_role('button',name='Ask for bank details').is_visible();assert page.locator('.pay-method[aria-pressed=true]').count()==1
 bounds=page.locator('#confirm-paid').bounding_box();assert bounds['y']+bounds['height']<844,bounds
 page.locator('#confirm-paid').click();assert page.get_by_text('Waiting for provider receipt',exact=True).is_visible();assert page.get_by_text('Payment received',exact=True).count()==0
 ctx=b.new_context(viewport={'width':390,'height':844},record_video_dir=str(out/'recordings'),record_video_size={'width':390,'height':844})
 d=ctx.new_page();d.goto(url+'?screen=bill&embed=1');d.wait_for_timeout(900)
 d.get_by_role('button',name='Cash Hand over directly').click();d.wait_for_timeout(1100)
 d.get_by_role('button',name='Bank transfer Send to your provider').click();d.wait_for_timeout(1400)
 d.get_by_role('button',name='Cash Hand over directly').click();d.wait_for_timeout(900);d.locator('#confirm-paid').click();d.wait_for_timeout(1400)
 video=d.video;ctx.close();video.save_as(str(out/'payment-method-motion.webm'))
 page.emulate_media(reduced_motion='reduce');page.goto(url+'?screen=bill&embed=1');assert page.locator('.sheet').evaluate('(e)=>parseFloat(getComputedStyle(e).animationDuration)')<.01
 page.keyboard.press('Escape');assert page.get_by_role('dialog').count()==0
 assert not errors,errors
 print({'checks':'unselected default, cash/bank selection, method-specific confirmation, visible CTA, receipt stays pending, Escape and reduced motion passed','browser_errors':errors})
 b.close()

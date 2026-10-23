from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path.cwd();folder=root/'tools/previews/splash-welcome';out=root/'build/previews/splash-welcome';url=(folder/'index.html').as_uri()
with sync_playwright() as p:
 b=p.chromium.launch(executable_path=r'C:\Users\ZIMTHI\AppData\Local\ms-playwright\chromium-1208\chrome-win64\chrome.exe',headless=True)
 page=b.new_page(viewport={'width':1340,'height':1100},device_scale_factor=1)
 errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 page.goto((folder/'board.html').as_uri());page.wait_for_timeout(600)
 for f,t in zip(page.frames[1:],[4250,4560,5500]):f.evaluate('(t)=>freeze(t)',t)
 page.screenshot(path=str(out/'transition-storyboard.png'),full_page=True)
 page.set_viewport_size({'width':412,'height':892});page.goto(url+'?embed=1');page.evaluate('freeze(5500)')
 assert page.locator('.loading,[role=progressbar],.spinner').count()==0
 assert page.locator('.shared-mark').count()==1
 bounds=page.locator('.shared-mark').bounding_box();assert abs(bounds['x']-19)<1 and abs(bounds['y']-16)<1,bounds
 assert page.locator('.welcome-content').evaluate('(e)=>!e.inert')
 assert page.locator('.secondary').bounding_box()['y']+page.locator('.secondary').bounding_box()['height']<892
 page.screenshot(path=str(out/'welcome-ready-dark.png'))
 page.goto(url+'?embed=1&light=1');page.evaluate('freeze(5500)');page.screenshot(path=str(out/'welcome-ready-light.png'))
 ctx=b.new_context(viewport={'width':412,'height':892},record_video_dir=str(out/'recordings'),record_video_size={'width':412,'height':892})
 d=ctx.new_page();d.goto(url+'?embed=1');d.wait_for_timeout(6100)
 assert d.locator('img').evaluate_all('(imgs)=>imgs.every(i=>i.complete&&i.naturalWidth>0)')
 video=d.video;ctx.close();video.save_as(str(out/'handshake-to-welcome.webm'))
 page.emulate_media(reduced_motion='reduce');page.goto(url+'?embed=1');page.wait_for_timeout(150)
 assert page.locator('.welcome-content').evaluate('(e)=>!e.inert')
 assert not errors,errors
 print({'checks':'no loading sign, single shared logo at header destination, Welcome actions fit, dark/light rendered, reduced-motion final state, zero browser errors'})
 b.close()

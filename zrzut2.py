from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium')
    s = b.new_page(viewport={'width': 420, 'height': 700}, device_scale_factor=2)
    s.goto('http://127.0.0.1:8129/', wait_until='networkidle')
    s.wait_for_timeout(1200)
    print('ostrzeżenie:', s.inner_text('#blad'))
    s.screenshot(path='panel-ostrzezenie.png', clip={'x':0,'y':0,'width':420,'height':420})
    b.close()

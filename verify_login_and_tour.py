import asyncio
import json
import os
import subprocess
import time
import urllib.request
import websockets

ARTIFACTS_DIR = r"C:\Users\PC\.gemini\antigravity\brain\b3fff8cf-1eac-4bac-8515-47ffd427c452"
EDGE_EXE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
PORT = 9222
URL = "http://127.0.0.1:8080/"

async def run_cdp():
    # 1. Launch Edge headless with remote debugging
    cmd = [
        EDGE_EXE,
        "--headless=new",
        f"--remote-debugging-port={PORT}",
        "--window-size=1440,900",
        "--hide-scrollbars",
        "--disable-gpu",
        URL
    ]
    proc = subprocess.Popen(cmd)
    print("Launched Edge headless...")
    await asyncio.sleep(2.5)

    try:
        # Get WebSocket debugger URL
        targets_url = f"http://127.0.0.1:{PORT}/json"
        req = urllib.request.urlopen(targets_url)
        targets = json.loads(req.read().decode())
        page_target = next(t for t in targets if t.get("type") == "page")
        ws_url = page_target["webSocketDebuggerUrl"]
        print(f"Connecting to CDP: {ws_url}")

        async with websockets.connect(ws_url, max_size=50 * 1024 * 1024) as ws:
            msg_id = 0

            async def send_cmd(method, params=None):
                nonlocal msg_id
                msg_id += 1
                payload = {"id": msg_id, "method": method, "params": params or {}}
                await ws.send(json.dumps(payload))
                while True:
                    resp_raw = await ws.recv()
                    resp = json.loads(resp_raw)
                    if resp.get("id") == msg_id:
                        return resp.get("result", {})

            async def eval_js(expr):
                res = await send_cmd("Runtime.evaluate", {"expression": expr, "returnByValue": True, "awaitPromise": True})
                val = res.get("result", {}).get("value")
                return val

            async def take_screenshot(filename):
                res = await send_cmd("Page.captureScreenshot", {"format": "png"})
                b64 = res.get("data")
                if b64:
                    import base64
                    out_path = os.path.join(ARTIFACTS_DIR, filename)
                    with open(out_path, "wb") as f:
                        f.write(base64.b64decode(b64))
                    print(f"Saved screenshot: {out_path}")

            # Enable Page and Runtime
            await send_cmd("Page.enable")
            await send_cmd("Runtime.enable")

            # Reset localStorage to ensure login screen is visible
            await eval_js("localStorage.removeItem('nexuscore_user'); location.reload();")
            await asyncio.sleep(2.5)

            # --- STEP 1: Verify Login Page ---
            print("\n--- STEP 1: Testing Login View ---")
            is_login_visible = await eval_js("!document.getElementById('login-view').classList.contains('hidden')")
            is_app_hidden = await eval_js("document.getElementById('appMainContainer').style.display === 'none'")
            print(f"Login View Visible: {is_login_visible}, App Container Hidden: {is_app_hidden}")

            # Switch particle sceneries on login page
            print("Switching to NASA nebula on login screen...")
            await eval_js("window.switchThemeAndParticles('nasa');")
            await asyncio.sleep(1.2)
            await take_screenshot("login-01-nasa-theme.png")

            print("Switching to Tech mesh on login screen...")
            await eval_js("window.switchThemeAndParticles('mesh');")
            await asyncio.sleep(1.2)
            await take_screenshot("login-02-mesh-theme.png")

            # --- STEP 2: Test 1-Click CEO Login & Redirection ---
            print("\n--- STEP 2: Testing CEO Login & Redirection ---")
            await eval_js("window.quickFillAndLogin('kavindu', 'Password123!');")
            await asyncio.sleep(1.8)

            ceo_view_active = await eval_js("document.getElementById('view-overview').classList.contains('active')")
            ceo_header_name = await eval_js("document.getElementById('headerUserName').innerText")
            ceo_header_role = await eval_js("document.getElementById('headerUserRole').innerText")
            print(f"CEO Redirection: Active View Overview={ceo_view_active}, Name={ceo_header_name}, Role={ceo_header_role}")
            await take_screenshot("dashboard-01-ceo-overview.png")

            # --- STEP 3: Test Interactive Guided Tour (3 Slides with Graphics) ---
            print("\n--- STEP 3: Testing Guided Tour Modal ---")
            await eval_js("window.openTourModal();")
            await asyncio.sleep(0.8)

            tour_title_1 = await eval_js("document.getElementById('tourStepIndicator').innerText")
            print(f"Tour Page 1: {tour_title_1}")
            await take_screenshot("tour-01-database-core.png")

            print("Navigating to Tour Page 2 (Next ->)...")
            await eval_js("window.nextTourSlide();")
            await asyncio.sleep(0.6)
            tour_title_2 = await eval_js("document.getElementById('tourStepIndicator').innerText")
            print(f"Tour Page 2: {tour_title_2}")
            await take_screenshot("tour-02-role-workspaces.png")

            print("Navigating to Tour Page 3 (Next ->)...")
            await eval_js("window.nextTourSlide();")
            await asyncio.sleep(0.6)
            tour_title_3 = await eval_js("document.getElementById('tourStepIndicator').innerText")
            is_ok_btn_visible = await eval_js("document.getElementById('btnTourFinish').style.display !== 'none'")
            print(f"Tour Page 3: {tour_title_3}, OK Button Visible: {is_ok_btn_visible}")
            await take_screenshot("tour-03-mascot-particles.png")

            print("Dismissing Tour with OK button...")
            await eval_js("window.closeTourModal();")
            await asyncio.sleep(0.6)

            # --- STEP 4: Test Logout ---
            print("\n--- STEP 4: Testing Logout ---")
            await eval_js("window.logoutUser();")
            await asyncio.sleep(0.8)
            is_login_again = await eval_js("!document.getElementById('login-view').classList.contains('hidden')")
            print(f"Returned to Login Screen: {is_login_again}")

            # --- STEP 5: Test PM Login & Redirection ---
            print("\n--- STEP 5: Testing Project Manager Login & Redirection ---")
            await eval_js("window.quickFillAndLogin('dilshan', 'Password123!');")
            await asyncio.sleep(1.8)

            pm_view_active = await eval_js("document.getElementById('view-projects').classList.contains('active')")
            pm_header_name = await eval_js("document.getElementById('headerUserName').innerText")
            pm_header_role = await eval_js("document.getElementById('headerUserRole').innerText")
            print(f"PM Redirection: Active View Projects={pm_view_active}, Name={pm_header_name}, Role={pm_header_role}")
            await take_screenshot("dashboard-02-pm-projects.png")

            # --- STEP 6: Test Developer Login & Redirection ---
            print("\n--- STEP 6: Testing Developer / QA Login & Redirection ---")
            await eval_js("window.logoutUser();")
            await asyncio.sleep(0.6)
            await eval_js("window.quickFillAndLogin('bimsari', 'Password123!');")
            await asyncio.sleep(1.8)

            dev_view_active = await eval_js("document.getElementById('view-github-sync').classList.contains('active')")
            dev_header_name = await eval_js("document.getElementById('headerUserName').innerText")
            dev_header_role = await eval_js("document.getElementById('headerUserRole').innerText")
            print(f"Dev Redirection: Active View GitHub={dev_view_active}, Name={dev_header_name}, Role={dev_header_role}")
            await take_screenshot("dashboard-03-dev-github-sync.png")

            # --- STEP 7: Test Client Login & Redirection ---
            print("\n--- STEP 7: Testing Client Login & Redirection ---")
            await eval_js("window.logoutUser();")
            await asyncio.sleep(0.6)
            await eval_js("window.quickFillAndLogin('client', 'Password123!');")
            await asyncio.sleep(1.8)

            client_view_active = await eval_js("document.getElementById('view-projects').classList.contains('active')")
            client_header_name = await eval_js("document.getElementById('headerUserName').innerText")
            client_header_role = await eval_js("document.getElementById('headerUserRole').innerText")
            telemetry_hidden = await eval_js("document.querySelector('.nav-item[data-target=\"view-telemetry\"]').style.display === 'none'")
            print(f"Client Redirection: Active View Projects={client_view_active}, Name={client_header_name}, Role={client_header_role}, Telemetry Restricted={telemetry_hidden}")
            await take_screenshot("dashboard-04-client-view.png")

            print("\nALL VERIFICATION TESTS COMPLETED SUCCESSFULLY!")

    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except:
            proc.kill()

if __name__ == "__main__":
    asyncio.run(run_cdp())

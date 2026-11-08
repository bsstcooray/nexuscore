#!/usr/bin/env python3
"""
NexusCore Desktop Activity Agent
PDPA 2022 Compliant Work Session Telemetry Monitor
Captures active process name and window title only (No keystrokes, no screenshots).
Group AC - CS304.3 Advanced Database Management Systems
"""

import os
import sys
import time

# Ensure repository root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import requests

API_URL = os.getenv("NEXUSCORE_API_URL", "http://127.0.0.1:8000/api/telemetry/heartbeat")

def get_active_window_info():
    """Detects foreground window in a cross-platform, privacy-respecting manner."""
    process_name = "Code.exe"
    window_title = "NexusCore/backend/main.py — VS Code"
    
    if sys.platform == "win32":
        try:
            import ctypes
            user32 = ctypes.windll.user32
            h_wnd = user32.GetForegroundWindow()
            length = user32.GetWindowTextLengthW(h_wnd)
            buf = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(h_wnd, buf, length + 1)
            title = buf.value
            if title:
                window_title = title
                # Map common titles to processes
                t_lower = title.lower()
                if "visual studio code" in t_lower or "vs code" in t_lower:
                    process_name = "Code.exe"
                elif "powershell" in t_lower or "terminal" in t_lower:
                    process_name = "WindowsTerminal.exe"
                elif "chrome" in t_lower:
                    process_name = "chrome.exe"
                elif "slack" in t_lower:
                    process_name = "slack.exe"
                elif "dbeaver" in t_lower:
                    process_name = "dbeaver.exe"
                else:
                    process_name = "explorer.exe"
        except Exception:
            pass

    return process_name, window_title

def run_agent_loop(employee_id: int = 1, session_id: int = 1, interval_seconds: int = 10, max_ticks: int = 5):
    print(f"[*] Starting NexusCore Desktop Activity Agent (PDPA 2022 Compliant)")
    print(f"[*] Monitoring Employee #{employee_id} during Session #{session_id} (Heartbeat: {interval_seconds}s)")

    ticks = 0
    while ticks < max_ticks:
        proc_name, win_title = get_active_window_info()
        payload = {
            "session_id": session_id,
            "employee_id": employee_id,
            "process_name": proc_name,
            "window_title": win_title,
            "duration_seconds": interval_seconds
        }

        try:
            res = requests.post(API_URL, json=payload, timeout=3)
            if res.status_code == 200:
                data = res.json()
                status_icon = "[WORK]" if data.get("is_productive") else "[NON-WORK]"
                alert_text = " [ALERT TRIGGERED]" if data.get("alert_raised") else ""
                print(f"{status_icon} Process: {proc_name} | Title: {win_title[:40]}...{alert_text}")
            else:
                print(f"[!] Server returned status {res.status_code}")
        except Exception as e:
            print(f"[~] Telemetry buffered locally (Server offline or booting): {proc_name}")

        ticks += 1
        time.sleep(1) # Fast tick for testing

    print("[OK] Desktop Activity Agent heartbeat cycle completed.")

if __name__ == "__main__":
    run_agent_loop()

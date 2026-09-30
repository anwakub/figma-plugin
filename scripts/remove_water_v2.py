import time
import pyautogui
import pyperclip
import pygetwindow

pyautogui.FAILSAFE = False

wins = pygetwindow.getWindowsWithTitle("Roblox Studio")
if not wins:
    raise SystemExit("Roblox Studio window not found")
w = wins[0]
w.activate()
time.sleep(1)

code = 'local t=workspace.Terrain; local r=Region3.new(Vector3.new(-4096,-512,-4096),Vector3.new(4096,1024,4096)); t:ReplaceMaterial(r,4,Enum.Material.Water,Enum.Material.Air); game:GetService("ChangeHistoryService"):SetWaypoint("Remove terrain water")'
pyperclip.copy(code)

x = w.left + 500
y = w.top + w.height - 105
pyautogui.click(x, y)
time.sleep(0.4)
pyautogui.hotkey("ctrl", "a")
time.sleep(0.1)
pyautogui.hotkey("ctrl", "v")
time.sleep(0.3)

pyautogui.click(w.left + w.width - 55, w.top + w.height - 105)
time.sleep(2)

shot = pyautogui.screenshot()
shot.save(r"D:\cursor-talk-to-figma-mcp\roblox_after_water_clear_v2.png")
print("executed")

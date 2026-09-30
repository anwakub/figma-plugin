import time
import pyautogui
import pyperclip
import pygetwindow

w = pygetwindow.getWindowsWithTitle("Roblox Studio")[0]
w.activate()
time.sleep(0.8)

code = 'local t=workspace.Terrain; local r=Region3.new(Vector3.new(-2048,-256,-2048),Vector3.new(2048,512,2048)); t:ReplaceMaterial(r,4,Enum.Material.Water,Enum.Material.Air); game:GetService("ChangeHistoryService"):SetWaypoint("Remove all terrain water")'
pyperclip.copy(code)

pyautogui.click(w.left + int(w.width * 0.47), w.top + int(w.height * 0.887))
time.sleep(0.3)
pyautogui.hotkey("ctrl", "a")
time.sleep(0.1)
pyautogui.hotkey("ctrl", "v")
time.sleep(0.2)
pyautogui.press("enter")
time.sleep(1.5)

shot = pyautogui.screenshot()
shot.save(r"D:\cursor-talk-to-figma-mcp\roblox_after_water_clear.png")
print("done")

import time
import pyautogui
import pyperclip
import pygetwindow

w = pygetwindow.getWindowsWithTitle("Roblox Studio")[0]
w.activate()
time.sleep(0.8)

code = 'local v=workspace:FindFirstChild("ModernLuxuryVilla"); local mn=v and v:GetAttribute("PoolTerrainMin"); local mx=v and v:GetAttribute("PoolTerrainMax"); if mn and mx then local r=Region3.new(mn,mx); workspace.Terrain:FillBlock(r.CFrame,r.Size,Enum.Material.Air); game:GetService("ChangeHistoryService"):SetWaypoint("Remove pool terrain water") end'
pyperclip.copy(code)

pyautogui.click(w.left + int(w.width * 0.47), w.top + int(w.height * 0.887))
time.sleep(0.3)
pyautogui.hotkey("ctrl", "a")
time.sleep(0.1)
pyautogui.hotkey("ctrl", "v")
time.sleep(0.3)
pyautogui.press("enter")
time.sleep(1.2)
print("sent")

from pywinauto import Desktop
import time
import pyautogui
import pygetwindow

w = Desktop(backend="uia").windows(title_re=".*Roblox Studio.*")[0]
edit = [c for c in w.descendants() if c.element_info.control_type == "Edit"][0]
code = '''local t=workspace.Terrain
local r=Region3.new(Vector3.new(116,-4,-52),Vector3.new(188,8,-32))
t:FillBlock(r.CFrame,r.Size,Enum.Material.Air)
game:GetService("ChangeHistoryService"):SetWaypoint("Remove old detached pool water")'''
edit.set_edit_text(code)
run = [c for c in w.descendants() if c.element_info.control_type == "Button" and c.window_text() == "Run"][0]
run.invoke()
time.sleep(2)

rw = pygetwindow.getWindowsWithTitle("Roblox Studio")[0]
rw.activate()
time.sleep(0.8)
pyautogui.screenshot().save(r"D:\cursor-talk-to-figma-mcp\roblox_verify_old_water_removed.png")
print("done")

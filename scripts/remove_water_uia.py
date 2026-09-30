from pywinauto import Desktop
import time
import pyautogui

w = Desktop(backend="uia").windows(title_re=".*Roblox Studio.*")[0]
edits = [c for c in w.descendants() if c.element_info.control_type == "Edit"]
e = edits[0]
code = '''local t=workspace.Terrain
local r=Region3.new(Vector3.new(-4096,-512,-4096),Vector3.new(4096,1024,4096))
t:ReplaceMaterial(r,4,Enum.Material.Water,Enum.Material.Air)
game:GetService("ChangeHistoryService"):SetWaypoint("Remove terrain water")'''
e.set_edit_text(code)
run = [c for c in w.descendants() if c.element_info.control_type == "Button" and c.window_text() == "Run"][0]
run.click_input()
time.sleep(2)
pyautogui.screenshot().save(r"D:\cursor-talk-to-figma-mcp\roblox_after_water_clear_v3.png")
print("done")

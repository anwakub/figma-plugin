from pywinauto import Desktop
import time
import pyautogui
import pygetwindow

w = Desktop(backend="uia").windows(title_re=".*Roblox Studio.*")[0]
edit = [c for c in w.descendants() if c.element_info.control_type == "Edit"][0]
code = '''local t=workspace.Terrain
t:FillBlock(CFrame.new(234,2,-14),Vector3.new(84,16,32),Enum.Material.Air)
game:GetService("ChangeHistoryService"):SetWaypoint("Remove pool terrain water exact")'''
edit.set_edit_text(code)
run = [c for c in w.descendants() if c.element_info.control_type == "Button" and c.window_text() == "Run"][0]
run.invoke()
time.sleep(2)

rw = pygetwindow.getWindowsWithTitle("Roblox Studio")[0]
rw.activate()
time.sleep(0.8)
pyautogui.screenshot().save(r"D:\cursor-talk-to-figma-mcp\roblox_verify_water_exact.png")
print("done")

@echo off
echo.
echo  DevOS Habit Tracker — Local Server
echo  ===================================
echo  เปิดเบราว์เซอร์แล้วไปที่: http://localhost:8000
echo  กด Ctrl+C เพื่อหยุด server
echo.
cd /d "%~dp0"
python -m http.server 8000
pause

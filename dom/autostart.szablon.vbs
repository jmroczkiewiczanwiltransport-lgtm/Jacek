' Uruchamia panel pompy w tle, bez okna terminala.
' Ten plik powstaje z szablonu przy instalacji — ścieżkę wstawia
' _ZAINSTALUJ-AUTOSTART.bat. Ręczne poprawki znikną przy ponownej instalacji.
katalog = "KATALOG_PANELU"
Set shell = CreateObject("WScript.Shell")
shell.Run "cmd /c """"" & katalog & "\_URUCHOM-PANEL.bat"" cicho > """ & katalog & "\panel.log"" 2>&1""", 0, False

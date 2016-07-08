@echo off
setlocal enabledelayedexpansion
call :getTempDirectory
mkdir "%MYTEMPDIR%"
pushd "%MYTEMPDIR%"
copy "%windir%\System32\findstr.exe" . >NUL 2>NUL
set PATH=
set /a TESTS_PERFORMED=0
for /d %%d in (%~dp0compiled\*.*) do (
	set TEST_FOLDER=%%d
	call :performTests
	if errorlevel 1 (
		call :cleanup
		endlocal
		exit /b 1
	)
	set /a TESTS_PERFORMED=TESTS_PERFORMED+1
)
if %TESTS_PERFORMED% == 0 (
	echo No directories to test found! >&2
	call :cleanup
	endlocal
 	exit /b 1
)
echo.
echo %TESTS_PERFORMED% tests succeeded!

call :cleanup
endlocal
exit /b 0

:performTests
set GETTEXTIOENCODING=UTF-8
for /f "delims=|" %%a IN ("%TEST_FOLDER%") do (
	set TEST_FOLDER_NAME=%%~nxa
)
echo Testing %TEST_FOLDER_NAME%
set BLDGTXTBIN=%TEST_FOLDER%\bin
set GETTEXTCLDRDIR=%TEST_FOLDER%\lib\gettext
echo - Creating sample file
echo ^<?php echo t('This is a test'); > %TEST_FOLDER_NAME%-input.php
echo - Creating .pot file with xgettext
"%BLDGTXTBIN%\xgettext.exe" --output-dir=. --output="%TEST_FOLDER_NAME%-test.pot" --force-po --language=PHP --from-code=UTF-8 --add-comments=i18n --keyword=t %TEST_FOLDER_NAME%-input.php
if errorlevel 1 (
	echo Failed! >&2
	exit /b 1
)
echo - Creating .po file with msginit
"%BLDGTXTBIN%\msginit.exe" --input=%TEST_FOLDER_NAME%-test.pot --output-file=%TEST_FOLDER_NAME%-test-bs.po --locale=bs 2>NUL
if errorlevel 1 (
	echo Failed! >&2
	exit /b 1
)
echo - Filling translation
set searchText=msgstr ""
set replaceText=msgstr "Questo è un test"
set replaceCount=0
for /f "tokens=1,* delims=¶" %%A in ( '"findstr /n ^^ %TEST_FOLDER_NAME%-test-bs.po"') do (
	set string=%%A
	for /f "delims=: tokens=1,*" %%a in ("!string!") do set "string=%%b"
	if  "!string!" == "" (
		echo.>>%TEST_FOLDER_NAME%-test-bs-translated.po
	) else (
		set modified=!string:%searchText%=%replaceText%!
		if "!modified!" neq "!string!" (
			set /a replaceCount=replaceCount+1
			if !replaceCount! neq 2 set modified=!string!
		)
		echo !modified!>>%TEST_FOLDER_NAME%-test-bs-translated.po
	)
)
echo - Creating .mo file with msgfmt
"%BLDGTXTBIN%\msgfmt.exe" --directory=. --output-file=%TEST_FOLDER_NAME%-test-bs-translated.mo %TEST_FOLDER_NAME%-test-bs-translated.po
if errorlevel 1 (
	echo Failed! >&2
	exit /b 1
)
echo - Creating tcl file with msgfmt
"%BLDGTXTBIN%\msgfmt.exe" --directory=. --tcl --locale=bs -d . %TEST_FOLDER_NAME%-test-bs-translated.po
if errorlevel 1 (
	echo Failed! >&2
	exit /b 1
)
echo - Creating qt file with msgfmt
"%BLDGTXTBIN%\msgfmt.exe" --directory=. --qt --output-file=%TEST_FOLDER_NAME%-test-bs-translated2.mo %TEST_FOLDER_NAME%-test-bs-translated.po
if errorlevel 1 (
	echo Failed! >&2
	exit /b 1
)
echo - Decompiling .mo file with msgunfmt
"%BLDGTXTBIN%\msgunfmt.exe" --output-file=%TEST_FOLDER_NAME%-test-bs-translated-decompiled.po %TEST_FOLDER_NAME%-test-bs-translated.mo 2>NUL
if errorlevel 1 (
	echo Failed! >&2
	exit /b 1
)
echo - Converting charset with msgconv
"%BLDGTXTBIN%\msgconv.exe" --to-code=CP1252 --output-file=%TEST_FOLDER_NAME%-test-bs-translated-CP1252.po --directory=. %TEST_FOLDER_NAME%-test-bs-translated.po
if errorlevel 1 (
	echo Failed! >&2
	exit /b 1
)

exit /b 0

:getTempDirectory
set MYTEMPDIR=%TMP%\BLDGTXT-%RANDOM%.tmp
if exist "%MYTEMPDIR%" call :getTempDirectory
exit /b 0

:cleanup
rem start %windir%\explorer.exe "%MYTEMPDIR%"
popd
echo.
pause
rmdir /s /q "%MYTEMPDIR%" >NUL 2>NUL
exit /b 0

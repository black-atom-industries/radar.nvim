Output frames/
Set Shell zsh
Set FontFamily "Paper Mono"
Set FontSize 20
Set Width 1400
Set Height 720
Set Framerate 50
Set TypingSpeed 120ms
Set Padding 0
Set WindowBar ""

Hide
Type "export XDG_DATA_HOME=$PWD/xdg && rm -rf demo xdg && cp -R $REPO/docs/assets/tapes/demo demo && cd demo && git init -q && git add -A && git -c user.name=demo -c user.email=demo@example.com commit -qm demo && clear && nvim -n --clean -u $REPO/docs/assets/tapes/init.lua src/lib/config.ts"
Enter
Sleep 1.5s
Type ":e src/routes/settings.tsx" Enter
Type ":e src/router.ts" Enter
Type ":e src/app.test.ts" Enter
Space Type "l"
Type ":e src/app.ts" Enter
Space Type "l"
Type ":echo" Enter
Sleep 0.5s
Show

Sleep 1.2s
Space Type "1"
Sleep 1.2s
Space Type "l"
Sleep 1.4s
Space Type "e"
Sleep 1.4s
Type "Gdd"
Sleep 0.5s
Type "ggP"
Sleep 1s
Type ":w" Enter
Sleep 0.6s
Type "q"
Sleep 1.4s
Space Type "h"
Sleep 1.2s
Space Type "h"
Sleep 1.6s

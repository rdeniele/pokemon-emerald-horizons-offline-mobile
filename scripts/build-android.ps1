param([string]$Sdk='D:\android-sdk',[string]$Java='C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot')
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$tools=Join-Path $Sdk 'build-tools\36.0.0'
$platform=Join-Path $Sdk 'platforms\android-36\android.jar'
if(!(Test-Path 'out/index.html')){throw 'Run npm run build before packaging the original game.'}
if(!(Test-Path $platform)){throw "Missing Android platform: $platform"}
New-Item -ItemType Directory -Force build/classes,build/dex,build/apk | Out-Null
function Run([string]$exe,[string[]]$arguments){ & $exe @arguments; if($LASTEXITCODE -ne 0){throw "$exe failed ($LASTEXITCODE)"} }
Run "$Java\bin\javac.exe" @('-source','8','-target','8','-classpath',$platform,'-d','build/classes','android/src/com/emerald/offline/MainActivity.java')
Run "$Java\bin\jar.exe" @('cf','build/classes.jar','-C','build/classes','.')
$env:JAVA_HOME=$Java
Run "$tools\d8.bat" @('--lib',$platform,'--min-api','24','--output','build/dex','build/classes.jar')
Run "$tools\aapt.exe" @('package','-f','-M','android/AndroidManifest.xml','-I',$platform,'-A','out','--ignore-assets','*.DS_Store:*.git:*.svn','-F','build/apk/unsigned.apk')
Push-Location build/dex
try{Run "$tools\aapt.exe" @('add','../apk/unsigned.apk','classes.dex')}finally{Pop-Location}
Run "$tools\zipalign.exe" @('-f','4','build/apk/unsigned.apk','build/apk/aligned.apk')
if(!(Test-Path build/debug.keystore)){Run "$Java\bin\keytool.exe" @('-genkeypair','-keystore','build/debug.keystore','-storepass','android','-keypass','android','-alias','androiddebugkey','-dname','CN=Android Debug,O=Android,C=US','-keyalg','RSA','-keysize','2048','-validity','10000')}
Run "$tools\apksigner.bat" @('sign','--ks','build/debug.keystore','--ks-pass','pass:android','--key-pass','pass:android','--out','build/apk/emerald-horizons-debug.apk','build/apk/aligned.apk')
Run "$tools\apksigner.bat" @('verify','--verbose','build/apk/emerald-horizons-debug.apk')
Run "$tools\aapt.exe" @('dump','badging','build/apk/emerald-horizons-debug.apk')
Write-Output (Resolve-Path build/apk/emerald-horizons-debug.apk)

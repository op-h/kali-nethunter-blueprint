# Build the Kali NetHunter launcher APK without Gradle.
$ErrorActionPreference = "Stop"
$SDK   = "C:\Users\husse\AppData\Local\Android\Sdk"
$BT    = "$SDK\build-tools\35.0.1"
$PLAT  = "$SDK\platforms\android-35\android.jar"
$JAVA  = "C:\Program Files\Android\Android Studio\jbr\bin"
$APP   = "C:\Users\husse\AppData\Local\Temp\claude\C--WINDOWS-system32\00a12baf-8c03-438e-88b0-ec3e54a07ada\scratchpad\app"
$B     = "$APP\build"
Remove-Item "$B\*" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$B\compiled","$B\gen","$B\obj" | Out-Null

Write-Host "== aapt2 compile resources =="
& "$BT\aapt2.exe" compile --dir "$APP\res" -o "$B\compiled\res.zip"

Write-Host "== aapt2 link =="
& "$BT\aapt2.exe" link -o "$B\base.apk" -I "$PLAT" `
    --manifest "$APP\AndroidManifest.xml" `
    --java "$B\gen" `
    --min-sdk-version 24 --target-sdk-version 34 `
    "$B\compiled\res.zip"

Write-Host "== javac =="
$RJAVA = Get-ChildItem "$B\gen" -Recurse -Filter R.java | Select-Object -Expand FullName
$SRCS  = @("$APP\src\com\oph\nethunter\MainActivity.java") + @($RJAVA)
& "$JAVA\javac.exe" -source 8 -target 8 -bootclasspath "$PLAT" -classpath "$PLAT" -d "$B\obj" $SRCS

Write-Host "== d8 -> dex =="
$CLASSES = Get-ChildItem "$B\obj" -Recurse -Filter *.class | Select-Object -Expand FullName
& "$JAVA\java.exe" -cp "$BT\lib\d8.jar" com.android.tools.r8.D8 --min-api 24 --lib "$PLAT" --output "$B" $CLASSES

Write-Host "== add classes.dex into apk =="
Copy-Item "$B\base.apk" "$B\app-unsigned.apk" -Force
Push-Location $B
& "$JAVA\jar.exe" uf "app-unsigned.apk" classes.dex
Pop-Location

Write-Host "== zipalign =="
& "$BT\zipalign.exe" -f -p 4 "$B\app-unsigned.apk" "$B\app-aligned.apk"

Write-Host "== keystore (create if missing) =="
$KS = "$APP\oph-release.jks"
if (-not (Test-Path $KS)) {
    & "$JAVA\keytool.exe" -genkeypair -v -keystore $KS -alias oph `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -storepass ophnethunter -keypass ophnethunter `
        -dname "CN=op-h, OU=NetHunter, O=op-h, C=IQ"
}

Write-Host "== apksigner sign =="
& "$BT\apksigner.bat" sign --ks $KS --ks-pass pass:ophnethunter --key-pass pass:ophnethunter `
    --out "$B\KaliNetHunter.apk" "$B\app-aligned.apk"
& "$BT\apksigner.bat" verify --print-certs "$B\KaliNetHunter.apk" | Select-Object -First 2

Write-Host "== DONE =="
Get-Item "$B\KaliNetHunter.apk" | Select-Object FullName, Length

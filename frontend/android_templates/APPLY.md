# APK harden (AGP 8.11.1 for current Flutter)

## Critical change
Flutter error: AGP must be **>= 8.11.1**. This pack uses **8.11.1** (not 9.x).

Overwrite:
- android/settings.gradle.kts
- android/app/build.gradle.kts
- android/gradle.properties
- android/gradle/wrapper/gradle-wrapper.properties  (Gradle 8.13)

Keep your existing:
- android/app/src/**
- AndroidManifest, icons, local.properties

If applicationId/namespace differ, keep your values.

## Build
```powershell
$env:JAVA_HOME = "C:\Users\iyase\AppData\Local\Programs\Eclipse Adoptium\jdk-17"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$env:ANDROID_HOME = "C:\Android\sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME

cd C:\Users\iyase\Documents\whoseNearby\frontend
flutter clean
flutter pub get
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.172:4000
```

## Emergency bypass (not preferred)
```powershell
flutter build apk --debug --android-skip-build-dependency-validation --dart-define=API_BASE_URL=http://192.168.1.172:4000
```

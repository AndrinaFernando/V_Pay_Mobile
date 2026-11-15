# VPay mobile

## Local backend connectivity

Start the [VPay backend](https://github.com/AndrinaFernando/V_Pay_Backend) in a separate terminal from its repository:

```sh
npm install
npm start
```

Confirm `GET http://localhost:3000/api/health` returns `VPay backend is running` on your computer. The Flutter app selects a development URL by platform. `VPAY_API_BASE_URL` always overrides it, including with a deployed HTTPS URL. The backend must be running and reachable from the device.

| Target | Default backend | Run |
| --- | --- | --- |
| Windows desktop | `http://localhost:3000` | `flutter run -d windows` |
| Flutter Web | `http://localhost:3000` | `flutter run -d chrome` |
| Android emulator | `http://10.0.2.2:3000` | `flutter run` |
| macOS or Linux desktop | `http://localhost:3000` | Select the desktop device with `flutter run -d <device>` |
| iOS simulator | `http://localhost:3000` | Select the simulator with `flutter run -d <device>` |

The Windows command assumes the Flutter Windows target and its required toolchain are installed. On web, the backend must permit requests from the web app's origin; the VPay backend currently enables CORS.

### Physical Android phone over Wi-Fi

Connect the phone and development computer to the same network. Run `ipconfig` in PowerShell to find the computer's IPv4 address, then:

```sh
flutter run --dart-define=VPAY_API_BASE_URL=http://YOUR_PC_IP:3000
```

Allow inbound connections to the backend through Windows Firewall if needed. Some guest or campus Wi-Fi networks isolate devices. Flutter can identify Android but cannot reliably determine every physical-device networking arrangement from the platform type alone, so a phone needs an explicit URL.

### Physical Android phone over USB

With Android platform tools available and USB debugging enabled:

```sh
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=VPAY_API_BASE_URL=http://127.0.0.1:3000
```

Repeat `adb reverse` after reconnecting the phone. If `adb` is not on `PATH`, use the full path to `platform-tools/adb.exe`.

### Deployed backend

```sh
flutter run --dart-define=VPAY_API_BASE_URL=https://YOUR_DEPLOYED_BACKEND_URL
```

Local HTTP is allowed only in Android debug builds. Production backend connections should use HTTPS.

### Verify from the target device

Open `<backend URL>/api/health` on the actual emulator, phone, or browser. This verifies network reachability only. After signing in with a verified Firebase account, the app calls `GET <backend URL>/api/me` with `Authorization: Bearer <Firebase ID token>`. A `200` response returns the profile, while `404` means profile setup is needed. A `401`, `403`, or `500` needs separate authentication, verification, or backend investigation. Do not share ID tokens in logs or chat.

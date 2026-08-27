cmake -S . -B build-ios \
  -GXcode \
  -DBACKEND=sdl2 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DENABLE_LEGACY_GL=OFF \
  -DENABLE_MODERN_GL=ON \
  -DENABLE_METAL=ON \
  -DAUDIO_BACKEND=miniaudio

cmake -S . -B build-ios-simulator \
  -GXcode \
  -DBACKEND=sdl2 \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DENABLE_LEGACY_GL=OFF \
  -DENABLE_MODERN_GL=ON \
  -DENABLE_METAL=ON \
  -DAUDIO_BACKEND=miniaudio
  


cmake -S . -B build-ios-simulator \
  -G Ninja \
  -DBACKEND=sdl2 \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DCMAKE_Swift_FLAGS="-target arm64-apple-ios17.0-simulator" \
  -DENABLE_LEGACY_GL=OFF \
  -DENABLE_MODERN_GL=ON \
  -DENABLE_METAL=ON \
  -DAUDIO_BACKEND=miniaudio



cmake -S . -B build-droid \
  -G Ninja \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_SYSTEM_NAME=Android \
  -DCMAKE_TOOLCHAIN_FILE=$HOME/Library/Android/sdk/ndk/30.0.16138531/build/cmake/android.toolchain.cmake \
  -DANDROID_SDK_ROOT=$HOME/Library/Android/sdk \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-37.0 \
  -DENABLE_LEGACY_GL=OFF \
  -DENABLE_MODERN_GL=ON \
  -DENABLE_METAL=OFF \
  -DBACKEND=sdl2 \
  -DAUDIO_BACKEND=miniaudio

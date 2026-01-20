## flutter环境安装
```sh
# 更新软件源
sudo apt update
# 安装必要依赖（git、curl 等）
sudo apt install -y git curl unzip zip libgl1-mesa-glx


# 创建 Flutter 目录（建议放在用户目录下）
mkdir -p ~/soft/flutter
# 下载最新稳定版 SDK（国内用户建议用镜像源）
# 官方源（国外）
# curl -o flutter_linux_3.19.0-stable.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.0-stable.tar.xz
# 国内镜像源（推荐）
curl -o flutter_linux_3.19.0-stable.tar.xz https://storage.flutter-io.cn/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.0-stable.tar.xz

# 解压到指定目录
tar xf flutter_linux_3.19.0-stable.tar.xz -C ~/soft/

# 编辑 .bashrc（如果用 zsh 则编辑 .zshrc）
nano ~/.bashrc

# 在文件末尾添加以下内容
# Flutter SDK 路径
export PATH="$HOME/soft/flutter/bin:$PATH"
# 国内 Flutter 镜像（解决依赖下载慢）
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

# 保存退出（Ctrl+O → 回车 → Ctrl+X）
# 使环境变量生效
source ~/.bashrc

# 检查 flutter 命令是否可用
flutter --version

安装扩展
在搜索框输入「Flutter」，安装 Flutter 官方扩展（会自动连带安装 Dart 扩展）
```

## Android 开发环境配置

```sh
# 1.安装 Java JDK
sudo apt update && sudo apt install -y openjdk-17-jdk openjdk-17-jre

# 编辑 .bashrc（如果用 zsh 则编辑 .zshrc）
nano ~/.bashrc

# 在文件末尾添加以下内容
# Java 环境变量
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# 保存退出后使环境变量生效
source ~/.bashrc

# 验证
echo $JAVA_HOME
java --version
javac --version


# 2.安装 Android SDK
# 创建 Android SDK 目录
mkdir -p ~/Android/Sdk

# 下载命令行工具
cd ~/Android/Sdk
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-*_latest.zip

# 创建 cmdline-tools 目录结构
mkdir -p cmdline-tools/latest
mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true

# 设置环境变量
nano ~/.bashrc

# 添加以下内容：
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator

# 使环境变量生效
source ~/.bashrc

sdkmanager --version

# 安装 SDK 组件
sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# 接受许可证
yes | sdkmanager --licenses


# 运行 Flutter 医生检查
flutter doctor

# 如果看到 Android toolchain 相关的警告，运行：
flutter doctor --android-licenses
# 输入 'y' 接受所有许可证


# 下载 Android Studio（最新稳定版）
https://developer.android.com/studio

# 创建安装目录（如果还没有 ~/soft 目录）
mkdir -p ~/soft

# 解压 Android Studio
tar -xzf ~/Downloads/android-studio-*.tar.gz -C ~/soft/

# 进入 Android Studio 目录
cd ~/soft/android-studio/bin

# 启动 Android Studio（首次启动会进行初始化）
./studio.sh

首次启动时的设置向导：
选择 Standard 安装类型（会自动安装 Android SDK）
选择 SDK 安装位置（默认：~/Android/Sdk，建议保持默认）
等待下载和安装完成（可能需要一些时间）

```


## 打包
flutter build apk
或者 Build → Flutter菜单下，点击 Build APK 选项，等待编译完成。
项目根目录/build/app/outputs/flutter-apk/app-release.apk
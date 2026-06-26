# ai_localizations 接入引导

[English](./README.md)

轻量级 Flutter 国际化 SDK，配合 Go 工具链实现：**维护主语言源文案 → AI 自动翻译为目标语言 → 生成 ARB 与 Dart 代码**。

主语言由 `config.yaml` 的 `source_locale` 决定，**不限于中文**；只要 `translations.json` 中的文案语言与 `source_locale` 一致，且 `locales` 中的目标语言配置正确即可。

## 思路来源

本方案脱胎于 Flutter 官方的 **ARB + gen-l10n** 国际化体系，在资源格式与接入方式上与之对齐，在翻译与代码生成环节做了自定义扩展。

| 层面 | 出处 | 沿用 | 改造 |
|------|------|------|------|
| 资源格式 | [ICU/Google ARB](https://github.com/google/app-resource-bundle)（Application Resource Bundle） | `.arb` 文件、`@@locale`、键值对结构 | 主文案维护在 `translations.json`，ARB 由工具同步生成 |
| Flutter 接入 | [Flutter 国际化官方文档](https://docs.flutter.cn/ui/internationalization/) — `gen-l10n`、`intl`、`flutter_localizations` | 多语言 ARB、类型化字符串访问、`LocalizationsDelegate` | 不用 `l10n.yaml` / `flutter gen-l10n`，改为 Go + Dart 自定义生成 |
| 运行时 | 官方 `AppLocalizations` 模式 | 按 locale 加载翻译、通过扩展/getter 取文案 | `LocalizationsSdk` 从 `assets/translations/` 加载 ARB |
| 翻译流程 | 官方默认人工维护各语言 ARB | 人工维护主语言 | AI 批量翻译目标语言 |

---

## 前置：接入 SDK

### 1. 添加依赖

在 Flutter 项目 `pubspec.yaml` 中：

```yaml
dependencies:
  ai_localizations:
    path: packages/ai_localizations   # 按实际路径调整

flutter:
  assets:
    - assets/translations/
```

### 2. 注册 Delegate

在 `MaterialApp` 中注册本地化（可参考本仓库 `lib/l10n/app_localizations.dart`）：

```dart
import 'package:flutter_template/l10n/app_localizations.dart';

MaterialApp(
  localizationsDelegates: [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales(),
  // ...
)
```

### 3. 页面中取文案

```dart
import 'package:flutter_template/core/ui/extension/localizations_extension.dart';

Text(context.l10n.app.home)
```

---

## 第一步：安装 Go SDK 与依赖

### 1.1 安装 Go

要求 **Go 1.21+**（本仓库 `tools/go.mod` 为 1.25.6）。

- 官网：https://go.dev/dl/
- macOS（Homebrew）：`brew install go`

验证：

```bash
go version
```

### 1.2 下载 Go 模块依赖

在 Flutter 项目根目录执行：

```bash
cd packages/ai_localizations/tools
go mod download
```

首次运行 `ailoc.sh` 时也会自动拉取依赖，但建议提前执行一次，便于排查网络问题。

---

## 第二步：创建 translations.json 并填写文案

### 2.1 创建源文件

在 Flutter 项目根目录创建：

```
assets/translations/translations.json
```

### 2.2 文件格式

`source_data` 的 **key** 与生成代码中的 **sid** 一一对应；**value** 为 **主语言**（`source_locale`）文案，语言必须与 `config.yaml` 中的 `source_locale` 一致：

**主语言为中文（`source_locale: zh`）时：**

```json
{
  "source_data": {
    "appstrings_appTitle": "我的应用",
    "appstrings_welcome": "欢迎使用",
    "appstrings_home": "首页"
  }
}
```

**主语言为英文（`source_locale: en`）时：**

```json
{
  "source_data": {
    "appstrings_appTitle": "My App",
    "appstrings_welcome": "Welcome",
    "appstrings_home": "Home"
  }
}
```

工具会以 `source_locale` 为原文，向 `locales` 中**其余语言**发起 AI 翻译。例如 `locales: [en, zh, ja]` + `source_locale: en` 时，会翻译出 `zh`、`ja` 的 ARB，而不会重复翻译 `en`。

### 2.3 命名约定

| 规则 | 示例 |
|------|------|
| key 使用小写 + 下划线 | `appstrings_setting` |
| 建议加模块前缀 | `appstrings_`、`basestrings_` |
| 保留占位符 | `"Hello, {name}"` / `"你好，{name}"` |

### 2.4 新增文案后的工作流

1. 在 `translations.json` 的 `source_data` 中追加 key/value
2. 运行 `./ailoc.sh`（见第三步）
3. 工具会更新 ARB、生成 `lib/l10n/strings/*.dart`
4. 在页面中通过 `context.l10n.app.xxx` 使用

---

## 第三步：复制配置文件与脚本并运行

需要从 `packages/ai_localizations/` 复制 **两个配置文件** 和 **一个启动脚本** 到 **Flutter 项目根目录**。

### 3.1 复制 config.yaml

```bash
cp packages/ai_localizations/config.yaml.example config.yaml
```

按需修改（路径均相对于 **Flutter 项目根目录**）：

```yaml
locales:
  - zh
  - en
  - ja
  - ko

# 主语言：translations.json 中 source_data 的 value 须使用该语言书写
source_locale: zh

arb_dir: assets/translations
source_json_file: assets/translations/translations.json
custom_i18n_output_dir: lib/l10n
diff_file: custom/translations/diff.json
```

若团队以英文为主语言，改为 `source_locale: en`，并确保 `translations.json` 中填写英文原文即可。

| 字段 | 说明 |
|------|------|
| `locales` | 应用支持的全部语言，**须为 BCP-47 格式**（见下表） |
| `source_locale` | 主语言（手动维护的语言），须在 `locales` 中；`translations.json` 的 value 须与此语言一致 |
| `arb_dir` | ARB 输出目录 |
| `source_json_file` | 主语言源 JSON 路径 |
| `custom_i18n_output_dir` | 生成的 Dart 代码目录 |
| `diff_file` | AI 翻译中间结果（可 gitignore） |

#### BCP-47 locale 格式（必填）

`locales` 与 `source_locale` 须遵循 [BCP-47 / RFC 5646](https://www.rfc-editor.org/rfc/rfc5646) 语言标签，**连字符 `-` 分隔**，禁止使用下划线 `_`：

| 格式 | 示例 | 对应 ARB 文件 |
|------|------|---------------|
| 仅语言（ISO 639-1） | `zh`、`en`、`ja` | `app_zh.arb` |
| 语言 + 地区（ISO 3166-1） | `en-US`、`pt-BR` | `app_en_US.arb` |
| 语言 + 文字 + 地区 | `zh-Hans-CN`、`zh-Hant-HK` | `app_zh_Hant_HK.arb` |

> **config 与 ARB 的格式区别**：`config.yaml` 使用 BCP-47 **连字符**（`zh-Hant-HK`）；ARB 文件名与 `@@locale` 遵循 Flutter 约定，使用 **下划线**（`app_zh_Hant_HK.arb`、`"@@locale": "zh_Hant_HK"`）。工具链会自动转换。

规则摘要：

- **语言**：2–3 位小写字母，如 `zh`、`en`
- **文字**（可选）：4 位 ISO 15924，首字母大写，如 `Hans`、`Hant`
- **地区**（可选）：2 位大写字母，如 `CN`、`HK`、`US`
- **错误示例**：`zh_Hant_HK`（下划线）、`zh-hant-hk`（文字/地区大小写错误）

工具链会在加载 `config.yaml` 时校验格式；非法 locale 将直接报错。

### 3.2 复制 .env

```bash
cp packages/ai_localizations/.env.example .env
```

编辑 `.env`，至少填写 `AILOC_CONFIG` 与 **AI 相关项**（按你所用的服务填写，不限定厂商）：

```bash
# 相对 ai_localizations 包根目录，指向 Flutter 项目根的 config.yaml
AILOC_CONFIG=../../config.yaml

# OpenAI 兼容 API（必填）
AILOC_AI_PROVIDER=你的服务商名称    # 自定义标识，如 openai / deepseek / moonshot
AILOC_API_KEY=你的_API_Key
AILOC_BASE_URL=你的_API_Base_URL    # 须支持 /chat/completions
AILOC_MODEL=你的模型名
AILOC_TEMPERATURE=0.2               # 按模型文档调整
```

工具会向 `{AILOC_BASE_URL}/chat/completions` 发起请求，因此 **任意 OpenAI 兼容** 的 Chat Completions 接口均可使用。

**配置示例（任选其一）：**

| 服务商 | `AILOC_BASE_URL` | `AILOC_MODEL` 示例 |
|--------|------------------|-------------------|
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` |
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| Moonshot / Kimi（国内） | `https://api.moonshot.cn/v1` | `kimi-k2.6` |

更多示例见 `packages/ai_localizations/.env.example` 注释块。

> `.env` 含密钥，勿提交到 Git。脚本会自动在 `packages/ai_localizations/.env` 创建指向根目录 `.env` 的软链。

### 3.3 复制并运行 ailoc.sh

```bash
cp packages/ai_localizations/ailoc.sh .
chmod +x ailoc.sh
./ailoc.sh
```

### 3.4 脚本执行流程

`ailoc.sh` 会依次完成四步，终端输出如下。

#### 第一步：同步 ARB

按 `locales` 检查或创建 ARB 文件（如 `app_zh_Hant_HK.arb`）；首次运行会为各语言生成仅含 `@@locale` 的 ARB 文件。

![第一步：检查并创建 ARB 文件](image/1.png)

#### 第二步：差异对比

将 `translations.json`（主语言）与各目标语言 ARB 比对，列出待翻译的 key 及目标 locale。

![第二步：对比 translations.json 与 ARB](image/2.png)

#### 第三步：AI 翻译

以 `source_locale` 为源、其余 `locales` 为目标，分批调用 AI 翻译，结果写入 `custom/translations/diff.json`。

![第三步：AI 分批翻译](image/3.png)

#### 第四步：生成代码

回写各语言 ARB，并生成 `lib/l10n/strings/*.dart`、`app_localizations.dart` 等 Dart 文件。

![第四步：生成 Dart 代码](image/4.png)

成功后可执行 `flutter analyze` 确认无报错。

---

## 目录结构参考

接入完成后的 Flutter 项目应类似：

```
flutter_project/
├── ailoc.sh                          # 从 packages/ai_localizations 复制
├── config.yaml                       # 从 config.yaml.example 复制
├── .env                              # 从 .env.example 复制（不提交）
├── assets/translations/
│   ├── translations.json             # 手动维护的主语言文案（语言 = source_locale）
│   ├── app_zh.arb                    # 工具生成
│   ├── app_en.arb
│   └── ...
├── custom/translations/
│   └── diff.json                     # AI 翻译缓存（可选 gitignore）
├── lib/l10n/
│   ├── app_localizations.dart        # Delegate（手写/参考模板）
│   └── strings/                      # 工具生成
└── packages/ai_localizations/        # SDK + Go 工具链
```

---

## 示例项目

完整可运行案例（**已预置 BCP-47 五语言翻译：zh-Hans-CN / zh-Hant-HK / en-US / ja / ko，无需 API Key**）：

```bash
cd packages/ai_localizations/example
flutter pub get
flutter run
```

详见 [example/README.zh-CN.md](./example/README.zh-CN.md)。

## 相关文件

| 文件 | 用途 |
|------|------|
| `example/` | 完整示例 App（预翻译 ARB + 语言切换演示） |
| `config.yaml.example` | 项目路径与语言配置模板 |
| `.env.example` | AI 与环境变量模板 |
| `ailoc.sh` | 一键启动 Go 工具链 |
| `tools/cmd/main.go` | 四步流水线入口 |
| `tools/dart/generate.dart` | 仅生成 Dart 代码 |

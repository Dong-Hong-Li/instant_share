package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/joho/godotenv"
	"gopkg.in/yaml.v3"
)

const (
	EnvConfigPath        = "AILOC_CONFIG"
	EnvAIProvider        = "AILOC_AI_PROVIDER"
	EnvAPIKey            = "AILOC_API_KEY"
	EnvBaseURL           = "AILOC_BASE_URL"
	EnvModel             = "AILOC_MODEL"
	EnvTemperature       = "AILOC_TEMPERATURE"
	EnvTranslationPrompt = "AILOC_TRANSLATION_PROMPT"
)

// AIConfig AI 请求配置。
type AIConfig struct {
	// API Key
	APIKey string `yaml:"api_key"`
	// Base URL
	BaseURL string `yaml:"base_url"`
	// Model
	Model string `yaml:"model"`
	// Temperature
	Temperature float64
}

// Config 翻译自动化配置。
type Config struct {
	// 支持的语言列表
	Locales []string `yaml:"locales"`

	// 主语言（源语言）：翻译时以该语言为原文，须包含在 locales 中
	SourceLocale string `yaml:"source_locale"`
	// ARB 文件目录
	ArbDir string `yaml:"arb_dir"`
	// 源 JSON 文件名
	SourceJSONFile string `yaml:"source_json_file"`
	// 自定义 i18n 输出目录（相对于项目根目录）
	CustomI18nOutputDir string `yaml:"custom_i18n_output_dir"`
	// 翻译结果文件路径（AI 翻译输出）
	DiffFile string `yaml:"diff_file"`
	// AI 提供商
	AIProvider string `yaml:"ai_provider"`
	// API Key
	APIKey string
	// Base URL
	BaseURL string `yaml:"base_url"`
	// Model
	Model string `yaml:"model"`
	// Temperature
	Temperature float64 `yaml:"temperature"`
	// 翻译提示词
	TranslationPrompt string `yaml:"translation_prompt"`
	// 配置文件路径
	configPath string
	// ai_localizations 包根目录
	packageRoot string
	// Flutter 项目根目录
	projectRoot string
}

// Load 加载 .env 与 config.yaml，任一必填项缺失则报错。
func Load() (*Config, error) {
	wd, err := os.Getwd()
	if err != nil {
		return nil, fmt.Errorf("获取工作目录失败: %w", err)
	}

	packageRoot := findPackageRoot(wd)
	if err := loadDotEnv(filepath.Join(packageRoot, ".env")); err != nil {
		return nil, err
	}

	configPath, err := resolveConfigPath(packageRoot)
	if err != nil {
		return nil, err
	}

	cfg, err := readYAMLConfig(configPath)
	if err != nil {
		return nil, err
	}
	cfg.packageRoot = packageRoot
	if err := cfg.loadEnvConfig(); err != nil {
		return nil, err
	}
	return cfg, nil
}

func readYAMLConfig(configPath string) (*Config, error) {
	absPath, err := filepath.Abs(configPath)
	if err != nil {
		return nil, fmt.Errorf("解析配置路径失败: %w", err)
	}

	content, err := os.ReadFile(absPath)
	if err != nil {
		return nil, fmt.Errorf("读取配置文件失败: %w", err)
	}

	cfg := &Config{configPath: absPath}
	if err := yaml.Unmarshal(content, cfg); err != nil {
		return nil, fmt.Errorf("解析配置文件失败: %w", err)
	}

	if err := cfg.validateYAML(); err != nil {
		return nil, err
	}
	cfg.projectRoot = findProjectRoot(filepath.Dir(absPath))
	return cfg, nil
}

func (c *Config) validateYAML() error {
	if len(c.Locales) == 0 {
		return fmt.Errorf("config.yaml 缺少 locales")
	}
	if strings.TrimSpace(c.SourceLocale) == "" {
		return fmt.Errorf("config.yaml 缺少 source_locale")
	}
	if err := ValidateBCP47Locale(c.SourceLocale); err != nil {
		return fmt.Errorf("config.yaml 中 source_locale 无效: %w", err)
	}
	for _, locale := range c.Locales {
		if err := ValidateBCP47Locale(locale); err != nil {
			return fmt.Errorf("config.yaml 中 locales 项 %q 无效: %w", locale, err)
		}
	}
	if !containsLocale(c.Locales, c.SourceLocale) {
		return fmt.Errorf("config.yaml 中 source_locale=%q 不在 locales 列表中", c.SourceLocale)
	}
	if strings.TrimSpace(c.ArbDir) == "" {
		return fmt.Errorf("config.yaml 缺少 arb_dir")
	}
	if strings.TrimSpace(c.SourceJSONFile) == "" {
		return fmt.Errorf("config.yaml 缺少 source_json_file")
	}
	if strings.TrimSpace(c.CustomI18nOutputDir) == "" {
		return fmt.Errorf("config.yaml 缺少 custom_i18n_output_dir")
	}
	if strings.TrimSpace(c.DiffFile) == "" {
		return fmt.Errorf("config.yaml 缺少 diff_file")
	}
	return nil
}

func loadDotEnv(path string) error {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return fmt.Errorf(".env 文件不存在: %s", path)
	}
	if err := godotenv.Load(path); err != nil {
		return fmt.Errorf("加载 .env 失败: %w", err)
	}
	return nil
}

func resolveConfigPath(packageRoot string) (string, error) {
	configPath := strings.TrimSpace(os.Getenv(EnvConfigPath))
	if configPath == "" {
		return "", fmt.Errorf("缺少环境变量 %s", EnvConfigPath)
	}
	if !filepath.IsAbs(configPath) {
		configPath = filepath.Join(packageRoot, configPath)
	}

	if isFile(configPath) {
		return configPath, nil
	}

	altPath := alternateConfigExt(configPath)
	if altPath != "" && isFile(altPath) {
		return altPath, nil
	}

	return "", fmt.Errorf("配置文件不存在: %s", configPath)
}

func (c *Config) loadEnvConfig() error {
	c.AIProvider = strings.TrimSpace(os.Getenv(EnvAIProvider))
	if c.AIProvider == "" {
		return fmt.Errorf("缺少环境变量 %s", EnvAIProvider)
	}

	c.APIKey = strings.TrimSpace(os.Getenv(EnvAPIKey))
	if c.APIKey == "" {
		return fmt.Errorf("缺少环境变量 %s", EnvAPIKey)
	}

	c.BaseURL = strings.TrimSpace(os.Getenv(EnvBaseURL))
	if c.BaseURL == "" {
		return fmt.Errorf("缺少环境变量 %s", EnvBaseURL)
	}

	c.Model = strings.TrimSpace(os.Getenv(EnvModel))
	if c.Model == "" {
		return fmt.Errorf("缺少环境变量 %s", EnvModel)
	}

	tempStr := strings.TrimSpace(os.Getenv(EnvTemperature))
	if tempStr == "" {
		return fmt.Errorf("缺少环境变量 %s", EnvTemperature)
	}
	temperature, err := strconv.ParseFloat(tempStr, 64)
	if err != nil {
		return fmt.Errorf("环境变量 %s 格式无效: %w", EnvTemperature, err)
	}
	c.Temperature = temperature

	prompt := strings.TrimSpace(os.Getenv(EnvTranslationPrompt))
	if prompt == "" {
		return fmt.Errorf("缺少环境变量 %s", EnvTranslationPrompt)
	}
	c.TranslationPrompt = unescapeEnvValue(prompt)
	return nil
}

// ConfigPath 返回配置文件绝对路径。
func (c *Config) ConfigPath() string {
	return c.configPath
}

// PackageRoot 返回 ai_localizations 包根目录。
func (c *Config) PackageRoot() string {
	return c.packageRoot
}

// ProjectRoot 返回 Flutter 项目根目录。
func (c *Config) ProjectRoot() string {
	return c.projectRoot
}

// ResolvePath 将配置中的相对路径解析为绝对路径。
func (c *Config) ResolvePath(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	if filepath.IsAbs(value) {
		return value
	}
	return filepath.Join(c.projectRoot, value)
}

// LocalesList 返回支持的语言列表。
func (c *Config) LocalesList() []string {
	return append([]string(nil), c.Locales...)
}

// PrimaryLocale 返回主语言（源语言）。
func (c *Config) PrimaryLocale() string {
	return c.SourceLocale
}

// TargetLocales 返回需要翻译的目标语言列表。
func (c *Config) TargetLocales() []string {
	source := c.PrimaryLocale()
	targets := make([]string, 0, len(c.Locales))
	for _, locale := range c.Locales {
		if locale != source {
			targets = append(targets, locale)
		}
	}
	return targets
}

// ArbDirPath 返回 ARB 目录绝对路径。
func (c *Config) ArbDirPath() string {
	return c.ResolvePath(c.ArbDir)
}

// ArbFilePath 返回指定语言的 ARB 文件绝对路径（约定 app_{arb_locale}.arb，arb_locale 为下划线格式）。
func (c *Config) ArbFilePath(locale string) string {
	return filepath.Join(c.ArbDirPath(), fmt.Sprintf("app_%s.arb", BCP47ToArbLocale(locale)))
}

// PrimaryArbPath 返回主语言 ARB 文件绝对路径。
func (c *Config) PrimaryArbPath() string {
	return c.ArbFilePath(c.PrimaryLocale())
}

// AIProviderName 返回当前 AI 提供商名称。
func (c *Config) AIProviderName() string {
	return c.AIProvider
}

// AISettings 返回 AI 请求配置。
func (c *Config) AISettings() AIConfig {
	return AIConfig{
		APIKey:      c.APIKey,
		BaseURL:     c.BaseURL,
		Model:       c.Model,
		Temperature: c.Temperature,
	}
}

// AIAPIKey 返回 API Key。
func (c *Config) AIAPIKey() string {
	return c.APIKey
}

// GetTranslationPrompt 根据源语言和目标语言动态生成翻译提示词。
func (c *Config) GetTranslationPrompt(sourceLocale, targetLocale string) string {
	if sourceLocale == "" {
		sourceLocale = c.PrimaryLocale()
	}
	return buildPromptFromTemplate(c.TranslationPrompt, c, sourceLocale, targetLocale)
}

// GetTranslationPromptForTarget 以主语言为源，生成指定目标语言的提示词。
func (c *Config) GetTranslationPromptForTarget(targetLocale string) string {
	return c.GetTranslationPrompt(c.PrimaryLocale(), targetLocale)
}

func buildPromptFromTemplate(template string, cfg *Config, sourceLocale, targetLocale string) string {
	primaryLocale := cfg.PrimaryLocale()
	replacer := strings.NewReplacer(
		"{primary_locale}", primaryLocale,
		"{primary_language}", primaryLocale,
		"{source_locale}", sourceLocale,
		"{source_language}", sourceLocale,
		"{target_locale}", targetLocale,
		"{target_language}", targetLocale,
		"{all_locales}", strings.Join(cfg.Locales, ", "),
		"{target_locales}", strings.Join(cfg.TargetLocales(), ", "),
	)
	return replacer.Replace(template)
}

// DiffFilePath 返回翻译结果文件绝对路径。
func (c *Config) DiffFilePath() string {
	return c.ResolvePath(c.DiffFile)
}

// SourceJSONPath 返回源 JSON 文件绝对路径。
func (c *Config) SourceJSONPath() string {
	return c.ResolvePath(c.SourceJSONFile)
}

// CustomI18nOutputDirPath 返回自定义 i18n 输出目录绝对路径。
func (c *Config) CustomI18nOutputDirPath() string {
	return c.ResolvePath(c.CustomI18nOutputDir)
}

func containsLocale(locales []string, target string) bool {
	for _, locale := range locales {
		if locale == target {
			return true
		}
	}
	return false
}

func findPackageRoot(startDir string) string {
	dir, err := filepath.Abs(startDir)
	if err != nil {
		return startDir
	}

	for {
		if isFile(filepath.Join(dir, "pubspec.yaml")) && isDir(filepath.Join(dir, "tools")) {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	return filepath.Clean(filepath.Join(startDir, "..", ".."))
}

func findProjectRoot(startDir string) string {
	dir, err := filepath.Abs(startDir)
	if err != nil {
		return startDir
	}

	for {
		pubspec := filepath.Join(dir, "pubspec.yaml")
		packagesDir := filepath.Join(dir, "packages")
		if isFile(pubspec) && isDir(packagesDir) {
			return dir
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	fallback := filepath.Clean(filepath.Join(startDir, "..", "..", ".."))
	if isFile(filepath.Join(fallback, "pubspec.yaml")) {
		return fallback
	}

	return startDir
}

func unescapeEnvValue(value string) string {
	replacer := strings.NewReplacer(
		`\\n`, "\n",
		`\\t`, "\t",
		`\n`, "\n",
		`\t`, "\t",
	)
	return replacer.Replace(value)
}

func alternateConfigExt(path string) string {
	switch filepath.Ext(path) {
	case ".yaml":
		return strings.TrimSuffix(path, ".yaml") + ".yml"
	case ".yml":
		return strings.TrimSuffix(path, ".yml") + ".yaml"
	default:
		return ""
	}
}

func isFile(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

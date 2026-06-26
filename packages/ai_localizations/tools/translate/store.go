package translate

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/config"
	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/diff"
)

// LocaleTranslations diff 文件结构：locale -> key -> 译文。
type LocaleTranslations map[string]map[string]string

// LoadExisting 加载已有 diff 文件；不存在则返回空数据，不创建文件。
func LoadExisting(cfg *config.Config) (LocaleTranslations, error) {
	data, err := loadFromFile(cfg.DiffFilePath())
	if os.IsNotExist(err) {
		return make(LocaleTranslations), nil
	}
	return data, err
}

func loadFromFile(path string) (LocaleTranslations, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if len(content) == 0 {
		return make(LocaleTranslations), nil
	}

	var data LocaleTranslations
	if err := json.Unmarshal(content, &data); err != nil {
		return nil, fmt.Errorf("解析 diff 文件失败: %w", err)
	}
	if data == nil {
		data = make(LocaleTranslations)
	}
	return data, nil
}

// MergeTranslations 将本次翻译结果合并进已有数据。
func MergeTranslations(base, added LocaleTranslations) LocaleTranslations {
	result := make(LocaleTranslations, len(base)+len(added))
	for locale, keys := range base {
		localeData := make(map[string]string, len(keys))
		for key, text := range keys {
			localeData[key] = text
		}
		result[locale] = localeData
	}
	for locale, keys := range added {
		if result[locale] == nil {
			result[locale] = make(map[string]string, len(keys))
		}
		for key, text := range keys {
			result[locale][key] = text
		}
	}
	return result
}

// Save 将 diff 数据写入配置文件中的 diff_file。
func Save(cfg *config.Config, data LocaleTranslations) error {
	path := cfg.DiffFilePath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("创建 diff 目录失败: %w", err)
	}

	encoded, err := json.MarshalIndent(normalize(data), "", "  ")
	if err != nil {
		return fmt.Errorf("序列化 diff 数据失败: %w", err)
	}
	encoded = append(encoded, '\n')

	if err := os.WriteFile(path, encoded, 0o644); err != nil {
		return fmt.Errorf("写入 diff 文件失败: %w", err)
	}
	return nil
}

func normalize(data LocaleTranslations) LocaleTranslations {
	locales := make([]string, 0, len(data))
	for locale := range data {
		locales = append(locales, locale)
	}
	sort.Strings(locales)

	result := make(LocaleTranslations, len(locales))
	for _, locale := range locales {
		keys := make([]string, 0, len(data[locale]))
		for key := range data[locale] {
			keys = append(keys, key)
		}
		sort.Strings(keys)

		localeData := make(map[string]string, len(keys))
		for _, key := range keys {
			localeData[key] = data[locale][key]
		}
		result[locale] = localeData
	}
	return result
}

func sortedKeys(data diff.PendingTranslations) []string {
	keys := make([]string, 0, len(data))
	for key := range data {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

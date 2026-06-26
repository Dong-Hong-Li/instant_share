package apply

import (
	"fmt"
	"os"

	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/arb"
	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/config"
	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/translate"
)

// Result 第四步执行结果。
type Result struct {
	Locales []LocaleResult
}

// LocaleResult 单个语言的 ARB 更新结果。
type LocaleResult struct {
	Locale  string
	ARBPath string
	Added   int
	Removed int
	Updated int
}

// Run 第四步：将翻译结果写入 ARB，并调用 Dart 代码生成。
func Run(cfg *config.Config) error {
	sourceData, err := arb.LoadSourceData(cfg.SourceJSONPath())
	if err != nil {
		return err
	}

	translations, err := translate.LoadExisting(cfg)
	if err != nil {
		return err
	}

	result := &Result{}
	for _, locale := range cfg.LocalesList() {
		localeResult, err := applyLocale(cfg, locale, sourceData, translations)
		if err != nil {
			return err
		}
		result.Locales = append(result.Locales, *localeResult)
	}
	PrintResult(result)

	if err := runDartGenerate(cfg); err != nil {
		return err
	}
	return nil
}

func applyLocale(
	cfg *config.Config,
	locale string,
	sourceData map[string]string,
	translations translate.LocaleTranslations,
) (*LocaleResult, error) {
	arbPath := cfg.ArbFilePath(locale)
	_, existing, err := arb.LoadARB(arbPath)
	if err != nil {
		if !os.IsNotExist(err) {
			return nil, fmt.Errorf("读取 ARB 失败 (%s): %w", arbPath, err)
		}
		existing = map[string]string{}
	}

	merged, stats := mergeLocaleData(cfg, locale, existing, sourceData, translations)
	if err := arb.WriteARB(arbPath, config.BCP47ToArbLocale(locale), merged); err != nil {
		return nil, fmt.Errorf("写入 ARB 失败 (%s): %w", arbPath, err)
	}

	return &LocaleResult{
		Locale:  locale,
		ARBPath: arbPath,
		Added:   stats.added,
		Removed: stats.removed,
		Updated: stats.updated,
	}, nil
}

type mergeStats struct {
	added   int
	removed int
	updated int
}

func mergeLocaleData(
	cfg *config.Config,
	locale string,
	existing map[string]string,
	sourceData map[string]string,
	translations translate.LocaleTranslations,
) (map[string]string, mergeStats) {
	stats := mergeStats{}
	merged := make(map[string]string, len(sourceData))
	sourceKeys := make(map[string]struct{}, len(sourceData))
	for key := range sourceData {
		sourceKeys[key] = struct{}{}
	}

	for key := range existing {
		if _, ok := sourceKeys[key]; !ok {
			stats.removed++
		}
	}

	if locale == cfg.PrimaryLocale() {
		for key, value := range sourceData {
			if old, ok := existing[key]; !ok {
				merged[key] = value
				stats.added++
			} else if old != value {
				merged[key] = value
				stats.updated++
			} else {
				merged[key] = value
			}
		}
		return merged, stats
	}

	localeTranslations := translations[locale]
	for key := range sourceData {
		text, ok := localeTranslations[key]
		if !ok || text == "" {
			continue
		}
		if old, exists := existing[key]; !exists {
			merged[key] = text
			stats.added++
		} else if old != text {
			merged[key] = text
			stats.updated++
		} else {
			merged[key] = text
		}
	}
	return merged, stats
}

// PrintResult 输出 ARB 更新摘要。
func PrintResult(result *Result) {
	for _, item := range result.Locales {
		fmt.Printf(
			"[%s] 新增 %d / 更新 %d / 删除 %d -> %s\n",
			item.Locale,
			item.Added,
			item.Updated,
			item.Removed,
			item.ARBPath,
		)
	}
}

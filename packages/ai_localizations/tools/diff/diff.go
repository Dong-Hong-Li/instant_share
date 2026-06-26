package diff

import (
	"fmt"
	"sort"

	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/arb"
	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/config"
)

// PendingTranslations 待翻译内容：key -> 缺失该 key 的目标 locale 列表。
type PendingTranslations map[string][]string

// Result 第二步对比结果。
type Result struct {
	SourceKeys map[string]string   // translations.json 中的 source_data
	Pending    PendingTranslations // 待翻译：key -> [en, ja, ...]
}

// Collect 遍历 source_data，对比各目标语言 ARB，收集缺失的 key。
func Collect(cfg *config.Config) (*Result, error) {
	sourceData, err := arb.LoadSourceData(cfg.SourceJSONPath())
	if err != nil {
		return nil, err
	}

	targetLocales := cfg.TargetLocales()
	localeARB := make(map[string]map[string]string, len(targetLocales))

	for _, locale := range targetLocales {
		arbPath := cfg.ArbFilePath(locale)
		if !arb.FileExists(arbPath) {
			return nil, fmt.Errorf("ARB 文件不存在: %s（请先执行第一步）", arbPath)
		}
		_, data, err := arb.LoadARB(arbPath)
		if err != nil {
			return nil, fmt.Errorf("读取 ARB 失败 (%s): %w", arbPath, err)
		}
		localeARB[locale] = data
	}

	pending := make(PendingTranslations)
	sourceKeys := sortedKeys(sourceData)

	for _, key := range sourceKeys {
		missingLocales := make([]string, 0, len(targetLocales))
		for _, locale := range targetLocales {
			if _, ok := localeARB[locale][key]; !ok {
				missingLocales = append(missingLocales, locale)
			}
		}
		if len(missingLocales) > 0 {
			pending[key] = missingLocales
		}
	}

	return &Result{
		SourceKeys: sourceData,
		Pending:    pending,
	}, nil
}

func sortedKeys(data map[string]string) []string {
	keys := make([]string, 0, len(data))
	for key := range data {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func sortedPendingKeys(data PendingTranslations) []string {
	keys := make([]string, 0, len(data))
	for key := range data {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

// PrintResult 输出待翻译摘要。
func PrintResult(result *Result) {
	fmt.Printf("source_data: %d 个键\n", len(result.SourceKeys))
	fmt.Printf("待翻译: %d 个键\n", len(result.Pending))
	for _, key := range sortedPendingKeys(result.Pending) {
		fmt.Printf("  %s -> %v\n", key, result.Pending[key])
	}
}

package arb

import (
	"fmt"

	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/config"
)

// LocaleStatus 单个 locale 的 ARB 处理结果。
type LocaleStatus struct {
	Locale  string
	ARBPath string
	Existed bool
	Created bool
}

// SyncResult ARB 同步结果。
type SyncResult struct {
	SourceKeys int
	Locales    []LocaleStatus
}

// Sync 读取 translations.json，检查各 locale 的 ARB 文件是否存在，不存在则创建空文件。
func Sync(cfg *config.Config) (*SyncResult, error) {
	sourceData, err := LoadSourceData(cfg.SourceJSONPath())
	if err != nil {
		return nil, err
	}

	result := &SyncResult{SourceKeys: len(sourceData)}
	for _, locale := range cfg.LocalesList() {
		status, err := syncLocale(cfg, locale)
		if err != nil {
			return nil, err
		}
		result.Locales = append(result.Locales, *status)
	}
	return result, nil
}

func syncLocale(cfg *config.Config, locale string) (*LocaleStatus, error) {
	arbPath := cfg.ArbFilePath(locale)
	status := &LocaleStatus{
		Locale:  locale,
		ARBPath: arbPath,
		Existed: fileExists(arbPath),
	}

	if status.Existed {
		return status, nil
	}

	if err := WriteARB(arbPath, config.BCP47ToArbLocale(locale), map[string]string{}); err != nil {
		return nil, err
	}
	status.Created = true
	return status, nil
}

// PrintResult 输出同步结果摘要。
func PrintResult(result *SyncResult) {
	fmt.Printf("source_data: %d 个键\n", result.SourceKeys)
	for _, item := range result.Locales {
		action := "已存在"
		if item.Created {
			action = "已创建（仅 @@locale）"
		}
		fmt.Printf("[%s] %s -> %s\n", item.Locale, action, item.ARBPath)
	}
}

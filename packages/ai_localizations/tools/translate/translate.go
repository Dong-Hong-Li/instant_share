package translate

import (
	"fmt"

	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/config"
	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/diff"
)

// Run 第三步：分批调用 AI 翻译，全部完成后一次性写入 diff 文件。
func Run(cfg *config.Config, result *diff.Result) error {
	if len(result.Pending) == 0 {
		fmt.Println("无待翻译内容，跳过第三步")
		return nil
	}

	existing, err := LoadExisting(cfg)
	if err != nil {
		return err
	}

	tasks := BuildTasks(existing, result)
	if len(tasks) == 0 {
		fmt.Println("diff 文件中已全部翻译，跳过第三步")
		return nil
	}

	client := NewClient(cfg)
	chunks := ChunkTasks(tasks)
	fmt.Printf("待翻译 %d 条，分 %d 批（每批最多 %d 条）\n", len(tasks), len(chunks), BatchSize)

	translated := make(LocaleTranslations)
	for index, batch := range chunks {
		fmt.Printf("\n--- 第 %d/%d 批 ---\n", index+1, len(chunks))
		items, err := client.TranslateBatch(batch)
		if err != nil {
			return fmt.Errorf("第 %d 批翻译失败: %w", index+1, err)
		}

		for _, item := range items {
			if translated[item.Locale] == nil {
				translated[item.Locale] = make(map[string]string)
			}
			translated[item.Locale][item.Key] = item.Text
			fmt.Printf("%s_%s : %s\n", item.Key, item.Locale, item.Text)
		}
	}

	final := MergeTranslations(existing, translated)
	if err := Save(cfg, final); err != nil {
		return fmt.Errorf("写入 diff 文件失败: %w", err)
	}
	fmt.Printf("翻译完成，已写入 diff 文件: %s\n", cfg.DiffFilePath())
	return nil
}

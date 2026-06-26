package translate

import (
	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/diff"
)

const BatchSize = 10

// Task 单条待翻译任务。
type Task struct {
	Key    string
	Locale string
	Source string
}

// BuildTasks 从 diff 结果与已有译文生成尚未翻译的任务列表。
func BuildTasks(existing LocaleTranslations, result *diff.Result) []Task {
	tasks := make([]Task, 0)
	keys := sortedKeys(result.Pending)

	for _, key := range keys {
		source := result.SourceKeys[key]
		for _, locale := range result.Pending[key] {
			current := ""
			if localeData, ok := existing[locale]; ok {
				current = localeData[key]
			}
			if current != "" && current != source {
				continue
			}
			tasks = append(tasks, Task{
				Key:    key,
				Locale: locale,
				Source: source,
			})
		}
	}
	return tasks
}

// ChunkTasks 将任务按批大小切分。
func ChunkTasks(tasks []Task) [][]Task {
	if len(tasks) == 0 {
		return nil
	}

	chunks := make([][]Task, 0, (len(tasks)+BatchSize-1)/BatchSize)
	for i := 0; i < len(tasks); i += BatchSize {
		end := i + BatchSize
		if end > len(tasks) {
			end = len(tasks)
		}
		chunks = append(chunks, tasks[i:end])
	}
	return chunks
}

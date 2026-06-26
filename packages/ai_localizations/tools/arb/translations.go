package arb

import (
	"encoding/json"
	"fmt"
	"os"
)

type translationsFile struct {
	SourceData map[string]string `json:"source_data"`
}

// LoadSourceData 读取 translations.json 中的 source_data。
func LoadSourceData(path string) (map[string]string, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("读取 translations.json 失败: %w", err)
	}

	var file translationsFile
	if err := json.Unmarshal(content, &file); err != nil {
		return nil, fmt.Errorf("解析 translations.json 失败: %w", err)
	}
	if len(file.SourceData) == 0 {
		return nil, fmt.Errorf("translations.json 缺少 source_data 或为空")
	}

	result := make(map[string]string, len(file.SourceData))
	for key, value := range file.SourceData {
		if key == "" {
			return nil, fmt.Errorf("translations.json 中存在空键")
		}
		result[key] = value
	}
	return result, nil
}

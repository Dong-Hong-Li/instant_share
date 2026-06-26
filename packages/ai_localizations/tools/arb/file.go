package arb

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
)

const localeMetadataKey = "@@locale"

// LoadARB 读取 ARB 文件，返回 locale 与翻译键值（不含元数据键）。
func LoadARB(path string) (string, map[string]string, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return "", nil, err
	}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(content, &raw); err != nil {
		return "", nil, fmt.Errorf("解析 ARB 失败: %w", err)
	}

	locale := ""
	translations := make(map[string]string, len(raw))
	for key, rawValue := range raw {
		if strings.HasPrefix(key, "@") {
			if key == localeMetadataKey {
				if err := json.Unmarshal(rawValue, &locale); err != nil {
					return "", nil, fmt.Errorf("解析 %s 失败: %w", localeMetadataKey, err)
				}
			}
			continue
		}
		var value string
		if err := json.Unmarshal(rawValue, &value); err != nil {
			return "", nil, fmt.Errorf("解析键 %q 失败: %w", key, err)
		}
		translations[key] = value
	}
	return locale, translations, nil
}

// WriteARB 写入 ARB 文件，@@locale 置顶，其余键按字母序。
func WriteARB(path string, locale string, translations map[string]string) error {
	keys := make([]string, 0, len(translations))
	for key := range translations {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	var buf bytes.Buffer
	buf.WriteString("{\n")

	localeJSON, err := json.Marshal(locale)
	if err != nil {
		return err
	}
	buf.WriteString(fmt.Sprintf("  %q: %s", localeMetadataKey, localeJSON))

	for _, key := range keys {
		keyJSON, err := json.Marshal(key)
		if err != nil {
			return err
		}
		valueJSON, err := json.Marshal(translations[key])
		if err != nil {
			return err
		}
		buf.WriteString(",\n")
		buf.WriteString(fmt.Sprintf("  %s: %s", keyJSON, valueJSON))
	}
	buf.WriteString("\n}\n")

	if err := os.MkdirAll(dirOf(path), 0o755); err != nil {
		return fmt.Errorf("创建 ARB 目录失败: %w", err)
	}
	if err := os.WriteFile(path, buf.Bytes(), 0o644); err != nil {
		return fmt.Errorf("写入 ARB 失败: %w", err)
	}
	return nil
}

func dirOf(path string) string {
	if idx := strings.LastIndex(path, string(os.PathSeparator)); idx >= 0 {
		return path[:idx]
	}
	return "."
}

// FileExists 判断 ARB 文件是否存在。
func FileExists(path string) bool {
	return fileExists(path)
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

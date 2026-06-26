package config

import (
	"fmt"
	"strings"
	"unicode"
)

// ValidateBCP47Locale 校验 locale 是否为支持的 BCP-47 格式（RFC 5646）。
// 当前支持：language[-script][-region]，例如 zh、en-US、zh-Hans-CN、zh-Hant-HK。
func ValidateBCP47Locale(locale string) error {
	locale = strings.TrimSpace(locale)
	if locale == "" {
		return fmt.Errorf("locale 不能为空")
	}
	if strings.Contains(locale, "_") {
		return fmt.Errorf("locale %q 使用了下划线，须改用 BCP-47 连字符格式（如 zh-Hant-HK，勿用 zh_Hant_HK）", locale)
	}

	parts := strings.Split(locale, "-")
	if len(parts) > 3 {
		return fmt.Errorf("locale %q 格式无效：当前仅支持 language[-script][-region]", locale)
	}

	if err := validateLanguageSubtag(parts[0]); err != nil {
		return fmt.Errorf("locale %q: %w", locale, err)
	}

	switch len(parts) {
	case 1:
		return nil
	case 2:
		return validateSecondSubtag(parts[1])
	case 3:
		if err := validateScriptSubtag(parts[1]); err != nil {
			return fmt.Errorf("locale %q: %w", locale, err)
		}
		if err := validateRegionSubtag(parts[2]); err != nil {
			return fmt.Errorf("locale %q: %w", locale, err)
		}
		return nil
	default:
		return fmt.Errorf("locale %q 格式无效", locale)
	}
}

func validateLanguageSubtag(value string) error {
	if len(value) < 2 || len(value) > 3 {
		return fmt.Errorf("语言代码须为 2-3 位小写字母（ISO 639）")
	}
	for _, r := range value {
		if r < 'a' || r > 'z' {
			return fmt.Errorf("语言代码须为小写（ISO 639）")
		}
	}
	return nil
}

func validateSecondSubtag(value string) error {
	switch len(value) {
	case 4:
		return validateScriptSubtag(value)
	case 2:
		return validateRegionSubtag(value)
	default:
		return fmt.Errorf("第二段须为 4 位文字码（ISO 15924，如 Hans）或 2 位地区码（ISO 3166-1，如 US）")
	}
}

func validateScriptSubtag(value string) error {
	if len(value) != 4 {
		return fmt.Errorf("文字代码须为 4 位 ISO 15924（如 Hans、Hant）")
	}
	if !unicode.IsUpper(rune(value[0])) {
		return fmt.Errorf("文字代码首字母须大写（如 Hans、Hant）")
	}
	for _, r := range value[1:] {
		if !unicode.IsLower(r) {
			return fmt.Errorf("文字代码第 2-4 位须小写（如 Hans、Hant）")
		}
	}
	return nil
}

func validateRegionSubtag(value string) error {
	if len(value) != 2 {
		return fmt.Errorf("地区代码须为 2 位大写字母（ISO 3166-1，如 CN、HK、US）")
	}
	for _, r := range value {
		if r < 'A' || r > 'Z' {
			return fmt.Errorf("地区代码须为大写（ISO 3166-1）")
		}
	}
	return nil
}

// BCP47ToArbLocale 将 config.yaml 中的 BCP-47 标签转为 ARB 文件名与 @@locale 用的下划线格式。
// Flutter 约定 arb locale 段使用下划线，例如 zh-Hant-HK -> zh_Hant_HK，en-US -> en_US。
func BCP47ToArbLocale(tag string) string {
	return strings.ReplaceAll(tag, "-", "_")
}

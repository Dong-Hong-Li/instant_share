package config

import "testing"

func TestBCP47ToArbLocale(t *testing.T) {
	cases := map[string]string{
		"zh":         "zh",
		"en-US":      "en_US",
		"zh-Hans-CN": "zh_Hans_CN",
		"zh-Hant-HK": "zh_Hant_HK",
	}
	for bcp47, arb := range cases {
		if got := BCP47ToArbLocale(bcp47); got != arb {
			t.Errorf("BCP47ToArbLocale(%q) = %q, want %q", bcp47, got, arb)
		}
	}
}

func TestValidateBCP47Locale(t *testing.T) {
	valid := []string{"zh", "en", "ja", "en-US", "pt-BR", "zh-Hans", "zh-Hans-CN", "zh-Hant-HK"}
	for _, locale := range valid {
		if err := ValidateBCP47Locale(locale); err != nil {
			t.Errorf("expected valid locale %q, got error: %v", locale, err)
		}
	}

	invalid := map[string]string{
		"":                 "empty",
		"zh_Hant_HK":       "underscore",
		"zh-hant-hk":       "lowercase script/region",
		"ZH":               "uppercase language",
		"zh-Hans-cn":       "lowercase region",
		"en-us":            "lowercase region",
		"zh-Hant-HK-extra": "too many parts",
	}
	for locale := range invalid {
		if err := ValidateBCP47Locale(locale); err == nil {
			t.Errorf("expected invalid locale %q (%s) to fail", locale, invalid[locale])
		}
	}
}

package translate

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/config"
)

type Client struct {
	httpClient *http.Client
	cfg        *config.Config
}

type batchItem struct {
	Key    string `json:"key"`
	Locale string `json:"locale"`
	Source string `json:"source"`
	Text   string `json:"text,omitempty"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type thinkingConfig struct {
	Type string `json:"type"`
}

type chatRequest struct {
	Model       string          `json:"model"`
	Messages    []chatMessage   `json:"messages"`
	Temperature float64         `json:"temperature"`
	Thinking    *thinkingConfig `json:"thinking,omitempty"`
}

type chatChoice struct {
	Message chatMessage `json:"message"`
}

type chatResponse struct {
	Choices []chatChoice `json:"choices"`
	Error   *apiError    `json:"error,omitempty"`
}

type apiError struct {
	Message string `json:"message"`
	Type    string `json:"type"`
}

func NewClient(cfg *config.Config) *Client {
	return &Client{
		httpClient: &http.Client{Timeout: 120 * time.Second},
		cfg:        cfg,
	}
}

func (c *Client) TranslateBatch(batch []Task) ([]batchItem, error) {
	if len(batch) == 0 {
		return nil, nil
	}

	systemPrompt := c.buildBatchSystemPrompt(batch)
	userPrompt := c.buildBatchUserPrompt(batch)
	content, err := c.chat(systemPrompt, userPrompt)
	if err != nil {
		return nil, err
	}

	items, err := parseBatchResponse(content)
	if err != nil {
		return nil, err
	}
	return mergeBatchResults(batch, items)
}

func (c *Client) buildBatchSystemPrompt(batch []Task) string {
	locales := uniqueLocales(batch)
	if len(locales) == 1 {
		return c.cfg.GetTranslationPromptForTarget(locales[0]) + batchResponseInstruction()
	}

	sourceLocale := c.cfg.PrimaryLocale()
	return fmt.Sprintf(
		"你是专业的 Flutter 应用国际化翻译助手。源语言 locale 为 %s。请将用户给出的 JSON 数组中每条 source 文本翻译成对应 locale 的译文。%s",
		sourceLocale,
		batchResponseInstruction(),
	)
}

func batchResponseInstruction() string {
	return "\n必须只返回 JSON 数组，不要 markdown 代码块，不要额外说明。每项格式：{\"key\":\"...\",\"locale\":\"...\",\"text\":\"译文\"}"
}

func (c *Client) buildBatchUserPrompt(batch []Task) string {
	items := make([]batchItem, len(batch))
	for i, task := range batch {
		items[i] = batchItem{
			Key:    task.Key,
			Locale: task.Locale,
			Source: task.Source,
		}
	}
	encoded, _ := json.Marshal(items)
	return string(encoded)
}

func (c *Client) chat(systemPrompt, userPrompt string) (string, error) {
	ai := c.cfg.AISettings()
	reqBody := chatRequest{
		Model: ai.Model,
		Messages: []chatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userPrompt},
		},
		Temperature: resolveTemperature(ai.Model, ai.Temperature),
	}
	if strings.Contains(strings.ToLower(ai.Model), "kimi") {
		reqBody.Thinking = &thinkingConfig{Type: "disabled"}
	}

	payload, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("构造 AI 请求失败: %w", err)
	}

	url := strings.TrimRight(ai.BaseURL, "/") + "/chat/completions"
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(payload))
	if err != nil {
		return "", fmt.Errorf("创建 AI 请求失败: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+ai.APIKey)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("AI 请求失败: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("读取 AI 响应失败: %w", err)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("AI 请求返回 %d: %s", resp.StatusCode, string(body))
	}

	var parsed chatResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return "", fmt.Errorf("解析 AI 响应失败: %w", err)
	}
	if parsed.Error != nil {
		return "", fmt.Errorf("AI 错误: %s", parsed.Error.Message)
	}
	if len(parsed.Choices) == 0 {
		return "", fmt.Errorf("AI 响应为空")
	}
	return strings.TrimSpace(parsed.Choices[0].Message.Content), nil
}

func parseBatchResponse(content string) ([]batchItem, error) {
	jsonText := extractJSONArray(content)
	var items []batchItem
	if err := json.Unmarshal([]byte(jsonText), &items); err != nil {
		return nil, fmt.Errorf("解析 AI 翻译结果失败: %w\n原始内容: %s", err, content)
	}
	if len(items) == 0 {
		return nil, fmt.Errorf("AI 未返回任何翻译结果")
	}
	return items, nil
}

func extractJSONArray(content string) string {
	trimmed := strings.TrimSpace(content)
	if strings.HasPrefix(trimmed, "```") {
		lines := strings.Split(trimmed, "\n")
		if len(lines) >= 2 {
			lines = lines[1:]
			if len(lines) > 0 && strings.HasPrefix(strings.TrimSpace(lines[len(lines)-1]), "```") {
				lines = lines[:len(lines)-1]
			}
			trimmed = strings.TrimSpace(strings.Join(lines, "\n"))
		}
	}
	start := strings.Index(trimmed, "[")
	end := strings.LastIndex(trimmed, "]")
	if start >= 0 && end > start {
		return trimmed[start : end+1]
	}
	return trimmed
}

func mergeBatchResults(batch []Task, items []batchItem) ([]batchItem, error) {
	lookup := make(map[string]string, len(items))
	for _, item := range items {
		text := strings.TrimSpace(item.Text)
		if item.Key == "" || item.Locale == "" || text == "" {
			continue
		}
		lookup[item.Key+"\x00"+item.Locale] = cleanTranslation(text)
	}

	results := make([]batchItem, 0, len(batch))
	for _, task := range batch {
		text, ok := lookup[task.Key+"\x00"+task.Locale]
		if !ok || text == "" {
			return nil, fmt.Errorf("AI 缺少翻译结果: key=%s locale=%s", task.Key, task.Locale)
		}
		results = append(results, batchItem{
			Key:    task.Key,
			Locale: task.Locale,
			Source: task.Source,
			Text:   text,
		})
	}
	return results, nil
}

func cleanTranslation(text string) string {
	text = strings.TrimSpace(text)
	if len(text) >= 2 {
		if (text[0] == '"' && text[len(text)-1] == '"') || (text[0] == '\'' && text[len(text)-1] == '\'') {
			return text[1 : len(text)-1]
		}
	}
	return text
}

func resolveTemperature(model string, configured float64) float64 {
	modelLower := strings.ToLower(model)
	// 针对 kimi 模型，设置温度为 0.6
	if strings.Contains(modelLower, "kimi-k2.6") || strings.Contains(modelLower, "kimi-k2-6") {
		return 0.6
	}
	return configured
}

func uniqueLocales(batch []Task) []string {
	seen := make(map[string]struct{})
	locales := make([]string, 0)
	for _, task := range batch {
		if _, ok := seen[task.Locale]; ok {
			continue
		}
		seen[task.Locale] = struct{}{}
		locales = append(locales, task.Locale)
	}
	return locales
}

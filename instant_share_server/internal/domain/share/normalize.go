package share

import (
	"fmt"
	"os"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
)

// MaxArticleContentLength 文章内容最大字符数。
const MaxArticleContentLength = 2000

// NormalizeFiles 校验本地路径并补全 id/name/size。
func NormalizeFiles(files []ShareFile) ([]ShareFile, error) {
	if len(files) == 0 {
		return []ShareFile{}, nil
	}
	result := make([]ShareFile, 0, len(files))
	for _, file := range files {
		if file.Path == "" {
			return nil, fmt.Errorf("file path is required")
		}
		info, err := os.Stat(file.Path)
		if err != nil {
			return nil, fmt.Errorf("invalid file %q: %w", file.Path, err)
		}
		if info.IsDir() {
			return nil, fmt.Errorf("directory sharing is not supported yet: %q", file.Path)
		}

		name := file.Name
		if name == "" {
			name = info.Name()
		}
		id := file.ID
		if id == "" {
			id = uuid.NewString()
		}

		result = append(result, ShareFile{
			ID:   id,
			Path: file.Path,
			Name: name,
			Size: info.Size(),
		})
	}
	return result, nil
}

// NormalizeArticles 校验并规范化文章列表。
func NormalizeArticles(articles []ShareArticle) ([]ShareArticle, error) {
	if len(articles) == 0 {
		return []ShareArticle{}, nil
	}

	result := make([]ShareArticle, 0, len(articles))
	for _, article := range articles {
		content := strings.TrimSpace(article.Content)
		if content == "" {
			return nil, fmt.Errorf("article content is required")
		}
		if utf8.RuneCountInString(content) > MaxArticleContentLength {
			return nil, fmt.Errorf("article content exceeds %d characters", MaxArticleContentLength)
		}

		id := strings.TrimSpace(article.ID)
		if id == "" {
			id = uuid.NewString()
		}

		result = append(result, ShareArticle{
			ID:      id,
			Title:   strings.TrimSpace(article.Title),
			Content: content,
		})
	}
	return result, nil
}

// CloneStatus 深拷贝状态中的切片。
func CloneStatus(status Status) Status {
	files := make([]ShareFile, len(status.Files))
	copy(files, status.Files)
	status.Files = files

	articles := make([]ShareArticle, len(status.Articles))
	copy(articles, status.Articles)
	status.Articles = articles

	return status
}

package service

import (
	"fmt"
	"os"
	"strings"
	"unicode/utf8"

	"instant_share/server/internal/domain/share"

	"github.com/google/uuid"
)

// normalizeFiles 校验本地路径并补全 id/name/size。
func normalizeFiles(files []share.ShareFile) ([]share.ShareFile, error) {
	if len(files) == 0 {
		return []share.ShareFile{}, nil
	}
	result := make([]share.ShareFile, 0, len(files))
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

		result = append(result, share.ShareFile{
			ID:   id,
			Path: file.Path,
			Name: name,
			Size: info.Size(),
		})
	}
	return result, nil
}

// normalizeArticles 校验文章内容长度并补全 id。
func normalizeArticles(articles []share.ShareArticle) ([]share.ShareArticle, error) {
	if len(articles) == 0 {
		return []share.ShareArticle{}, nil
	}

	result := make([]share.ShareArticle, 0, len(articles))
	for _, article := range articles {
		content := strings.TrimSpace(article.Content)
		if content == "" {
			return nil, fmt.Errorf("article content is required")
		}
		if utf8.RuneCountInString(content) > share.MaxArticleContentLength {
			return nil, fmt.Errorf("article content exceeds %d characters", share.MaxArticleContentLength)
		}

		id := strings.TrimSpace(article.ID)
		if id == "" {
			id = uuid.NewString()
		}

		result = append(result, share.ShareArticle{
			ID:      id,
			Title:   strings.TrimSpace(article.Title),
			Content: content,
		})
	}
	return result, nil
}

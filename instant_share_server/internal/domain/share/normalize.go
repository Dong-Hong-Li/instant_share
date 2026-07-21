package share

import (
	"fmt"
	"os"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
)

// MaxArticleContentLength 文章内容最大字符数（按 rune 计）。
const MaxArticleContentLength = 2000

/**
 * @description: NormalizeFiles 校验本地路径存在且非目录，并补全 id/name/size。
 * @param {[]ShareFile} files 原始文件列表（允许空）
 * @return {[]ShareFile, error} 规范化后的列表；路径无效时返回 error
 */
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

/**
 * @description: NormalizeArticles 校验正文非空且不超过 MaxArticleContentLength，并补全 id。
 * @param {[]ShareArticle} articles 原始文章列表（允许空）
 * @return {[]ShareArticle, error}
 */
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

/**
 * @description: CloneStatus 深拷贝 Status 中的 Files/Articles 切片，避免调用方误改内部状态。
 * @param {Status} status 源状态
 * @return {Status} 副本
 */
func CloneStatus(status Status) Status {
	files := make([]ShareFile, len(status.Files))
	copy(files, status.Files)
	status.Files = files

	articles := make([]ShareArticle, len(status.Articles))
	copy(articles, status.Articles)
	status.Articles = articles

	return status
}

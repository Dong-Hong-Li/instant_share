package main

import (
	"fmt"
	"log"

	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/apply"
	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/arb"
	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/config"
	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/diff"
	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/translate"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("加载配置失败: %v", err)
	}

	fmt.Println("==> 第一步：检查并创建 ARB 文件")
	syncResult, err := arb.Sync(cfg)
	if err != nil {
		log.Fatalf("ARB 同步失败: %v", err)
	}
	arb.PrintResult(syncResult)

	fmt.Println("\n==> 第二步：对比 translations.json 与 ARB，收集待翻译内容")
	diffResult, err := diff.Collect(cfg)
	if err != nil {
		log.Fatalf("差异对比失败: %v", err)
	}
	diff.PrintResult(diffResult)

	fmt.Println("\n==> 第三步：AI 分批翻译并写入 diff 文件")
	if err := translate.Run(cfg, diffResult); err != nil {
		log.Fatalf("AI 翻译失败: %v", err)
	}

	fmt.Println("\n==> 第四步：写入 ARB 并生成 Dart 代码")
	if err := apply.Run(cfg); err != nil {
		log.Fatalf("ARB 更新或代码生成失败: %v", err)
	}
}

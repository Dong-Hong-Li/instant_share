package apply

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"gitee.com/lidonghonglalala/flutter_template/packages/ai_localizations/tools/config"
)

func runDartGenerate(cfg *config.Config) error {
	packageRoot := cfg.PackageRoot()
	generator := filepath.Join("tools", "dart", "generate.dart")
	if _, err := os.Stat(filepath.Join(packageRoot, generator)); err != nil {
		return fmt.Errorf("找不到 Dart 生成器: %s", filepath.Join(packageRoot, generator))
	}

	fmt.Println("\n--- 调用 Dart 代码生成 ---")
	cmd := exec.Command("dart", "run", generator)
	cmd.Dir = packageRoot
	cmd.Env = os.Environ()
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("Dart 代码生成失败: %w", err)
	}
	return nil
}

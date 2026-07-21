package repository

import "instant_share/server/internal/domain/share"

// Store 本机分享会话状态端口：用例读写当前分享快照与按 id 查文件。
//
// 表达「share 上下文需要什么状态能力」，不关心内存/磁盘实现。
type Store interface {
	/**
	 * @description: Snapshot 读取当前会话状态副本。
	 * @return {share.Status}
	 */
	Snapshot() share.Status

	/**
	 * @description: ReplaceActive 用完整状态替换当前会话（开启或同步后写入）。
	 * @param {share.Status} status 新状态
	 */
	ReplaceActive(status share.Status)

	/**
	 * @description: Clear 结束会话并清空文件/文章，保留端口字段供下次开启使用。
	 */
	Clear()

	/**
	 * @description: FileByID 按文件 id 查询本机会话中的文件。
	 * @param {string} id
	 * @return {share.ShareFile, bool}
	 */
	FileByID(id string) (share.ShareFile, bool)

	/**
	 * @description: Port 读取会话关联的 HTTP 端口。
	 * @return {int}
	 */
	Port() int

	/**
	 * @description: SetPort 写入会话关联的 HTTP 端口。
	 * @param {int} port
	 */
	SetPort(port int)
}

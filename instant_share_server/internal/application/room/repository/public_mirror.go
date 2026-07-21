package repository

import "instant_share/server/internal/domain/room"

// PublicMirror 公开聚合目录镜像端口：本节点缓存一份跨设备 SharedEntry 列表，供公开状态查询读取。
//
// 表达 room 上下文「需要读写一份公开目录镜像」的能力；不描述协议帧或客户端如何同步。
type PublicMirror interface {
	/**
	 * @description: Set 覆盖镜像中的目录条目；entries 为 nil 表示清空。
	 * @param {[]room.SharedEntry} entries
	 */
	Set(entries []room.SharedEntry)

	/**
	 * @description: Clear 清空镜像。
	 */
	Clear()

	/**
	 * @description: Entries 读取镜像副本；无数据时返回 nil。
	 * @return {[]room.SharedEntry}
	 */
	Entries() []room.SharedEntry
}

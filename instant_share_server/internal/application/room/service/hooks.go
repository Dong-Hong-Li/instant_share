package service

// CatalogUpdatedHook 房间聚合目录变更后的应用内通知（由装配层注入，非 repository 端口）。
type CatalogUpdatedHook func()

// PendingUpdatedHook 待审批列表变更后的应用内通知（由装配层注入，非 repository 端口）。
type PendingUpdatedHook func()

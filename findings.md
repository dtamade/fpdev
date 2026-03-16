## 2026-03-07 build.cache artifact meta helper 第一切片 (B263)

- Root cause:
  - `TBuildCache.SaveArtifactMetadata` 仍直接承载旧式 source `.meta` 文件内容拼装与写盘逻辑，wrapper 里还有一段可抽离的文件写入细节。
- Decision:
  - 新增 `src/fpdev.build.cache.artifactmeta.pas`。
  - 抽离 `BuildCacheSaveArtifactMeta`。
  - `SaveArtifactMetadata` 改为：source meta path lookup + host CPU/OS lookup -> artifact meta helper。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_artifactmeta.lpr` -> `Can't find unit fpdev.build.cache.artifactmeta`
  - `test_build_cache_artifactmeta 6/6`
  - `test_cache_space 8/8`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `212/212` passed

## 2026-03-07 build.cache entry query helper 第一切片 (B262)

- Root cause:
  - `TBuildCache.NeedsRebuild` 与 `TBuildCache.GetRevision` 仍各自保留 entry-line 查询逻辑，wrapper 里还有一段可抽离的纯查询代码。
- Decision:
  - 新增 `src/fpdev.build.cache.entryquery.pas`。
  - 抽离 `BuildCacheNeedsRebuildFromEntryLine` 与 `BuildCacheGetRevisionFromEntryLine`。
  - `NeedsRebuild` / `GetRevision` 改为 entry lookup 后委托 helper。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_entryquery.lpr` -> `Can't find unit fpdev.build.cache.entryquery`
  - `test_build_cache_entryquery 7/7`
  - `test_build_cache_entryio 22/22`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `212/212` passed

## 2026-03-07 build.cache cache stats helper 第一切片 (B261)

- Root cause:
  - `TBuildCache.GetCacheStats` 仍内嵌 total-request 计算、命中率计算和字符串格式化逻辑，wrapper 里还有一段可抽离的纯展示代码。
- Decision:
  - 新增 `src/fpdev.build.cache.cachestats.pas`。
  - 抽离 `BuildCacheFormatCacheStats`。
  - `GetCacheStats` 改为：counter lookup -> cache stats helper。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_cachestats.lpr` -> `Can't find unit fpdev.build.cache.cachestats`
  - `test_build_cache_cachestats 2/2`
  - `test_build_cache_binary 19/19`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `210/210` passed

## 2026-03-07 build.cache source path helper 第一切片 (B260)

- Root cause:
  - `TBuildCache.GetArtifactArchivePath` 与 `TBuildCache.GetArtifactMetaPath` 仍内嵌 source cache 文件路径拼装逻辑，wrapper 里还有一段可抽离的纯路径组合代码。
- Decision:
  - 新增 `src/fpdev.build.cache.sourcepath.pas`。
  - 抽离 `BuildCacheGetSourceArchivePath` 与 `BuildCacheGetSourceMetaPath`。
  - 两个方法改为：artifact key lookup -> source path helper。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_sourcepath.lpr` -> `Can't find unit fpdev.build.cache.sourcepath`
  - `test_build_cache_sourcepath 2/2`
  - `test_cache_metadata 38/38`
  - `test_cache_ttl 9/9`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `209/209` passed

## 2026-03-07 build.cache json path helper 第一切片 (B259)

- Root cause:
  - `TBuildCache.GetJSONMetaPath` 仍内嵌 JSON metadata 文件路径拼装逻辑，wrapper 还有一段可抽离的纯路径组合代码。
- Decision:
  - 新增 `src/fpdev.build.cache.jsonpath.pas`。
  - 抽离 `BuildCacheGetJSONMetaPath`。
  - `GetJSONMetaPath` 改为：artifact key lookup -> json path helper。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_jsonpath.lpr` -> `Can't find unit fpdev.build.cache.jsonpath`
  - `test_build_cache_jsonpath 1/1`
  - `test_cache_metadata 38/38`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `208/208` passed

## 2026-03-07 build.cache json save helper 第一切片 (B258)

- Root cause:
  - `TBuildCache.SaveMetadataJSON` 仍内嵌 `TArtifactInfo -> BuildCacheSaveMetadataJSON` 参数映射逻辑，wrapper 里还有一段可纯化的 JSON metadata 写入映射代码。
- Decision:
  - 新增 `src/fpdev.build.cache.jsonsave.pas`。
  - 抽离 `BuildCacheCreateMetaJSONArtifactInfo`。
  - `SaveMetadataJSON` 改为：record mapping helper -> existing `BuildCacheSaveMetadataJSON` call。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_jsonsave.lpr` -> `Can't find unit fpdev.build.cache.jsonsave`
  - `test_build_cache_jsonsave 12/12`
  - `test_cache_metadata 38/38`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `208/208` passed

## 2026-03-07 build.cache json info helper 第一切片 (B257)

- Root cause:
  - `TBuildCache.LoadMetadataJSON` 仍内嵌 `TMetaJSONArtifactInfo -> TArtifactInfo` 的字段搬运逻辑，wrapper 里还有一段可纯化的 JSON metadata 映射代码。
- Decision:
  - 新增 `src/fpdev.build.cache.jsoninfo.pas`。
  - 抽离 `BuildCacheCreateJSONArtifactInfo`。
  - `LoadMetadataJSON` 改为：JSON file load -> json info helper -> success/failure contract。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_jsoninfo.lpr` -> `Can't find unit fpdev.build.cache.jsoninfo`
  - `test_build_cache_jsoninfo 12/12`
  - `test_cache_metadata 38/38`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `206/206` passed

## 2026-03-07 build.cache migration backup helper 第一切片 (B256)

- Root cause:
  - `TBuildCache.MigrateMetadataToJSON` 仍内嵌 old `.meta` 的 backup path 拼装和 rename/overwrite 收尾逻辑，wrapper 还夹带了一段可抽离的文件系统细节。
- Decision:
  - 新增 `src/fpdev.build.cache.migrationbackup.pas`。
  - 抽离 `BuildCacheGetMetaBackupPath` 与 `BuildCacheFinalizeMetaMigration`。
  - `MigrateMetadataToJSON` 改为：old-meta check -> legacy read -> JSON save -> JSON verify -> migration backup helper。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_migrationbackup.lpr` -> `Can't find unit fpdev.build.cache.migrationbackup`
  - `test_build_cache_migrationbackup 7/7`
  - `test_cache_metadata 38/38`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `205/205` passed

## 2026-03-07 build.cache delete files helper 第一切片 (B255)

- Root cause:
  - `TBuildCache.DeleteArtifacts` 仍直接承载 source archive/meta 的文件存在性判断与删除动作，wrapper 里还有一段可抽离的文件系统细节代码。
- Decision:
  - 新增 `src/fpdev.build.cache.deletefiles.pas`。
  - 抽离 `BuildCacheDeleteArtifactFiles`。
  - `DeleteArtifacts` 改为：source archive/meta path lookup -> delete helper。
  - 保持当前行为不变：缺失文件视为成功，且仅处理 source artifact 的 `.tar.gz`/`.meta` 对。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_deletefiles.lpr` -> `Can't find unit fpdev.build.cache.deletefiles`
  - `test_build_cache_deletefiles 4/4`
  - `test_cache_ttl 9/9`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `204/204` passed

## 2026-03-07 build.cache source info helper 第一切片 (B254)

- Root cause:
  - `TBuildCache.GetArtifactInfo` 仍内嵌 `TOldMetaArtifactInfo -> TArtifactInfo` 字段搬运逻辑，wrapper 里还有一段可纯化的 source metadata 映射代码。
- Decision:
  - 新增 `src/fpdev.build.cache.sourceinfo.pas`。
  - 抽离 `BuildCacheCreateSourceArtifactInfo`。
  - `GetArtifactInfo` 改为：source path lookup -> `BuildCacheLoadOldMeta` -> source info helper。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_sourceinfo.lpr` -> `Can't find unit fpdev.build.cache.sourceinfo`
  - `test_build_cache_sourceinfo 7/7`
  - `test_cache_metadata 38/38`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `203/203` passed

## 2026-03-07 build.cache expired scan helper 第一切片 (B253)

- Root cause:
  - `TBuildCache.CleanExpired` 仍内嵌 `.meta` 文件扫描、版本提取、artifact info 加载与过期过滤逻辑，wrapper 还没有收敛成单纯的删除 orchestration。
- Decision:
  - 新增 `src/fpdev.build.cache.expiredscan.pas`。
  - 抽离 `TBuildCacheExpiredInfoLoader`、`TBuildCacheExpiredChecker` 与 `BuildCacheCollectExpiredVersions`。
  - `CleanExpired` 改为：expired versions helper -> `DeleteArtifacts` 循环。
  - 保持现有行为不变，包括当前仅通过 `DeleteArtifacts` 删除 source artifact 的语义。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_expiredscan.lpr` -> `Can't find unit fpdev.build.cache.expiredscan`
  - `test_build_cache_expiredscan 3/3`
  - `test_cache_ttl 9/9`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `202/202` passed

## 2026-03-07 build.cache binary presence helper 第一切片 (B252)

- Root cause:
  - `TBuildCache.HasArtifacts` 虽然逻辑很小，但仍直接承载 source archive / binary meta 的最终存在性判定，尚未与前几轮抽出的 binary meta path helper 配合收口。
- Decision:
  - 新增 `src/fpdev.build.cache.binarypresence.pas`。
  - 抽离 `BuildCacheHasArtifactFiles`。
  - `HasArtifacts` 改为：artifact key -> source path + binary meta path helper -> presence helper。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binarypresence.lpr` -> `Can't find unit fpdev.build.cache.binarypresence`
  - `test_build_cache_binarypresence 3/3`
  - `test_build_cache_binary 19/19`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `201/201` passed

## 2026-03-07 build.cache binary info helper 第一切片 (B251)

- Root cause:
  - `TBuildCache.GetBinaryArtifactInfo` 仍内嵌 binary meta path 拼装与 `TBinaryMetaArtifactInfo -> TArtifactInfo` 字段映射逻辑，wrapper 还有一段可纯化的数据搬运代码。
- Decision:
  - 新增 `src/fpdev.build.cache.binaryinfo.pas`。
  - 抽离 `BuildCacheGetBinaryMetaPath` 与 `BuildCacheCreateBinaryArtifactInfo`。
  - `GetBinaryArtifactInfo` 改为：artifact key -> meta path helper -> `BuildCacheLoadBinaryMeta` -> info mapping helper。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binaryinfo.lpr` -> `Can't find unit fpdev.build.cache.binaryinfo`
  - `test_build_cache_binaryinfo 10/10`
  - `test_build_cache_binary 19/19`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `200/200` passed

## 2026-03-07 build.cache binary restore helper 第一切片 (B250)

- Root cause:
  - `TBuildCache.RestoreBinaryArtifact` 仍内嵌默认扩展回退、`-binary` 归档路径拼装和 tar flags 选择逻辑，wrapper 还夹带了一段可纯化的恢复计划决策。
- Decision:
  - 新增 `src/fpdev.build.cache.binaryrestore.pas`。
  - 抽离 `TBuildCacheBinaryRestorePlan` 与 `BuildCacheBuildBinaryRestorePlan`。
  - `RestoreBinaryArtifact` 改为：metadata lookup -> restore plan helper -> verify -> extract command。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binaryrestore.lpr` -> `Can't find unit fpdev.build.cache.binaryrestore`
  - `test_build_cache_binaryrestore 10/10`
  - `test_build_cache_binary 19/19`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `199/199` passed

## 2026-03-07 build.cache binary save helper 第一切片 (B249)

- Root cause:
  - `TBuildCache.SaveBinaryArtifact` 仍内嵌二进制扩展名识别、`-binary` 路径拼装、归档大小读取和 SHA256 选择逻辑，wrapper 还承载了较多可抽离的弱状态步骤。
- Decision:
  - 新增 `src/fpdev.build.cache.binarysave.pas`。
  - 抽离 `BuildCacheResolveBinaryFileExt`、`BuildCacheBuildBinaryArtifactPaths`、`BuildCacheReadBinaryArchiveSize`、`BuildCacheResolveBinarySHA256`。
  - `SaveBinaryArtifact` 改为：校验输入 -> copy -> size/hash helper -> `BuildCacheSaveBinaryMeta`。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binarysave.lpr` -> `Can't find unit fpdev.build.cache.binarysave`
  - `test_build_cache_binarysave 8/8`
  - `test_build_cache_binary 19/19`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `198/198` passed

## 2026-03-06 build.cache rebuild collect helper 第一切片 (B248)

- Root cause:
  - `TBuildCache.RebuildIndex` 在完成 B037 扫描 helper 抽离后，仍保留 `versions -> LoadMetadataJSON -> UpdateIndexEntry` 中间的 metadata load 过滤循环，wrapper 还不够薄。
- Decision:
  - 扩展 `src/fpdev.build.cache.rebuildscan.pas`，新增 `TBuildCacheRebuildInfoLoader`、`TBuildCacheRebuildInfoArray`、`BuildCacheCollectRebuildInfos`。
  - `RebuildIndex` 改为：B065 状态重置 -> `BuildCacheListMetadataVersions` -> `BuildCacheCollectRebuildInfos` -> `UpdateIndexEntry`。
  - 保持 `FIndexEntries.Clear` + `FIndexLoaded := True` 在 wrapper 内，继续避免旧索引回灌。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_rebuildscan.lpr` -> `Identifier not found "BuildCacheCollectRebuildInfos"`
  - `test_build_cache_rebuildscan 10/10`
  - `test_cache_index 23/23`
  - `test_build_cache_indexstats 23/23`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `197/197` passed

## 2026-03-06 build.cache index stats summary helper 第一切片 (B247)

- Root cause:
  - `TBuildCache.GetIndexStatistics` 虽然已经有 `BuildCacheIndexStatsInit/Accumulate/Finalize`，但仍保留自己的 `FIndexEntries` 遍历与累计循环，尚未复用前一批抽出的 index collect helper。
- Decision:
  - 扩展 `src/fpdev.build.cache.indexstats.pas`，新增 `BuildCacheCalculateIndexStats`。
  - `GetIndexStatistics` 改为：`EnsureIndexLoaded` -> `BuildCacheCollectIndexInfos` -> `BuildCacheCalculateIndexStats`。
  - helper 接收 `ATotalEntries`，从而保持现有 `TotalEntries = FIndexEntries.Count` 语义，即使只有部分索引项成功解析。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_indexstats.lpr` -> `Identifier not found "BuildCacheCalculateIndexStats"`
  - `test_build_cache_indexstats 23/23`
  - `test_cache_index 23/23`
  - `test_cache_stats 22/22`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `197/197` passed

## 2026-03-06 build.cache index collect helper 第一切片 (B246)

- Root cause:
  - `TBuildCache.GetDetailedStats` 与 `TBuildCache.GetLeastRecentlyUsed` 都在重复执行 `FIndexEntries` -> `LookupIndexEntry` -> `TArtifactInfo[]` 的收集循环，读取职责和后续 helper 委托之间仍有重复样板代码。
- Decision:
  - 新增 `src/fpdev.build.cache.indexcollect.pas` 承载 `BuildCacheCollectIndexInfos`。
  - helper 使用 object callback 保持对 `LookupIndexEntry` 的现有调用方式不变，只过滤 lookup 失败项并保持索引顺序。
  - `GetDetailedStats` 与 `GetLeastRecentlyUsed` 改为 thin wrapper：`EnsureIndexLoaded` -> collect helper -> downstream helper。
- Verification:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_indexcollect.lpr` -> `Can't find unit fpdev.build.cache.indexcollect`
  - `test_build_cache_indexcollect 4/4`
  - `test_build_cache_detailedstats 12/12`
  - `test_build_cache_lru 3/3`
  - `test_cache_stats 22/22`
  - `test_cache_index 23/23`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `197/197` passed

## 2026-03-06 build.cache access helper 第一切片 (B245)

- Root cause:
  - `TBuildCache.RecordAccess` 仍内嵌“递增 `AccessCount` + 刷新 `LastAccessed`”的纯记录变换逻辑，和 lookup/persistence 职责混在一起。
- Decision:
  - 新增 `src/fpdev.build.cache.access.pas` 承载 `BuildCacheRecordAccessInfo`。
  - `RecordAccess` 改为：lookup -> access helper -> `UpdateIndexEntry` / `SaveMetadataJSON` / `SaveIndex`。
  - 新增 focused 测试锁定访问计数递增、时间戳刷新、metadata 保持不变、输入记录不被原地修改的契约。
- Verification:
  - `test_build_cache_access 15/15`
  - `test_cache_stats 22/22`
  - `test_cache_index 23/23`
  - `lazbuild -B fpdev.lpi` passed
  - `bash scripts/run_all_tests.sh` => `196/196` passed


## 2026-03-06 build.cache cleanup scan helper 第一切片 (B244)

- Root cause:
  - `CleanupLRU` 仍内嵌“扫描 `*.tar.gz` 并构造 `TArtifactInfo` 列表”逻辑，和 orchestration/删除职责没有完全分离。
- Decision:
  - 新增 `src/fpdev.build.cache.cleanupscan.pas` 承载 `BuildCacheCollectCleanupEntries`。
  - `CleanupLRU` 改为：扫描 helper -> victim helper -> 删除文件。
  - helper 通过 metadata loader 回调优先使用 metadata 的 `CreatedAt`，否则回退文件时间戳。
- Verification:
  - `test_build_cache_cleanupscan 6/6`
  - `test_cache_space 8/8`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 build.cache cleanup helper 第一切片 (B243)

- Root cause:
  - `CleanupLRU` 仍内嵌“按大小上限选出需要淘汰的受害者”算法，和文件扫描/删除职责混在一起。
- Decision:
  - 新增 `src/fpdev.build.cache.cleanup.pas` 承载 `BuildCacheSelectCleanupVictims`。
  - `CleanupLRU` 保留文件扫描与删除逻辑，只将受害者选择交给 helper。
  - helper 复用已抽出的 `BuildCacheSelectLeastRecentlyUsed`，因此清理受害者选择逻辑与 LRU 规则保持一致。
- Verification:
  - `test_build_cache_cleanup 4/4`
  - `test_cache_space 8/8`
  - `test_cache_stats 22/22`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 build.cache detailed stats helper 第一切片 (B242)

- Root cause:
  - `TBuildCache.GetDetailedStats` 仍内嵌基于 `TArtifactInfo` 的纯统计聚合逻辑，和索引读取职责混在一起。
- Decision:
  - 新增 `src/fpdev.build.cache.detailedstats.pas` 承载 `BuildCacheGetDetailedStatsCore`。
  - `TBuildCache.GetDetailedStats` 改为只收集 `TArtifactInfo` 数组，然后委托 helper 计算统计结果。
  - 新增 focused 测试锁定 total size/accesses、most/least accessed、average size 与 empty-input 契约。
- Verification:
  - `test_build_cache_detailedstats 12/12`
  - `test_cache_stats 22/22`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 build.cache LRU helper 第一切片 (B241)

- Root cause:
  - `TBuildCache.GetLeastRecentlyUsed` 仍内嵌 LRU 选择算法，虽然是纯计算逻辑，但和缓存对象的数据读取混在一起。
- Decision:
  - 新增 `src/fpdev.build.cache.lru.pas` 承载 `BuildCacheSelectLeastRecentlyUsed`。
  - `TBuildCache.GetLeastRecentlyUsed` 改为仅收集 `TArtifactInfo` 数组并委托 helper 进行 LRU 选择。
  - 新增 focused 测试锁定 never-accessed 优先、按 `CreatedAt` / `LastAccessed` 选择的契约。
- Verification:
  - `test_build_cache_lru 3/3`
  - `test_cache_stats 22/22`
  - `test_cache_space 8/8`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 resource.repo package query helper 第一切片 (B240)

- Root cause:
  - `fpdev.resource.repo.pas` 的 `GetPackageInfo` / `ListPackages` / `SearchPackages` 仍保留文件解析、目录扫描与搜索拼装逻辑，package query 簇尚未完成 helper 收口。
- Decision:
  - 扩展 `src/fpdev.resource.repo.package.pas`：
    - `ResourceRepoLoadPackageInfoFromFile`
    - `ResourceRepoListPackagesCore`
  - 扩展 `src/fpdev.resource.repo.search.pas`：
    - `TResourceRepoPackageInfoGetter`
    - `ResourceRepoSearchPackagesCore`
  - `src/fpdev.resource.repo.pas` 中 `GetPackageInfo` / `ListPackages` / `SearchPackages` 改为 thin wrapper。
  - 暂不动 `HasPackage`，因为它当前仍绑定 manifest 语义，直接替换会改变行为。
- Verification:
  - `test_resource_repo_query 8/8`
  - `test_resource_repo_package 6/6`
  - `test_resource_repo_search 11/11`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 resource.repo config helper 第一切片 (B239)

- Root cause:
  - `fpdev.resource.repo.pas` 仍保留顶层纯函数 `GetCurrentPlatform` / `CreateDefaultConfig` / `CreateConfigWithMirror`，这些逻辑与仓库对象主流程无关，适合作为低风险首切片。
- Decision:
  - 新增 `src/fpdev.resource.repo.config.pas` 承载：
    - `ResourceRepoGetCurrentPlatform`
    - `ResourceRepoCreateDefaultConfig`
    - `ResourceRepoCreateConfigWithMirror`
  - `src/fpdev.resource.repo.pas` 中对应导出函数改为 wrapper，行为保持不变。
  - 新增 focused 测试锁定平台标识、默认配置和镜像选择契约。
- Verification:
  - `test_resource_repo_config 12/12`
  - `test_resource_repo_package 6/6`
  - `test_resource_repo_search 11/11`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 package create helper 接线收口 (B238)

- Root cause:
  - `CreatePackage` 虽然已有 `GeneratePackageMetadataJsonCore` helper，但仍手写 `TJSONObject` 生成默认 `package.json`，形成重复实现。
- Decision:
  - 让 `CreatePackage` 通过 `GeneratePackageMetadataJson` 生成默认 metadata。
  - 扩展 `GeneratePackageMetadataJsonCore`，保持与原 `CreatePackage` 一致的默认字段：`homepage` / `repository` / `keywords`。
  - 保持 helper 输出紧凑 JSON，兼容现有 `test_package_properties` 的契约。
- Verification:
  - `test_package_create_metadata_helper 5/5`
  - `test_package_properties 157/157`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 package info helper 第一切片 (B237)

- Root cause:
  - `TPackageManager.ShowPackageInfo` 仍内嵌 info 文本组装逻辑，与包信息查询职责耦合。
- Decision:
  - 新增 `src/fpdev.cmd.package.infoview.pas` 承载 `BuildPackageInfoLinesCore`。
  - `TPackageManager.ShowPackageInfo` 保留查询与 `IOutput` 写出，文本行组装交给 helper。
  - 新增 focused 测试锁定 name/version/description 行，以及 installed 时才显示 install path 的契约。
- Verification:
  - `test_package_infoview 5/5`
  - `test_cli_package 222/222`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 package search helper 第一切片 (B236)

- Root cause:
  - `TPackageManager.SearchPackages` 仍内嵌大小写无关匹配、状态标签选择与文本行渲染逻辑，查询与展示职责耦合。
- Decision:
  - 新增 `src/fpdev.cmd.package.searchview.pas` 承载 `BuildPackageSearchLinesCore`。
  - `TPackageManager.SearchPackages` 保留包列表获取与 `IOutput` 写出，匹配与文本渲染交给 helper。
  - 新增 focused 测试锁定 name/description 匹配、installed/available 标签与 no-results 文本契约。
- Verification:
  - `test_package_searchview 3/3`
  - `test_cli_package 222/222`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 package update helper 第一切片 (B235)

- Root cause:
  - `UpdatePackage` 同时承担“查最新版本/判断是否需要升级”与“卸旧装新”两段职责，协调逻辑过重。
- Decision:
  - 新增 `src/fpdev.cmd.package.updateplan.pas` 承载 `BuildPackageUpdatePlanCore`。
  - `TPackageManager.UpdatePackage` 保留输出与卸载/安装流程，只复用 helper 决定 latest version 与 update-needed。
  - 顺手移除 `src/fpdev.cmd.package.pas` 中不再使用的 `fpdev.utils` 依赖，避免引入新 hint。
- Verification:
  - `test_package_updateplan 6/6`
  - `test_cli_package 222/222`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 package install flow helper 第一切片 (B234)

- Root cause:
  - `InstallPackage` 在完成下载后仍内嵌“解压缓存归档 → 调安装回调 → 按 KeepArtifacts 清理临时目录”的流程，和下载计划 orchestration 混在一起。
- Decision:
  - 新增 `src/fpdev.cmd.package.installflow.pas` 承载 `InstallPackageArchiveCore`。
  - `InstallPackage` 保留依赖解析与下载计划 orchestration，仅将 post-download 流程委托给 helper，并继续在 manager 层输出 cleanup warning。
  - 新增 focused 测试锁定 temp dir 命名、安装回调参数、cleanup 与 keep-artifacts 契约。
- Verification:
  - `test_package_install_flow_helper 9/9`
  - `test_cli_package 222/222`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 InstallPackage 复用 download helper (B233)

- Root cause:
  - `InstallPackage` 内仍保留与 `DownloadPackageCore` 基本相同的“选版本 + 组下载参数 + 调下载器”逻辑，重复路径未完全消除。
- Decision:
  - 将 `src/fpdev.cmd.package.fetch.pas` 升级为“下载计划构造器”，新增 `TPackageDownloadPlan` 与 `BuildPackageDownloadPlanCore`。
  - `DownloadPackageCore` 与 `InstallPackage` 共同复用该计划，保证版本选择、缓存路径和 fetch 选项完全一致。
  - 在 focused 测试中锁定计划构造契约，避免后续两条路径再次漂移。
- Verification:
  - `test_package_fetch 16/16`
  - `test_cli_package 222/222`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 package download helper 第一切片 (B232)

- Root cause:
  - `TPackageManager.DownloadPackage` 仍内嵌“选版本 + 组下载参数 + 调下载器”逻辑，与安装路径中的同类代码形成重复。
- Decision:
  - 新增 `src/fpdev.cmd.package.fetch.pas` 承载 `DownloadPackageCore`。
  - `TPackageManager.DownloadPackage` 保留为薄封装，传入 `GetAvailablePackages` 结果、`GetCacheDir` 和 `EnsureDownloadedCached`。
  - 新增 focused 测试锁定：默认选最高版本、缓存路径位于 `<cache>/packages`、SHA256/timeout/URL 列表透传，以及缺包/无 URL 时不触发下载器。
- Verification:
  - `test_package_fetch 10/10`
  - `test_cli_package 222/222`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 package available query helper 第一切片 (B231)

- Root cause:
  - `TPackageManager.GetAvailablePackages` 仍同时负责 repo 查询、分类项过滤、installed 标记和本地 index fallback，查询职责过重。
- Decision:
  - 新增 `src/fpdev.cmd.package.query.available.pas` 承载 `GetAvailablePackagesCore`。
  - `TPackageManager.GetAvailablePackages` 保留为薄封装，通过 repo/list/info、installed、index parser 回调注入现有依赖。
  - 新增 focused 测试锁定两条契约：repo 路径跳过分类项并保留 installed 标记；repo 为空时回退本地 index。
- Verification:
  - `test_package_available_query 9/9`
  - `test_cli_package 222/222`
  - `test_package_index_validation` passed
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 package installed query helper 第一切片 (B230)

- Root cause:
  - `TPackageManager.GetInstalledPackages` 仍内嵌目录扫描逻辑，与查询协调职责混在一起。
- Decision:
  - 新增 `src/fpdev.cmd.package.query.installed.pas` 承载 `GetInstalledPackagesCore`。
  - `TPackageManager.GetInstalledPackages` 保留为薄封装，传入 `@GetPackageInfo` 回调。
  - 新增 focused 测试锁定“仅扫描目录、忽略普通文件、通过回调解析包信息”契约。
- Verification:
  - `test_package_installed_query 5/5`
  - `test_cli_package 222/222`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 package metadata helper 第一切片 (B229)

- Root cause:
  - `TPackageManager.WritePackageMetadata` 仍内嵌 JSON 写入逻辑，与协调器职责混在一起。
- Decision:
  - 新增 `src/fpdev.cmd.package.metadata.pas` 承载 `WritePackageMetadataCore`。
  - `TPackageManager.WritePackageMetadata` 保留为薄封装，仅传递 `LastBuildTool/LastBuildLog`。
  - 新增 focused 测试锁定 package.json 字段持久化契约。
- Verification:
  - `test_package_metadata_writer 11/11`
  - `test_cli_package 222/222`
  - `test_package_search 24/24`
  - `lazbuild -B fpdev.lpi` passed


## 2026-03-06 package index helper 第一切片 (B228)

- Root cause:
  - `TPackageManager.ParseLocalPackageIndex` 仍内嵌在 `src/fpdev.cmd.package.pas`，属于纯解析逻辑，和协调器职责混在一起。
- Decision:
  - 新增 `src/fpdev.cmd.package.index.pas` 承载 `ParseLocalPackageIndexCore`。
  - `TPackageManager.ParseLocalPackageIndex` 保留为薄封装，CLI 行为不变。
  - 新增 focused 测试锁定索引解析契约：跳过无效条目、按包名去重、保留最高版本。
- Verification:
  - `test_package_index_parser 5/5`
  - `test_package_search 24/24`
  - `test_package_registry 35/35`
  - `lazbuild -B fpdev.lpi` passed

# 2026-03-15 Builder.DI GitOps 收口

## Requirements
- 移除 `src/fpdev.fpc.builder.di.pas` 内对 `FProcessRunner.Execute('git', ...)` 的直接调用。
- `builder.di` 的 git fallback 必须经由 `fpdev.utils.git.TGitOperations`，且 CLI 路径继续通过注入的 `IProcessRunner` 可观测。
- `TGitOperations` 需要支持 injectable CLI runner 和 `cli-only` 构造，但不破坏现有调用。
- `TFPCBuilder.UpdateSources` 只允许 fast-forward；`needs merge` / `detached` / `dirty` 等场景直接返回可行动错误。
- 定向验证至少包括 `tests/test_fpc_builder.lpr` 与 `tests/test_git_operations.lpr`，最终回归 `scripts/run_all_tests.sh`。

## Research Findings
- 本次任务已有明确实施方案，核心是把 builder 层的 CLI 逃逸收回到 `TGitOperations`，而不是替换 libgit2 主路径。
- `planning-with-files` 要求复杂任务使用落盘规划文件；仓库里已存在长期规划文件，因此本次以追加节的方式记录，避免覆盖旧任务。
- `session-catchup.py` 报告的未同步上下文与本任务无直接关系，但提醒需要显式记录当前任务，避免和旧长期自治计划混淆。
- `src/fpdev.utils.git.pas` 当前只有 `constructor Create;`，会先 `TryInitLibgit2`，失败后直接用 `TProcessExecutor.Run('git', ['--version'], '')` 选后端；`CommandLineGitAvailable` 与 `ExecuteGitCommand` 也都直接依赖 `TProcessExecutor`，没有 DI 注入口。
- `TGitOperations.Clone` 在 libgit2 成功 clone 后会复用自身 `Checkout(...)` 做 tag/branch 切换；CLI fallback 走 `git clone --depth 1 [--branch <branch>] ...`。
- `TGitOperations.Pull` 现在是“libgit2 fast-forward 优先，非 fast-forward/异常则 fallback 到 CLI `git pull`”；`PullWithLibgit2` 通过 `ANeedsFallback` 控制是否继续走 CLI。
- `src/fpdev.fpc.builder.di.pas` 的 `DownloadSource` 已经优先使用 `FGitManager.CloneRepository(...)` + `CheckoutRefWithLibgit2(...)`，但失败后仍直接 `FProcessRunner.Execute('git', ['clone', ...], '')`。
- `src/fpdev.fpc.builder.di.pas` 的 `UpdateSources` 会在 `IGitRepositoryExt.PullFastForward('origin', PullErr)` 返回 `gpffNeedsMerge/gpffDetachedHead/gpffDirty/gpffError` 后保留 `NeedsFallback := True`，最终直接执行 `FProcessRunner.Execute('git', ['pull'], SourceDir)`。
- `tests/test_fpc_builder.lpr` 现有断言覆盖了：
  - `DownloadSource - Prefers libgit2`：要求 `MockProcessRunner.GetExecutedCommands.Count = 0`。
  - `DownloadSource - Success`：当前只要求至少执行过某个 git 命令，不关心是否包含 `git --version`。
  - `UpdateSources - Prefers libgit2`：要求不触发 CLI。
  - 还没有覆盖 `gpffNeedsMerge/gpffDetachedHead/gpffDirty` 的 fast-forward-only 错误语义。
- `src/fpdev.fpc.mocks.pas` 中 `TMockProcessRunner` 只按 executable 名称返回结果，并会把完整命令行追加到 `GetExecutedCommands`；这足以观测新的 `git --version` + `git clone` CLI 链路。
- `TMockGitRepository.PullFastForward` 直接返回预设 `FPullResult/FPullError`，适合新增 diverged/dirty/detached 场景测试。

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| 不新建独立计划文件，直接在现有三份规划文件顶部追加本次任务记录 | 仓库已经把这三份文件当长期工作内存使用，追加更符合现状 |
| 先做 focused discovery，再进入 RED | 需要先确认 `builder.di` 与 `TGitOperations` 的现有分工和测试覆盖 |
| builder 侧不自行重新发明 git CLI wrapper，而是通过 `IGitCliRunner` 适配 `IProcessRunner` | 保持 CLI fallback 可测试、可观测，同时把 backend 选择逻辑留在 `TGitOperations` |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| 语义搜索优先命中了历史 planning 文档而不是目标源码 | 改为后续直接读取目标文件并做精确符号搜索 |
| RED 编译失败：`tests/test_git_operations.lpr` 引入的 `IGitCliRunner` / `TGitOperations.Create(..., True)` 尚不存在 | 这正是目标缺口，进入实现 |

## RED Verification
- `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_git_operations.lpr`
  - 失败，关键错误：`Identifier not found "IGitCliRunner"`。
- `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_fpc_builder.lpr && ./bin/test_fpc_builder`
  - 编译通过，运行失败。
  - `DownloadSource - CLI fallback uses injected runner` 失败，实际首条命令仍是直接 `git clone ...`，没有 `git --version` probe。
  - `UpdateSources - NeedsMerge/DetachedHead/Dirty` 都失败，实际仍执行了 1 次 CLI `git pull` fallback。

## Implementation Result
- `src/fpdev.utils.git.pas`
  - 新增 `IGitCliRunner`。
  - 新增 `TGitOperations.Create(const ACliRunner: IGitCliRunner; const ACliOnly: Boolean = False)`。
  - 新增默认 CLI runner，内部仍用 `TProcessExecutor.Execute('git', ...)`。
  - `CommandLineGitAvailable`、`ExecuteGitCommand`、`HasRemote`、`GetCurrentBranch`、`GetShortHeadHash`、`GetVersion`、`ListRemoteBranches` 的 CLI 分支统一走注入 runner。
  - `cli-only` 模式跳过 libgit2 初始化，只按 CLI 可用性设置 backend。
- `src/fpdev.fpc.builder.di.pas`
  - 新增 `TGitCliRunnerFromProcessRunner`，把注入的 `IProcessRunner` 适配到 `IGitCliRunner`。
  - `DownloadSource` 的 fallback 改为 `TGitOperations.Create(Adapter, True).Clone(...)`，不再直接 `Execute('git', ...)`。
  - `UpdateSources` 不再 CLI fallback；`gpffNeedsMerge` / `gpffDetachedHead` / `gpffDirty` 返回英文可行动错误，`gpffError`/init/open/unsupported 也直接返回错误。
- `tests/test_fpc_builder.lpr`
  - 新增 builder CLI fallback probe 断言。
  - 新增 `needs merge / detached head / dirty` 的 fast-forward-only 失败断言。
  - `UpdateSources - Success` 调整为 libgit2 fast-forward 成功路径。
- `tests/test_git_operations.lpr`
  - 新增 injected CLI runner / cli-only backend 的正反向测试。

## GREEN Verification
- `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_git_operations.lpr && ./bin/test_git_operations`
  - 通过，结果：`160 passed, 0 failed`。
- `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_fpc_builder.lpr && ./bin/test_fpc_builder`
  - 通过，结果：`59 passed, 0 failed`。
- `bash scripts/run_all_tests.sh`
  - 通过，结果：`256 passed, 0 failed, 0 skipped`。

## 2026-03-16 User-Facing FPC Update Flow

### Research Findings
- 用户态 `fpdev fpc update <version>` 不是走 `builder.di`；它的实际链路是：
  - `src/fpdev.cmd.fpc.update.pas` -> `TFPCManager.UpdateSources`
  - `src/fpdev.fpc.manager.pas` -> `ExecuteFPCUpdatePlanCore(...)`
  - `src/fpdev.fpc.runtimeflow.pas` -> `IFPCGitRuntime.Pull(APlan.SourceDir)`
  - `TFPCGitRuntimeAdapter.Pull` -> `TGitOperations.Pull`
- 这意味着我们昨天改成 fast-forward-only 的只是 `builder.di` 路径，不会自动影响用户态 `fpdev fpc update`。
- `ExecuteFPCUpdatePlanCore` 自身不理解 fast-forward/merge/detached/dirty，只把 `AGit.Pull(...)` 的布尔结果映射成：
  - success -> `CMD_FPC_UPDATE_DONE`
  - failure -> `CMD_FPC_GIT_PULL_FAILED` + `AGit.GetLastError`
  - no remote -> 输出 local-only 并返回 `True`
- `TGitOperations.Pull` 当前仍是“libgit2 fast-forward 优先，但 non-fast-forward 时允许 CLI fallback”的语义，因此用户态 update 仍可能进入 merge/rebase 路径。
- 现有测试覆盖：
  - `tests/test_fpc_runtimeflow.lpr` 只验证 `ExecuteFPCUpdatePlanCore` 的布尔 contract 和错误输出，不区分 fast-forward-only / merge fallback。
  - `tests/test_fpc_update.lpr` 只覆盖 missing dir、non-git dir、valid local repo(no remote)。
  - `tests/test_git_operations.lpr` 已覆盖 `Pull merge without CLI (libgit2)`，说明当前 `TGitOperations.Pull` 语义被测试锁定为允许 merge 路径。

### Technical Decision
| Decision | Rationale |
|----------|-----------|
| 在改用户态 update 语义前，先把 `TGitOperations.Pull` 现有 contract 和 `test_git_operations` 的 merge test 视为需要显式审视的兼容面 | 这不是 builder 层内部行为，而是更广的 runtime contract，不能直接按昨天的 builder 语义外推 |
| 本轮不修改 `TFPCManager.UpdateSources` / `TGitOperations.Pull` 的行为，只同步过时文档 | 现有 merge-success 语义已经被 `tests/test_git_operations.lpr` 锁定；静默改成 fast-forward-only 会是新的产品行为，不适合在“继续清理”里顺手做 |

### Documentation Sync
- 已更新：
  - `docs/FPC_MANAGEMENT.md`
  - `docs/FPC_MANAGEMENT.en.md`
  - `docs/FAQ.md`
  - `docs/FAQ.en.md`
- 同步内容：
  - 去掉中文文档里 `fpc update/clean` 的“规划中”表述。
  - 把 FAQ 中“就是 `git pull`”改成更准确的“通过 FPDev 的 Git runtime 更新”。
  - 补充 local-only 仓库无 remote 时会报告 local-only 并成功退出。

## Resources
- `task_plan.md`
- `findings.md`
- `progress.md`
- `/home/dtamade/.codex/skills/superpowers/skills/executing-plans/SKILL.md`
- `/home/dtamade/.codex/skills/superpowers/skills/test-driven-development/SKILL.md`
- `/home/dtamade/.codex/skills/superpowers/skills/verification-before-completion/SKILL.md`
- `/home/dtamade/.codex/skills/planning-with-files/SKILL.md`

# Findings & Decisions

## 2026-03-06 install-local 自包含发布路径修复 (B227)

- Root cause:
  - `InstallPackageFromSource` 仅记录 `source_path`，未复制源码到安装目录；`publish` 会优先依赖 metadata 的 `source_path`，导致原始目录删除后发布失败。
- Decision:
  - 在安装阶段递归复制源码到安装目录，保障后续发布有本地稳定输入。
  - 增加 source/install 同路径保护，避免自复制导致递归问题。
  - 安装 metadata 写空 `source_path`，让 `publish` 统一回退安装目录，消除对原始路径依赖。
  - 增加 CLI 回归覆盖“install-local 后删除原目录仍能 publish”契约。
- Verification:
  - `test_cli_package 222/222`
  - `run_all_tests 177/177`

## 2026-03-06 publish 非法 metadata JSON 契约锁定 (B226)

- Root cause:
  - B225 已修复读取异常崩溃，但“metadata 非法 JSON”分支若无回归测试，后续很容易被误改为 `EXIT_IO_ERROR` 或回退崩溃行为。
- Decision:
  - 新增 CLI 回归，显式锁定该场景应返回 `EXIT_ERROR`（数据错误，不是 I/O 故障）。
  - 同时断言 stderr 含 `CMD_PKG_META_INVALID` 语义，确保用户可定位问题。
- Verification:
  - `test_cli_package 218/218`
  - `run_all_tests 177/177`

## 2026-03-06 publish metadata 读取异常收口 (B225)

- Root cause:
  - `package publish` 预检会先读取已安装包 metadata；当 `package.json` 不可读时，异常在 manager 层直接抛出，导致命令崩溃而非返回可预期退出码。
- Decision:
  - 在 `GetPackageInfo` 增加 metadata 读取容错，避免预检阶段异常穿透。
  - 在 `PublishPackage` 明确 metadata 失败语义：
    - 文件读取失败（权限/IO）-> `EXIT_IO_ERROR`
    - JSON 非法或结构非对象 -> `EXIT_ERROR`
  - 新增 CLI 回归锁定“metadata 不可读 -> EXIT_IO_ERROR”契约。
- Verification:
  - `test_cli_package 215/215`
  - `run_all_tests 177/177`

## 2026-03-06 publish 相对 source_path 解析修复 (B224)

- Root cause:
  - `PublishPackage` 直接按进程工作目录校验 metadata 的 `source_path`，当配置为相对路径时会误判不存在。
- Decision:
  - `source_path` 保留绝对路径原行为。
  - 相对路径统一按包安装目录解析后再校验与归档，避免依赖调用方当前工作目录。
  - 增加 CLI 回归锁定契约：相对 `source_path` 场景应可成功发布并生成归档。
- Verification:
  - `test_cli_package 211/211`
  - `run_all_tests 177/177`

## 2026-03-06 publish 归档 I/O 失败退出码收口 (B223)

- Root cause:
  - B222 后 `package publish` 已能区分 NOT_FOUND，但归档器执行类失败（`tar` 不可用/归档未生成）仍落到 `EXIT_ERROR`，无法区分业务校验失败与系统 I/O 故障。
- Decision:
  - 在 `PublishPackage` 按归档器错误码细分：
    - `paecTarCommandFailed` / `paecArchiveNotCreated` / `paecTarExecutionFailed` -> `EXIT_IO_ERROR`
    - `paecNoSourceFiles` 继续 `EXIT_ERROR`（输入内容问题）。
  - 新增 CLI 回归覆盖“`tar` 不可用”场景，使用临时 `PATH` 注入触发稳定失败并断言 `EXIT_IO_ERROR`。
- Verification:
  - `test_cli_package 208/208`
  - `run_all_tests 177/177`

## 2026-03-05 publish 退出码细分收口 (B222)

- Root cause:
  - `TPackagePublishCmd.Execute` 在 `LMgr.PublishPackage` 失败时统一返回 `EXIT_ERROR`，丢失“资源不存在（NOT_FOUND）”语义。
- Decision:
  - 在 `TPackageManager` 增加 publish 专用最近退出码状态（`FLastPublishExitCode` + getter）。
  - `PublishPackage` 按失败原因写入退出码（包/metadata/source_path 缺失 -> `EXIT_NOT_FOUND`）。
  - 命令层失败时返回 manager 提供的退出码，保留原有 stdout/stderr 行为。
  - CLI 回归将 invalid source_path 场景调整为 `EXIT_NOT_FOUND`；empty source files 继续 `EXIT_ERROR`。
- Verification:
  - `test_cli_package 204/204`
  - `run_all_tests 177/177`

## 2026-03-05 publish 归档错误码契约收口 (B221)

- Root cause:
  - `PublishPackage` 通过比较 `Archiver.GetLastError` 英文文本判断“无源码文件”，对文案改动高度敏感，维护成本高。
- Decision:
  - 在 `TPackageArchiver` 暴露结构化错误码 `TPackageArchiverErrorCode` 与 `GetLastErrorCode`。
  - `PublishPackage` 按错误码分支（`paecNoSourceFiles`）处理业务语义，保留原错误文本仅用于展示。
  - 增加归档器单测锁定“空源码目录 -> paecNoSourceFiles”契约。
- Verification:
  - `test_package_archiver 18/18`
  - `test_cli_package 204/204`
  - `run_all_tests 177/177`

## 2026-03-05 publish 源路径失败语义收口 (B220)

- Root cause:
  - `PublishPackage` 对 metadata 的 `source_path` 仅“存在即优先，缺失即静默回退到安装目录”，当路径失效时会掩盖配置错误。
  - 归档器 “No source files found to archive” 直接透传到上层，缺少 publish 语境信息（哪个源目录为空）。
- Decision:
  - 若 metadata 提供了 `source_path` 且目录不存在，发布流程直接失败，不再回退安装目录。
  - 对 “无源码可归档” 错误做上层语义映射，输出 i18n 的 publish 专用错误（携带源目录）。
  - 增加两个 CLI 回归（invalid source_path / empty source files）+ i18n key 断言，固定行为契约。
- Verification:
  - `test_cli_package 204/204`
  - `run_all_tests 177/177`

## 2026-03-05 install-local -> publish 元数据连续性修复 (B219)

- Root cause:
  - `InstallPackageFromSource` 写回安装 metadata 时未优先继承源 `package.json` 关键字段，导致 version/description 可能空值漂移。
  - `PublishPackage` 读取 metadata 时未处理“version 字段存在但为空”的情况，可能生成异常归档名；且始终从安装目录归档，无法覆盖 install-local 的“源代码在 source_path”场景。
- Decision:
  - 在安装阶段优先合并源 metadata（name/version/description 等）再写回安装 metadata。
  - 发布阶段对空 version 做默认值回退。
  - 发布阶段优先使用有效 `source_path` 作为归档源，兼容 install-local 流程。
  - 增加 CLI 端到端回归 `install-local -> publish`，并补 metadata 字段保留断言。
- Verification:
  - `test_cli_package 196/196`
  - `run_all_tests 177/177`

## 2026-03-05 install-local 元数据名称对齐修复 (B218)

- Root cause: `InstallFromLocal` 仅使用目录名作为安装包名；当目录名与 `package.json.name` 不一致时，会把包安装到错误路径，导致后续 `publish <name>` 容易找不到目标目录。
- Decision:
  - 保持目录名作为默认回退，兼容现有行为。
  - 若本地目录存在 `package.json` 且 `name` 非空，则优先使用 metadata 名称作为安装包名。
  - metadata 解析异常时不抛错，回退目录名路径，避免额外破坏。
  - 增加 CLI 回归测试覆盖“目录名与 metadata.name 不一致”场景。
- Verification:
  - `test_cli_package 190/190`
  - `run_all_tests 177/177`

## 2026-03-05 install-local 成功路径返回值修复 (B217)

- Root cause: `src/fpdev.cmd.package.pas` 的 `InstallPackageFromSource` 在 `WritePackageMetadata` 分支中缺少失败分支退出，导致“写入成功仍返回 False、写入失败反而返回 True”的语义反转。
- Decision:
  - 修正控制流：`WritePackageMetadata` 失败立即 `Exit`，成功后统一 `Result := True`。
  - 移除无意义的占位赋值（`Info.Version := Info.Version` / `Info.Description := Info.Description`）。
  - 在 `test_cli_package` 增加 `install-local` 成功路径回归，覆盖此前未测试到的分支。
- Verification:
  - `test_cli_package 187/187`
  - `run_all_tests 177/177`

## 2026-03-05 package.publish/package.validate 功能类运行态文案收口 (B216 Step 3)

- Root cause: `src/fpdev.cmd.package.publish.pas` 与 `src/fpdev.cmd.package.validate.pas` 在执行路径仍有 `FLastError` / `AddMessage` 硬编码文本，导致 `package` 子命令运行态 i18n 契约存在尾差。
- Decision:
  - 新增并接入 `CMD_PKG_PUBLISH_*` 与 `CMD_PKG_VALIDATE_*` 文案键，统一替换运行态用户可见文本。
  - `publish` 仅替换错误文案来源，不改业务路径与错误分支。
  - `validate` 保持原有 `Error/Warning/Info` 分级机制，仅迁移消息文本与前缀到 i18n。
  - 在 `test_cli_package` 增加 key-level 断言，防止未来回退为硬编码。
- Verification:
  - `test_package_publish 26/26`
  - `test_package_validate 22/22`
  - `test_cli_package 185/185`
  - `run_all_tests 177/177`

## 2026-03-05 package.search 功能类运行态文案收口 (B216 Step 2)

- Root cause: `src/fpdev.cmd.package.search.pas` 中 `GetInfo`/`FormatPackageInfo` 仍有运行态硬编码标签与错误文案，导致 `package` 子命令相关功能类 i18n 契约不完整。
- Decision:
  - 新增 `CMD_PKG_SEARCH_INFO_*` 与 `CMD_PKG_SEARCH_*_FAILED` 文案键。
  - `FormatPackageInfo` 与 `FLastError` 相关文本统一改为 `_(...)` / `_Fmt(...)`。
  - 复用现有 `CMD_PKG_NOT_FOUND`，避免重复定义“包不存在”语义。
  - 在 `test_cli_package` 增加轻量键值断言防回退。
- Verification:
  - `test_package_search 24/24`
  - `test_cli_package 180/180`
  - `test_command_registry 162/162`
  - `run_all_tests 177/177`

## 2026-03-05 package.test 运行态文案收口 (B216 Step 1)

- Root cause: `src/fpdev.cmd.package.test.pas` 作为 package 相关运行模块，仍有一组非 help 硬编码用户可见文本（`[INFO]` 输出 + `FLastError` 英文文案），与近期 `package` 系列 i18n 契约不一致。
- Decision:
  - 新增 `CMD_PKG_TEST_*` 文案键覆盖 metadata/archive/dependency/script/cleanup 场景。
  - `TPackageTestCommand` 中相关输出/错误统一改为 `_(...)` / `_Fmt(...)`。
  - 在 `test_cli_package` 补轻量键值断言，防止回退。
- Verification:
  - `test_package_test 16/16`
  - `test_cli_package 177/177`
  - `test_command_registry 162/162`
  - `run_all_tests` 二次复跑稳定 `177/177`（首次出现 `test_cache_index` 单点波动，单测复跑通过）

## 2026-03-05 package 核心流程运行态文案收口 (B215)

- Root cause: `src/fpdev.cmd.package.pas` 中仍有少量核心流程输出硬编码（依赖解析/安装进度与归档 SHA256 显示），与前序 i18n 收口策略不一致。
- Decision:
  - 统一新增 `MSG_PKG_DEP_*` 与 `MSG_PKG_ARCHIVE_SHA256` 文案键。
  - 将 `ResolveAndInstallDependencies` / `InstallPackage` / `CreatePackageArchive` 的用户输出迁移到 i18n。
  - 在 `test_cli_package` 添加轻量 i18n 键回归断言，避免回退为硬编码。
- Verification: `test_cli_package 173/173`, `test_command_registry 162/162`, `run_all_tests 177/177`。

## 2026-03-05 package list(--all) 运行态文案收口 (B214)

- Root cause: `package list` 的 help 已 i18n，但 `ListPackages` 执行态仍存在 `Available/Empty` 等硬编码输出，导致契约收口不完整。
- Decision:
  - 新增 `CMD_PKG_LIST_AVAILABLE_HEADER`、`CMD_PKG_LIST_AVAILABLE_EMPTY`。
  - `ListPackages` 的 installed/available header 与 empty 文案统一走 i18n。
  - 在 `test_cli_package` 增加 `list` 运行态 header 断言（`no args` + `--all`）。
- Verification: `test_cli_package 167/167`, `test_command_registry 162/162`, `run_all_tests 177/177`。

## 2026-03-05 package 运行态 i18n 收口完成 (B213)

- Root cause: `package` 族在 help/options 基本收口后，仍有执行态硬编码残留（`deps/why` 示例树文本、`search` 状态词与无结果提示），导致用户可见契约不一致。
- Decision:
  - `deps/why`：新增并使用 `CMD_PKG_DEPS_CURRENT_PROJECT`、`CMD_PKG_WHY_TREE_NODE`、`CMD_PKG_WHY_TREE_LEAF`。
  - `search`：将 `Installed/Available` 与无结果提示迁入 i18n（`CMD_PKG_SEARCH_STATUS_*` + `CMD_PKG_SEARCH_NO_RESULTS`）。
  - 测试：在 `test_cli_package` 增加 `why` 树节点断言与 `TestSearchNoResultsOutput` 回归。
- Verification: `test_cli_package 164/164`, `test_command_registry 162/162`, `run_all_tests 177/177`。

## 2026-03-05 package install 运行态提示 i18n 收口 (B213 Step 1)

- Root cause: `package install` 的 dry-run/no-deps 用户提示仍为硬编码英文，与 `package` 族 i18n 收口目标不一致。
- Decision: 新增 `CMD_PKG_INSTALL_DRYRUN_*` 和 `CMD_PKG_INSTALL_NODEPS_WARN*` 文案键，安装命令运行态输出统一走 i18n；并新增 dry-run 输出回归断言。
- Verification: `test_cli_package 160/160`, `test_command_registry 162/162`, `run_all_tests 177/177`。

## 2026-03-05 package help/options 尾差 i18n 收口 (B212)

- Root cause: `package install/list/search` 的少量 help options 文案仍是硬编码英文，和近期 i18n 契约收口目标不一致。
- Decision: 新增 `HELP_PACKAGE_INSTALL_OPT_NODEPS`、`HELP_PACKAGE_INSTALL_OPT_DRYRUN`、`HELP_PACKAGE_LIST_OPT_JSON`、`HELP_PACKAGE_SEARCH_OPT_JSON`，命令实现统一引用 i18n。
- Verification: `test_cli_package 156/156`, `test_command_registry 162/162`, `run_all_tests 177/177`。

## 2026-03-05 package 子命令未知选项契约收口 (B211)

- Root cause: 多个 `package` 子命令只校验“多余位置参数”，对未知 `--option` 默认放行，导致 CLI 契约不一致。
- Decision:
  - 在 `fpdev.cmd.utils.pas` 增加通用选项校验工具：`IsKnownOption`、`FindUnknownOption`。
  - 为 `package` 主线子命令与 `package repo` 子命令接入白名单校验，未知选项统一 `EXIT_USAGE_ERROR`。
- RED evidence: `test_cli_package` 新增 unknown-option 测试后初次运行失败 `12` 项。
- Verification: 修复后 `test_cli_package 156/156`, `test_command_registry 162/162`, `run_all_tests 177/177`。

## 2026-03-05 package deps/why 运行态输出 i18n 收口

- Root cause: `deps/why` 的 help/usage 已切入 i18n，但执行态输出（header/path/summary/constraint）仍是硬编码英文，存在契约分裂。
- Decision: 新增 `CMD_PKG_DEPS_*` 与 `CMD_PKG_WHY_*` 运行态文案键；命令实现统一使用 `_(...)` / `_Fmt(...)` 输出。
- Test decision: 在 `test_cli_package` 新增运行态断言（`TestDepsWithPackageName`、`TestWhyPackageOutput`），防止回退为硬编码。
- Verification: `test_cli_package 143/143`, `test_command_registry 162/162`, `run_all_tests 177/177`。

## 2026-03-05 package deps/why 内部 help 文案 i18n 收口

- Root cause: `src/fpdev.cmd.package.deps.pas` 与 `src/fpdev.cmd.package.why.pas` 内 `Show*Help` 的 `Options/Examples` 仍存在硬编码。
- Decision: 将 `deps/why` 内部 help 的 `Options/Examples` 迁移到 `HELP_PACKAGE_DEPS_*` / `HELP_PACKAGE_WHY_*` 常量，并统一 usage 错误输出。
- Verification: `test_cli_package 143/143`, `test_command_registry 162/162`, `run_all_tests 177/177`。

## 2026-03-05 package help deps/why i18n 收口

- Root cause: `src/fpdev.cmd.package.help.pas` 中 `deps/why` 文案是硬编码英文，绕过 i18n 体系，导致多语言契约不一致。
- Decision: 为 `deps/why` 增加 `HELP_PACKAGE_DEPS_*`、`HELP_PACKAGE_WHY_*` i18n 常量，并让 `package help`/`package help deps|why` 全部引用这些常量。
- Verification: `test_cli_package 134/134`, `test_command_registry 162/162`, `run_all_tests 177/177`。

## 2026-03-05 package deps/why 参数契约收口

- Root cause: `package deps/why` 对未知 flag 缺少校验，CLI 会静默接受错误输入，导致行为不可预测。
- Decision: 对这两个命令使用显式“允许参数白名单”；未知选项直接 `EXIT_USAGE_ERROR`。
- Additional rule: `package deps --depth=<N>` 仅接受非负整数；非法值直接 usage error。
- Verification: `test_cli_package 132/132`, `test_command_registry 158/158`, `run_all_tests 177/177`。

## 2026-03-05 Package CLI Contract Closure

- Decision: treat `fpdev package create` as **non-public / unregistered CLI command** in current product contract.
- Why: runtime registry/help/completion no longer expose `create`; stale docs/i18n references were causing planning and user-perception drift.
- Closure actions:
  - Removed stale i18n keys/messages that advertised `package create`.
  - Added registry contract assertion: `package create` must not be registered.
  - Synchronized `ROADMAP`, `CHANGELOG`, and package-creation design docs with explicit 2026-03-05 status.
  - Updated `task_plan.md` Phase 5 status table (B176-B205) to completed and added B206 closure record.
- Verification:
  - `test_command_registry`: 158/158 pass
  - `test_cli_package`: 129/129 pass
  - `run_all_tests.sh`: 177/177 pass

## 2026-02-13 CLI Smoke / Acceptance Gaps

- Root cause: `TCommandRegistry.DispatchPath` rewrote `--help/-h` into positional `help`, breaking leaf commands (e.g. `shell-hook`, `fpc test`, `cross test`, `lazarus run`).
- Fix: only rewrite a trailing help flag when an actual `<prefix> help` command exists; otherwise keep args unchanged so leaf commands can handle `--help` directly.
- Fix: `cross build --dry-run` should be side-effect free and not fail when sources/toolchains are absent.
- Fix: `resolve-version --help` now prints usage (previously printed a version).
- Fix: `fpdev --self-test` implemented (toolchain report + exit code 2 on FAIL).

## 2026-02-13 Real Completion / Acceptance (P0 Blockers)

- `fpdev fpc test` in a clean config (no default toolchain) is now smoke-friendly:
  - Behavior: falls back to validating the system `fpc` in `PATH` (`Testing system FPC...`), exits `0` on success.
  - Rationale: makes `fpdev` CLI usable for first-run smoke; explicit versions still test fpdev-managed toolchains.
- `fpdev project build` could hang when invoking `lazbuild` via `TProcessExecutor.Execute` (pipes + verbose output can deadlock).
  - Fix: `TProjectManager.BuildProject` uses `TProcessExecutor.RunDirect` for `lazbuild/fpc/make` so output streams without pipe buffering deadlocks.
- Offline/deterministic test runs:
  - `TFPCInstallCommand` short-circuits network installs when `FPDEV_SKIP_NETWORK_TESTS=1`, returning `EXIT_IO_ERROR` with a hint.
  - Keeps `scripts/run_all_tests.sh` stable (default `FPDEV_SKIP_NETWORK_TESTS=1`).
- Host toolchain reality (external):
  - `scripts/check_toolchain.sh` now exits `0` when required tools are present and reports cross-only tools as optional by default (use `--strict` / `FPDEV_TOOLCHAIN_STRICT=1` to enforce).
  - Cross-compilation *execution* still depends on external prerequisites (target toolchains + populated FPC sources), but:
    - `fpdev cross list` no longer triggers network manifest loads (no first-run hangs/timeouts).
    - `fpdev cross build` now fails fast with actionable errors when the source tree is missing/incomplete.
    - Build system failures no longer crash the process when `make` is missing (BuildManager catches `EOSError` and sets `GetLastError`).

## Phase 4 自治运行策略 (2026-02-07)

### 目标
- 将“问题修复”从一次性任务转为可连续执行的批次流水线。
- 保持低上下文损耗：每批有输入、有输出、有验收、有下一批。

### 批次定义
| 项目 | 约束 |
|------|------|
| 批次时长 | 60-120 分钟 |
| WIP | 1（同一时间仅 1 个批次 in_progress） |
| 交付物 | 修改文件、验证命令、风险、下一批建议 |
| 里程碑汇报 | 每 5 批或每日一次 |

### 停机闸门（需要人工确认）
- 破坏性操作（删除大范围文件、reset 历史）
- 外部依赖重大变更（工具链版本/新网络依赖）
- 架构级重构（跨多个核心模块）

### 批次优先级策略
1. 先修“可证明安全”的 warning（行为不变）
2. 再做高收益迁移（@deprecated / SHA256）
3. 最后做低风险整理（unused 参数、文档补齐）

### 里程碑度量
| 指标 | 说明 |
|------|------|
| Warning 总量 | 趋势持续下降 |
| Hint 总量 | 不反弹 |
| 测试通过率 | 维持 100%（或明确说明失败原因） |
| 每批吞吐 | 每日 >= 1 批 |

## B001 基线冻结结果 (2026-02-07)

### 验证命令
- `lazbuild -B fpdev.lpi 2>&1 | tee /tmp/fpdev_b001_build.log | rg -n "(Warning|Hint|Error)"`
- `bash scripts/run_all_tests.sh`

### 基线值
| Metric | Value |
|--------|-------|
| Warnings (src) | 19 |
| Hints (src) | 28 |
| Hints (all lines) | 40 |
| Errors (src) | 0 |
| Tests | 94/94 passed |

### 说明
- `Hints (all lines)` 包含 Lazarus/FPC 工具链配置提示。
- 项目治理使用 `src` 范围指标作为后续批次对比基线。

## B002 Warning 分批清单（草案）

### 分批原则
- 先低耦合、后高耦合
- 每批只覆盖一种主要 warning 类型
- 每批完成后必须回归测试

### Warning 池拆分
| Batch | 目标 | 预估 warning 降幅 | 风险 |
|------|------|-------------------|------|
| B003 | `fpdev.source.repo.pas` + `fpdev.git2.pas` 的 GitManager 迁移（低风险调用点优先） | 4-8 | 中 |
| B004 | 剩余 GitManager 迁移 + `fpdev.fpc.source.pas` deprecated 替换 | 4-6 | 中高 |
| B005 | `fpdev.fpc.installer.pas` / `fpdev.cmd.fpc.pas` deprecated API 替换 | 4 | 中 |
| B006 | `fpdev.cross.downloader.pas` 的 `TBaseJSONReader.Create` 迁移 | 1 | 低 |

### B002 交付标准
- 给出每批涉及文件、预期替换点与回归命令
- 标注需要人工确认的高风险替换点

## B003 命令占位实现清零结果 (2026-02-07)

### 已清零项
- `src/fpdev.fpc.installer.pas`：`TFPCInstaller.InstallVersion` 移除 binary mode 的“not implemented”硬失败，统一回退到可执行路径。
- `src/fpdev.package.resolver.pas`：`GenerateLockFile` 移除 `sha256-placeholder`，改为真实 SHA256（文件哈希，失败时回退流哈希）。
- `src/fpdev.cmd.lazarus.pas`：`InstallVersion` 的 binary 分支不再直接失败，改为可运行的 source fallback。
- `src/fpdev.lpr`：补齐 `fpdev.cmd.fpc.verify`、`fpdev.cmd.fpc.autoinstall` 单元引入，确保命令注册生效。
- `src/fpdev.cmd.fpc.autoinstall.pas`：实现标准 `ICommand` 方法（`Name/Aliases/FindSub`）和 `--help`。
- `src/fpdev.cmd.fpc.verify.pas`：补充 `--help` 处理，避免将 `--help` 误当版本参数。

### 命令可达性巡检
| 项目 | 结果 |
|------|------|
| 注册命令总数 | 77 |
| `Unknown command` 失败数 | 0（按命令语义执行 help/--help） |

### 测试验证
- 定向测试：`tests/test_fpc_installer.lpr` PASS
- 定向测试：`tests/test_package_resolver_integration.lpr` PASS
- 全量测试：`scripts/run_all_tests.sh` PASS（94/94）

## B004 GitManager 弃用迁移（低耦合）结果 (2026-02-07)

### 变更
- `src/fpdev.source.repo.pas`：将 `GitManager` 全局弃用调用迁移到 `IGitManager/NewGitManager`。
- `src/fpdev.git2.pas`：`TGit2Manager` 内部不再调用弃用 `GitManager` 函数，改为持有 `TGitManager` 实例。

### 编译/测试结果
| Metric | Before | After |
|--------|--------|-------|
| Warnings (src) | 19 | 7 |
| Tests | 94/94 | 94/94 |

### 剩余 warning（下一批）
- `fpdev.fpc.source.pas`（2）
- `fpdev.cross.downloader.pas`（1）
- `fpdev.fpc.installer.pas`（2）
- `fpdev.cmd.fpc.pas`（2）

## B005 deprecated API 迁移结果 (2026-02-08)

### 变更
- `src/fpdev.fpc.source.pas`：补齐非弃用内部 helper 路径，避免内部再次调用弃用接口。
- `src/fpdev.fpc.installer.pas` / `src/fpdev.cmd.fpc.pas`：迁移到非弃用调用路径并保持行为兼容。
- `src/fpdev.cross.downloader.pas`：迁移 `TBaseJSONReader.Create` 的弃用构造调用。

### 编译/测试结果
| Metric | Before | After |
|--------|--------|-------|
| Warnings (src) | 7 | 0 |
| Warnings (all) | >0 | 0 |
| Hints (src) | 28 | 28 |
| Tests | 94/94 | 94/94 |

### 验证命令
- `lazbuild -B fpdev.lpi`（日志：`/tmp/fpdev_b005_build.log`）
- `grep -c "Warning:" /tmp/fpdev_b005_build.log` => `0`
- `bash scripts/run_all_tests.sh`（日志：`/tmp/fpdev_b005_tests.log`）

## B006 回归验证结果 (2026-02-08)

### 结果
- `bash scripts/run_all_tests.sh`：`Total=94, Passed=94, Failed=0`
- B003-B005 变更链路无回归，当前可进入 B007（Hint 清理）。

## B007 Hint 清理结果 (2026-02-08)

### 变更策略
- 仅做低风险、无行为变化改动：清理 `unused unit` 与参数 no-op 标记。
- 不改命令流程、不改业务分支，仅降低编译噪音，便于后续批次聚焦真实问题。

### 编译/测试结果
| Metric | Before | After |
|--------|--------|-------|
| Warnings (src) | 0 | 0 |
| Hints (src) | 28 | 2 |
| Hints (all) | 40 | 14 |
| Tests | 94/94 | 94/94 |

### 剩余 Hint（B007时点，已在 B011 收敛）
- `src/fpdev.utils.fs.pas`：`StatBuf` 初始化提示（5057，可能是编译器路径分析限制）
- `src/fpdev.lpr`：`fpdev.cmd.lazarus` 仅用于初始化注册，触发未使用单元提示（5023）


## B009 大文件拆分预研结果 (2026-02-08)

### 大文件热区（按行数）
| File | LOC | Functions/Procedures |
|------|-----|----------------------|
| `src/fpdev.cmd.package.pas` | 2497 | 58 |
| `src/fpdev.resource.repo.pas` | 1996 | 42 |
| `src/fpdev.build.cache.pas` | 1955 | 62 |
| `src/fpdev.config.managers.pas` | 1345 | 60 |
| `src/fpdev.fpc.installer.pas` | 1320 | 17 |

### 最小切片方案（先低风险再重构）
- `src/fpdev.cmd.package.pas`：优先按现有区段拆分（semantic/deps/verify/create/validate）为独立单元，先做 helper 提取，不动命令入口。
- `src/fpdev.resource.repo.pas`：按 mirror/cross/package 三块服务化拆分，保留 Facade 兼容层。
- `src/fpdev.build.cache.pas`：按 artifact/binary/index/stats 四块下沉到子模块，先抽纯函数与序列化逻辑。

### 风险评估
- 主要风险：初始化顺序、循环依赖、接口可见性变化。
- 控制策略：每次只切 1 个区段 + 全量回归。

## B010 里程碑报告 (2026-02-08)

### 里程碑区间
- 覆盖批次：`B001` → `B010`
- 目标达成：Phase 4 自治流水线稳定运行，warning/hint 债务基本收敛。

### 指标结果
| Metric | B001 Baseline | Current |
|--------|----------------|---------|
| Warnings (src) | 19 | 0 |
| Hints (src) | 28 | 0 |
| Hints (all) | 40 | 12 |
| Tests | 94/94 | 94/94 |

### 结论
- 编译面已从“问题修复”切换到“结构优化”阶段。
- 下一阶段优先级：大文件可维护性（B012+）。

## B011 剩余 Hint 收敛结果 (2026-02-08)

### 修复项
- `src/fpdev.utils.fs.pas`：将 `StatBuf` 初始化移到 `FpStat` 调用前（`Default(TStat)`），消除局部变量初始化提示。
- `src/fpdev.lpr`：移除未实际使用的 `fpdev.cmd.lazarus` uses 项，保留 `fpdev.cmd.lazarus.root` 与各子命令注册单元。

### 验证结果
- `lazbuild -B fpdev.lpi`（日志：`/tmp/fpdev_b011_build.log`）
  - `Warnings(all)=0`
  - `Hints(all)=12`（仅工具链配置提示）
  - `Warnings/Hints(src)=0`
- `bash scripts/run_all_tests.sh`（日志：`/tmp/fpdev_b011_tests.log`）
  - `Total=94, Passed=94, Failed=0`

## B012 新任务池扫描结果 (2026-02-08)

### 扫描输入
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests docs`
- `python3 scripts/analyze_code_quality.py`

### 发现
- 代码质量脚本识别 3 类低风险项：debug/style/hardcoded。
- TODO 类项主要在文档与 roadmap；代码侧高风险 TODO 已基本清空。
- 结构性机会主要集中在超大文件拆分：`cmd.package`、`resource.repo`、`build.cache`。

### 生成的下一轮批次
1. B013：`fpdev.cmd.package` 第一切片（helper 提取）
2. B014：代码风格与调试输出清理
3. B015：硬编码常量分层与配置化

## B013 拆分试点准备 (2026-02-08)

### 目标文件
- `src/fpdev.cmd.package.pas`（2497 LOC）

### 第一切片候选（按现有区段边界）
- `Semantic Version Functions Implementation`: `1737`–`1968`
- `Dependency Graph Functions`: `1969`–`2154`
- `Package Verification Functions Implementation`: `2155`–`2239`
- `Package Creation Functions Implementation`: `2240`–`2370`
- `Package Validation Functions Implementation`: `2371`–`2497`

### 执行策略
- 第一步仅抽取 `Semantic Version` + `Dependency Graph` 到新 helper 单元。
- 保留 `TPackageManager` 与命令入口在原文件，避免行为变化。
- 每次切片后执行 `lazbuild -B fpdev.lpi` + `bash scripts/run_all_tests.sh`。


## B013 拆分试点结果 (2026-02-08)

### 本批交付
- 新增 `src/fpdev.cmd.package.semver.pas`，承载 `Parse/Compare/Constraint` 三个语义版本函数实现。
- `src/fpdev.cmd.package.pas` 中语义版本实现改为薄封装（wrapper），接口签名保持不变。
- 修复 `src/fpdev.lpr` 的噪音 diff，仅保留删除 `fpdev.cmd.lazarus` 一行逻辑改动。

### 验证结果
- `lazbuild -B fpdev.lpi`（日志：`/tmp/fpdev_b013b_build.log`）
  - `Warnings(src)=0`
  - `Hints(src)=0`（代码文件级）
- `bash scripts/run_all_tests.sh`（日志：`/tmp/fpdev_b013b_tests.log`）
  - `Total=94, Passed=94, Failed=0`

### 结论
- B013 第一切片（Semantic Version）已完成且无行为回归。
- 下一步可在同一策略下执行 `Dependency Graph` 切片（B016）。

## B014 质量项清理结果 (2026-02-08)

### 变更
- `scripts/analyze_code_quality.py`：
  - 增加 Pascal 注释状态机（`{...}`、`(*...*)`、`//`）以避免将注释/示例代码误报为 debug。
  - 对 `Write/WriteLn` 检测增加限定（忽略对象方法调用与声明行）。
  - 对字符串字面量进行剥离后再匹配，减少示例文本触发误报。

### 验证
- `python3 scripts/analyze_code_quality.py`（日志：`/tmp/fpdev_b014_quality3.log`）
  - 脚本运行正常，仍保留真实可疑项输出。

### 结论
- 已收敛“注释/示例触发 debug 误报”的主要噪音来源。
- 保留对真实 `Write/WriteLn` 可疑调用的检测能力。



## B015 常量治理结果 (2026-02-08)

### 变更
- `src/fpdev.constants.pas`：新增集中常量
  - `FPC_MIRROR_SOURCEFORGE`
  - `FPC_MIRROR_GITHUB_RELEASES`
  - `FPC_MIRROR_GITEE_RELEASES`
  - `UNIX_MAKE_PATH`
  - `PROC_UPTIME_FILE`
  - `PROC_MEMINFO_FILE`
- `src/fpdev.fpc.mirrors.pas`：默认镜像 URL 改为引用常量。
- `src/fpdev.cmd.lazarus.pas`：`3.2.2` 和 `/usr/bin/make` 改为引用常量。
- `src/fpdev.utils.pas`：`/proc/uptime` 与 `/proc/meminfo` 路径改为引用常量。

### 验证
- `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b015_build.log`）
  - `Warnings(src)=0`
  - `Hints(src)=0`
- `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b015_tests.log`）
  - `Total=94, Passed=94, Failed=0`

### 结论
- B015 完成：硬编码常量已完成第一轮集中治理且行为不变。


## B016 拆分第二切片结果 (2026-02-08)

### 本批交付
- 新增 `src/fpdev.cmd.package.depgraph.pas`，承载依赖图构建与拓扑排序实现。
- `src/fpdev.cmd.package.pas` 中 `BuildDependencyGraph` / `TopologicalSortDependencies` 改为 wrapper，外部接口保持不变。
- 继续保持 `TPackageManager` 与命令层逻辑留在原文件，避免行为改动。

### 执行中问题与修复
- 首次替换时误命中 interface 区块，导致替换范围过大。
- 处理：立即回滚目标文件并改为 `implementation` 段后锚点精确替换，再次验证通过。

### 验证
- `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b016_build.log`）
  - `Warnings(src)=0`
  - `Hints(src)=0`
- `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b016_tests.log`）
  - `Total=94, Passed=94, Failed=0`

### 结论
- B016 完成：`cmd.package` 第二切片已落地，行为保持稳定。


## B017 自治复盘结果 (2026-02-08)

### 复盘输入
- `python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b017_quality.log`）
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests docs`
- `src/*.pas` 大文件统计（`>=1000 LOC`）

### 当前池状态
- 质量脚本仍为 3 类问题：`debug_code` / `code_style` / `hardcoded_constants`。
- 代码侧 TODO 基本清空，仅剩 `src/fpdev.resource.repo.pas` 一条注释型说明。
- 超大文件热区（Top）：
  - `src/fpdev.cmd.package.pas` (2131)
  - `src/fpdev.resource.repo.pas` (1996)
  - `src/fpdev.build.cache.pas` (1955)

### 决策
- 继续优先拆分 `fpdev.cmd.package`（上下文连续、风险可控）。
- 后续批次按 `Verification -> Creation -> Validation` 顺序继续切片。


## B018 下一轮拆分立项结果 (2026-02-08)

### 立项输入
- 复核 `src/fpdev.cmd.package.pas` 当前切片边界与剩余函数区段。

### 固化的执行边界
- `Package Verification`: `1790`–`1874`
- `Package Creation`: `1875`–`2004`
- `Package Validation`: `2005`–`2130`

### 决策
- B019 执行 `Package Verification` helper 抽离。
- B020/B021 继续按 Creation/Validation 顺序推进。


## B019 第三切片结果 (2026-02-08)

### 本批交付
- 新增 `src/fpdev.cmd.package.verify.pas`，承载包验证与校验和实现。
- `src/fpdev.cmd.package.pas` 中 `VerifyInstalledPackage` / `VerifyPackageChecksum` 改为 wrapper。
- 包管理器对外接口保持不变，状态值通过 wrapper 映射回原枚举。

### 验证
- `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b019_build.log`）
  - `Warnings(src)=0`
  - `Hints(src)=0`
- `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b019_tests.log`）
  - `Total=94, Passed=94, Failed=0`

### 结论
- B019 完成，第三切片稳定通过回归。


## B020 第四切片结果 (2026-02-08)

### 本批交付
- 新增 `src/fpdev.cmd.package.create.pas`，承载 package creation 相关实现。
- `src/fpdev.cmd.package.pas` 中 creation 相关函数改为 wrapper：
  - `IsBuildArtifact`
  - `CollectPackageSourceFiles`
  - `GeneratePackageMetadataJson`
  - `CreatePackageZipArchive`

### 过程问题与修复
- 首次 helper 使用了不存在的 `GetFileListRecursive`，导致编译失败。
- 修复：回退为原始递归扫描逻辑并保持原行为语义（含扩展名判断）。

### 验证
- `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b020_build.log`）
- `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b020_tests.log`）
  - `Total=94, Passed=94, Failed=0`


## B021 第五切片结果 (2026-02-08)

### 本批交付
- 新增 `src/fpdev.cmd.package.validation.pas`，承载 package validation 相关实现。
- `src/fpdev.cmd.package.pas` 中 validation 相关函数改为 wrapper：
  - `ValidatePackageSourcePath`
  - `ValidatePackageMetadata`
  - `CheckPackageRequiredFiles`

### 过程问题与修复
- 初次错误覆盖了已有命令单元 `src/fpdev.cmd.package.validate.pas`，导致 `test_package_validate` 编译失败。
- 修复：恢复原命令单元；新 helper 改用不冲突名称 `fpdev.cmd.package.validation`。

### 验证
- `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b021_build.log`）
- `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b021_tests.log`）
  - `Total=94, Passed=94, Failed=0`


## B022 周期复盘结果 (2026-02-08)

### 指标快照
- `scripts/analyze_code_quality.py`：仍为 `3` 类问题（debug/style/hardcoded），与 B017 持平。
- `src/fpdev.cmd.package.pas` 行数：`2131 -> 1874`（核心实现持续外移）。
- 新增 helper 单元：`semver/depgraph/verify/create/validation` 共 5 个。

### 结果
- 连续批次 B015-B021 完成，编译与全测维持稳定（`94/94`）。
- 下一阶段进入横向拆分立项：`resource.repo` 与 `build.cache`。

## 项目问题扫描结果 (2026-02-07)

### 扫描范围
- 目录: `/home/dtamade/projects/fpdev`
- 重点: `src/` 目录下的 Pascal 源代码

### 问题统计
| 类别 | 数量 | 优先级 |
|------|------|--------|
| Warning: @deprecated 使用 | 17+ | 高 |
| Warning: 返回值未初始化 | 8 | 高 |
| Warning: Case 不完整 | 3 | 高 |
| Hint: 变量未初始化 | 10+ | 中 |
| Hint: 未使用单元 | 24+ | 低 |
| Hint: 未使用参数/变量 | 20+ | 低 |
| TODO/FIXME | 1 (关键) | 高 |
| 超大文件 (>1000行) | 10 | 中 |

## 高优先级问题详情

### 1. @deprecated GitManager 使用 (17+ 处)

**问题**: Phase 2 架构重构后，`GitManager` 已标记为 `@deprecated`，应迁移到 `NewGitManager()`。

**影响文件**:
- `fpdev.git2.pas` (6 处)
- `fpdev.source.repo.pas` (6 处)
- `fpdev.fpc.source.pas` (2 处)
- `fpdev.fpc.installer.pas` (2 处)
- `fpdev.cmd.fpc.pas` (2 处)

**迁移方案**:
```pascal
// 旧代码
uses fpdev.git2;
Repo := GitManager.OpenRepository('.');

// 新代码
uses git2.api, git2.impl;
var Mgr: IGitManager;
Mgr := NewGitManager();
Mgr.Initialize;
Repo := Mgr.OpenRepository('.');
```

### 2. 函数返回值未初始化 (8 处)

**问题**: 返回 managed type (string, array) 的函数未初始化返回值。

**影响文件**:
| 文件 | 行号 |
|------|------|
| fpdev.config.project.pas | 324 |
| fpdev.manifest.pas | 476, 486 |
| fpdev.fpc.types.pas | 163, 173 |
| fpdev.cross.manifest.pas | 161, 341 |
| fpdev.cmd.package.pas | 2297, 2447 |

**修复方案**:
```pascal
// 对于 string
Result := '';

// 对于 array
SetLength(Result, 0);
// 或
Result := nil;
```

### 3. Case 语句不完整 (3 处)

**影响文件**:
| 文件 | 行号 |
|------|------|
| fpdev.cmd.show.pas | 117, 132 |
| fpdev.toolchain.fetcher.pas | 209 |

**修复方案**: 添加 `else` 分支处理未覆盖的情况。

### 4. TODO: SHA256 校验和占位符

**位置**: `fpdev.package.resolver.pas:251`

**问题**: 包锁定文件使用 `'sha256-placeholder'` 占位符，影响完整性验证。

**修复方案**: 实现实际的 SHA256 计算逻辑。

## 中优先级问题详情

### 变量未初始化 (10+ 处)

| 文件 | 行号 | 变量 |
|------|------|------|
| fpdev.utils.fs.pas | 242 | StatBuf |
| fpdev.build.cache.pas | 1265 | Entries |
| fpdev.command.registry.pas | 124 | D |
| fpdev.toolchain.fetcher.pas | 285 | URLs |
| fpdev.cmd.package.pas | 1758, 1771, 2053, 2082 | 多个 |
| fpdev.cross.manifest.pas | 433, 455 | AManifestTarget, ABinutils |
| fpdev.fpc.version.pas | 369 | Info |

## 技术债务 (来自计划文件)

### Phase C: 技术债务清理
- C.1: Wave 4 提前执行 - 清理 @deprecated 代码 (1-2 天)
- C.2: 测试覆盖率提升 (2-3 天)
- C.3: 代码重构 (2-3 天)

### Phase A: 待办事项完成
- BuildManager 文档完善 (0.5-1 天)
- 日志系统优化 (0.5 天)
- Git2 功能扩展 (1-1.5 天)

## 超大文件 (需要拆分)

| 文件 | 行数 |
|------|------|
| fpdev.cmd.package.pas | 2487 |
| fpdev.resource.repo.pas | 1996 |
| fpdev.build.cache.pas | 1954 |
| fpdev.config.managers.pas | 1345 |
| fpdev.fpc.installer.pas | 1307 |
| fpdev.cmd.fpc.pas | 1279 |
| fpdev.cmd.cross.pas | 1247 |
| fpdev.build.manager.pas | 1234 |
| fpdev.git2.pas | 1050 |

## Technical Decisions

| Decision | Rationale |
|----------|-----------|
| 先修 Warning 再修 Hint | Warning 可能导致运行时错误 |
| 保持测试通过 | 每次修改后验证测试 |
| 分批提交 | 便于回滚和追踪 |
| @deprecated 迁移优先 | 符合 Phase 2 架构重构计划 |

## Resources

- 全量测试: `scripts/run_all_tests.sh`
- 编译检查: `lazbuild -B fpdev.lpi 2>&1 | grep -E "(Warning|Error|Hint)"`
- Phase 2 迁移指南: `docs/PHASE2-MIGRATION-GUIDE.md`

#### Batch B023: 横向拆分立项（完成）
- **Status:** complete
- **Goal:** 为 `src/fpdev.resource.repo.pas` / `src/fpdev.build.cache.pas` 生成低风险切片顺序
- **Actions:**
  - 基于函数簇与依赖关系完成横向切片边界划分
  - 明确首切片选择：`resource.repo` 的 bootstrap 映射/解析簇（低耦合）
- **Slice Plan (resource.repo):**
  - R1 `GetRequiredBootstrapVersion` + `GetBootstrapVersionFromMakefile` + `ListBootstrapVersions`（~655-844）
  - R2 镜像策略簇：`DetectUserRegion`/`TestMirrorLatency`/`SelectBestMirror`/`GetMirrors`（~1271-1525）
  - R3 包查询簇：`HasPackage`/`GetPackageInfo`/`ListPackages`/`SearchPackages`（~1718-1940）
- **Slice Plan (build.cache):**
  - C1 平台/键值/路径 helper：`GetCurrentCPU`/`GetCurrentOS`/`GetArtifactKey`/`GetArtifact*Path`（~261-346）
  - C2 条目元数据簇：`LoadEntries`/`SaveEntries`/`FindEntry`/`UpdateCache`（~375-547）
  - C3 工件缓存簇：`Has/Save/Restore/Delete/GetArtifactInfo/ListCachedVersions`（~555-768）
  - C4 二进制缓存+校验簇：`SaveBinaryArtifact`/`RestoreBinaryArtifact`/`VerifyArtifact`（~818-1174）
  - C5 JSON 元数据与索引簇：`Save/LoadMetadataJSON` + `Load/Save/RebuildIndex` + stats（~1351-1927）
- **Risk Controls:**
  - 保持 public API 与调用点不变，仅 implementation 改 wrapper
  - 先抽离纯函数/弱状态逻辑，避免首批触及 I/O 密集路径

#### Batch B024: resource.repo 第一切片（完成）
- **Status:** complete
- **Goal:** 抽离 bootstrap 映射/Makefile 解析 helper，保持行为与接口稳定
- **Actions:**
  - 新增 `src/fpdev.resource.repo.bootstrap.pas`
  - 抽离函数：
    - `ResourceRepoGetRequiredBootstrapVersion`
    - `ResourceRepoGetBootstrapVersionFromMakefile`
    - `ResourceRepoListBootstrapVersions`
  - `src/fpdev.resource.repo.pas` 中对应方法改为 wrapper（保留原日志语义与回退路径）
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b024_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b024_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 行为保持不变，完成 resource 首切片落地

#### Next Auto Batches
1. B025 build.cache 第一切片执行（C1 平台/键值 helper）
2. B026 周期复盘（B023-B025 收口）
3. B027 resource.repo 第二切片（镜像策略簇）

#### Batch B025: build.cache 第一切片（完成）
- **Status:** complete
- **Goal:** 抽离 `build.cache` 的平台/键值纯函数，降低核心类体积与耦合
- **Actions:**
  - 新增 `src/fpdev.build.cache.key.pas`
  - 抽离函数：
    - `BuildCacheGetCurrentCPU`
    - `BuildCacheGetCurrentOS`
    - `BuildCacheGetArtifactKey`
  - `src/fpdev.build.cache.pas` 中对应私有方法改为 wrapper：
    - `GetCurrentCPU`
    - `GetCurrentOS`
    - `GetArtifactKey`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b025_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b025_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 行为稳定，完成 build.cache 首切片

#### Next Auto Batches
1. B026 周期复盘（B023-B025 收口）
2. B027 resource.repo 第二切片（镜像策略簇）
3. B028 build.cache 第二切片（entries/index 边界优化）

#### Batch B026: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B023-B025 连续批次结果，确认稳定性并刷新任务池
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b026_quality.log`, exit=3）
  - 结构统计：`wc -l src/fpdev.resource.repo.pas src/fpdev.build.cache.pas`
    - `resource.repo: 1996 -> 1857`
    - `build.cache: 1955 -> 1923`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b025_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b025_tests.log`）
- **Result:**
  - 连续三批（B023-B025）均保持 `Build=0` 且 `Tests=94/94`
  - 大文件持续收敛，切片策略有效
  - 新任务池继续聚焦：镜像策略簇与 cache entries/index 簇

#### Next Auto Batches
1. B027 resource.repo 第二切片（镜像策略簇）
2. B028 build.cache 第二切片（entries/index 簇）
3. B029 周期复盘（B027-B028 收口）

#### Batch B027: resource.repo 第二切片（完成）
- **Status:** complete
- **Goal:** 抽离镜像区域探测与延迟测试逻辑，降低 `resource.repo` 复杂度
- **Actions:**
  - 新增 `src/fpdev.resource.repo.mirror.pas`
  - 抽离函数：
    - `ResourceRepoDetectUserRegion`
    - `ResourceRepoTestMirrorLatency`
  - `src/fpdev.resource.repo.pas` 改为 wrapper：
    - `DetectUserRegion`
    - `TestMirrorLatency`
  - implementation uses 增加 `fpdev.resource.repo.mirror`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b027_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b027_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 镜像策略簇切片推进完成（step-1）

#### Next Auto Batches
1. B028 build.cache 第二切片（entries/index helper）
2. B029 周期复盘（B027-B028 收口）
3. B030 resource.repo 第三切片（GetMirrors/SelectBestMirror 候选抽离）

#### Batch B028: build.cache 第二切片（完成）
- **Status:** complete
- **Goal:** 抽离 entries 基础函数，继续收敛 `TBuildCache` 方法体
- **Actions:**
  - 新增 `src/fpdev.build.cache.entries.pas`
  - 抽离函数：
    - `BuildCacheGetCacheFilePath`
    - `BuildCacheGetEntryCount`
    - `BuildCacheFindEntry`
  - `src/fpdev.build.cache.pas` 中对应方法改 wrapper：
    - `GetCacheFilePath`
    - `GetEntryCount`
    - `FindEntry`
  - implementation uses 增加 `fpdev.build.cache.entries`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b028_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b028_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - entries/index 路线切片完成首段落地

#### Next Auto Batches
1. B029 周期复盘（B027-B028 收口）
2. B030 resource.repo 第三切片（SelectBestMirror/GetMirrors 候选抽离）
3. B031 build.cache 第三切片（index JSON 读写 helper）

#### Batch B029: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B027-B028，并确认快速冲刺策略稳定性
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b029_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1857 -> 1774`
    - `build.cache: 1923 -> 1919`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b028_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b028_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` + `Tests=94/94`
  - 快速冲刺节奏有效，可继续按 helper + wrapper 路线推进

#### Next Auto Batches
1. B030 resource.repo 第三切片（GetMirrors/SelectBestMirror 候选抽离）
2. B031 build.cache 第三切片（index JSON 读写 helper）
3. B032 周期复盘（B030-B031 收口）

#### Batch B030: resource.repo 第三切片（完成）
- **Status:** complete
- **Goal:** 抽离 `SelectBestMirror` 的候选镜像构建逻辑，继续收敛镜像策略簇
- **Actions:**
  - `src/fpdev.resource.repo.mirror.pas`
    - 新增 `ResourceRepoBuildCandidateMirrors`
  - `src/fpdev.resource.repo.pas`
    - `SelectBestMirror` 候选镜像收集段改为 helper 调用
    - 保留缓存 TTL、延迟测速、错误回退与缓存写回逻辑
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b030_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b030_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 镜像主流程切片推进完成（候选构建段）

#### Next Auto Batches
1. B031 build.cache 第三切片（index JSON 读写 helper）
2. B032 周期复盘（B030-B031 收口）
3. B033 resource.repo 第四切片（GetMirrors 解析 helper）

#### Batch B031: build.cache 第三切片（完成）
- **Status:** complete
- **Goal:** 抽离 index JSON 读写公共逻辑，降低 `LookupIndexEntry/UpdateIndexEntry` 复杂度
- **Actions:**
  - 新增 `src/fpdev.build.cache.indexjson.pas`
    - `BuildCacheParseIndexEntryJSON`
    - `BuildCacheBuildIndexEntryJSON`
    - `BuildCacheNormalizeIndexDate`
  - `src/fpdev.build.cache.pas`
    - `LookupIndexEntry` 改为复用 helper 解析与日期标准化
    - `UpdateIndexEntry` 改为复用 helper 序列化
    - implementation uses 增加 `fpdev.build.cache.indexjson`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b031_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b031_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - index JSON 切片完成，行为稳定

#### Next Auto Batches
1. B032 周期复盘（B030-B031 收口）
2. B033 resource.repo 第四切片（GetMirrors 解析 helper）
3. B034 build.cache 第四切片（Load/SaveIndex I/O helper）

#### Batch B032: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B030-B031 并确认快速冲刺延续稳定
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b032_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1774 -> 1726`
    - `build.cache: 1904`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b031_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b031_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` 与 `Tests=94/94`
  - 冲刺策略可继续，进入 `B033`

#### Next Auto Batches
1. B033 resource.repo 第四切片（GetMirrors 解析 helper）
2. B034 build.cache 第四切片（Load/SaveIndex I/O helper）
3. B035 周期复盘（B033-B034 收口）

#### Batch B033: resource.repo 第四切片（完成）
- **Status:** complete
- **Goal:** 抽离 `GetMirrors` 的 manifest 解析逻辑
- **Actions:**
  - `src/fpdev.resource.repo.mirror.pas`
    - 新增 `TResourceRepoMirrorInfo` / `TResourceRepoMirrorInfoArray`
    - 新增 `ResourceRepoGetMirrorsFromManifest`
  - `src/fpdev.resource.repo.pas`
    - `GetMirrors` 改为 helper 解析 + 类型映射 wrapper
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b033_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b033_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 镜像策略簇切片继续收敛

#### Next Auto Batches
1. B034 build.cache 第四切片（Load/SaveIndex I/O helper）
2. B035 周期复盘（B033-B034 收口）
3. B036 resource.repo 第五切片（SelectBestMirror 主流程 helper）

#### Batch B034: build.cache 第四切片（完成）
- **Status:** complete
- **Goal:** 抽离 `LoadIndex/SaveIndex` 的索引 I/O 逻辑
- **Actions:**
  - 新增 `src/fpdev.build.cache.indexio.pas`
    - `BuildCacheLoadIndexEntries`
    - `BuildCacheSaveIndexEntries`
  - `src/fpdev.build.cache.pas`
    - `LoadIndex` 改为调用 `BuildCacheLoadIndexEntries`
    - `SaveIndex` 改为调用 `BuildCacheSaveIndexEntries`
    - implementation uses 增加 `fpdev.build.cache.indexio`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b034_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b034_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - index I/O 切片完成，行为稳定

#### Next Auto Batches
1. B035 周期复盘（B033-B034 收口）
2. B036 resource.repo 第五切片（SelectBestMirror 主流程 helper）
3. B037 build.cache 第五切片（RebuildIndex 扫描 helper）

#### Batch B035: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B033-B034 并刷新后续冲刺入口
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b035_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1726 -> 1718`
    - `build.cache: 1904 -> 1820`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b034_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b034_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` 与 `Tests=94/94`
  - 快速冲刺继续推进到 B036

#### Next Auto Batches
1. B036 resource.repo 第五切片（SelectBestMirror 主流程 helper）
2. B037 build.cache 第五切片（RebuildIndex 扫描 helper）
3. B038 周期复盘（B036-B037 收口）

#### Batch B036: resource.repo 第五切片（完成）
- **Status:** complete
- **Goal:** 抽离 `SelectBestMirror` 中“测速择优”主流程逻辑
- **Actions:**
  - `src/fpdev.resource.repo.mirror.pas`
    - 新增类型：
      - `TResourceRepoMirrorLatencyArray`
      - `TResourceRepoMirrorLatencyTestFunc`
    - 新增函数：`ResourceRepoSelectBestMirrorFromCandidates`
  - `src/fpdev.resource.repo.pas`
    - `SelectBestMirror` 改为调用 `ResourceRepoSelectBestMirrorFromCandidates`
    - 保留缓存 TTL、错误回退、镜像延迟记录写回行为
  - 修复一次 managed-type hint：显式初始化 `ALatencies := nil`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b036_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b036_tests.log`）
- **Result:**
  - Build: `exit=0`（`4 hints`，恢复到切片前水平）
  - Tests: `94/94 passed`
  - SelectBestMirror 主流程进一步瘦身，行为保持稳定

#### Next Auto Batches
1. B037 build.cache 第五切片（RebuildIndex 扫描 helper）
2. B038 周期复盘（B036-B037 收口）
3. B039 resource.repo 第六切片（mirror cache TTL helper）

#### Batch B037: build.cache 第五切片（完成）
- **Status:** complete
- **Goal:** 抽离 `RebuildIndex` 的 metadata 文件扫描/版本提取逻辑
- **Actions:**
  - 新增 `src/fpdev.build.cache.rebuildscan.pas`
    - `BuildCacheExtractVersionFromMetadataFilename`
    - `BuildCacheListMetadataVersions`
  - `src/fpdev.build.cache.pas`
    - `RebuildIndex` 改为使用 `BuildCacheListMetadataVersions`
    - implementation uses 增加 `fpdev.build.cache.rebuildscan`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b037_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b037_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - RebuildIndex 扫描流程切片完成，行为稳定

#### Next Auto Batches
1. B038 周期复盘（B036-B037 收口）
2. B039 resource.repo 第六切片（mirror cache TTL helper）
3. B040 build.cache 第六切片（index stats helper）

#### Batch B038: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B036-B037 并刷新冲刺入口
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b038_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1718 -> 1721`（函数抽离+类型映射后的微小波动）
    - `build.cache: 1820 -> 1802`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b037_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b037_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` 与 `Tests=94/94`
  - 冲刺可继续推进 B039/B040

#### Next Auto Batches
1. B039 resource.repo 第六切片（mirror cache TTL helper）
2. B040 build.cache 第六切片（index stats helper）
3. B041 周期复盘（B039-B040 收口）

#### Batch B039: resource.repo 第六切片（完成）
- **Status:** complete
- **Goal:** 抽离镜像缓存 TTL 命中判断逻辑
- **Actions:**
  - `src/fpdev.resource.repo.mirror.pas`
    - 新增 `ResourceRepoTryGetCachedMirror`
  - `src/fpdev.resource.repo.pas`
    - `SelectBestMirror` 的缓存判断改为 helper 调用
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b039_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b039_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 缓存 TTL 逻辑完成切片，行为保持稳定

#### Next Auto Batches
1. B040 build.cache 第六切片（index stats helper）
2. B041 周期复盘（B039-B040 收口）
3. B042 resource.repo 第七切片（mirror cache set helper）

#### Batch B040: build.cache 第六切片（完成）
- **Status:** complete
- **Goal:** 抽离 `GetIndexStatistics` 的统计累计逻辑到独立 helper
- **Actions:**
  - 新增 `src/fpdev.build.cache.indexstats.pas`
    - `BuildCacheIndexStatsInit`
    - `BuildCacheIndexStatsAccumulate`
    - `BuildCacheIndexStatsFinalize`
  - `src/fpdev.build.cache.pas`
    - `GetIndexStatistics` 改为 helper 驱动，保留原有字段语义
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b040_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b040_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 统计逻辑完成切片，行为保持稳定

#### Next Auto Batches
1. B041 周期复盘（B039-B040 收口）
2. B042 resource.repo 第七切片（mirror cache set helper）
3. B043 build.cache 第七切片（index lookup helper）

#### Batch B041: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B039-B040 并刷新下一轮冲刺入口
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b041_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1721 -> 1716`
    - `build.cache: 1802 -> 1786`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b040_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b040_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` 与 `Tests=94/94`
  - 质量扫描为存量项（exit=3）且无新增高风险
  - 进入 B042/B043 横向拆分

#### Next Auto Batches
1. B042 resource.repo 第七切片（mirror cache set helper）
2. B043 build.cache 第七切片（index lookup helper）
3. B044 周期复盘（B042-B043 收口）

#### Batch B042: resource.repo 第七切片（完成）
- **Status:** complete
- **Goal:** 抽离 `SelectBestMirror` 的镜像缓存写入逻辑为 helper
- **Actions:**
  - `src/fpdev.resource.repo.mirror.pas`
    - 新增 `ResourceRepoSetCachedMirror`
  - `src/fpdev.resource.repo.pas`
    - `SelectBestMirror` 内缓存写入改为 `ResourceRepoSetCachedMirror(...)`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b042_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b042_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 缓存写入逻辑切片完成，镜像选择语义保持不变

#### Next Auto Batches
1. B043 build.cache 第七切片（index lookup helper）
2. B044 周期复盘（B042-B043 收口）
3. B045 resource.repo 第八切片（package query helper）

#### Batch B043: build.cache 第七切片（完成）
- **Status:** complete
- **Goal:** 抽离 `LookupIndexEntry` 的索引读取/日期归一化 helper
- **Actions:**
  - `src/fpdev.build.cache.indexjson.pas`
    - 新增 `BuildCacheGetIndexEntryJSON`
    - 新增 `BuildCacheGetNormalizedIndexDates`
  - `src/fpdev.build.cache.pas`
    - `LookupIndexEntry` 改为调用上述 helper
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b043_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b043_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 索引查找逻辑进一步收敛，行为保持稳定

#### Next Auto Batches
1. B044 周期复盘（B042-B043 收口）
2. B045 resource.repo 第八切片（package query helper）
3. B046 build.cache 第八切片（stats report helper）

#### Batch B044: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B042-B043 并刷新后续冲刺队列
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b044_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1716 -> 1715`
    - `build.cache: 1786 -> 1782`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b043_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b043_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` 与 `Tests=94/94`
  - 质量扫描仍为存量项（exit=3），无新增高风险

#### Next Auto Batches
1. B045 resource.repo 第八切片（package query helper）
2. B046 build.cache 第八切片（stats report helper）
3. B047 周期复盘（B045-B046 收口）

#### Batch B045: resource.repo 第八切片（完成）
- **Status:** complete
- **Goal:** 抽离 package metadata 路径解析 helper，收敛 `GetPackageInfo` 文件定位逻辑
- **Actions:**
  - 新增 `src/fpdev.resource.repo.package.pas`
    - `ResourceRepoResolvePackageMetaPath`
  - `src/fpdev.resource.repo.pas`
    - implementation uses 增加 `fpdev.resource.repo.package`
    - `GetPackageInfo` 元数据路径解析改为 helper 调用
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b045_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b045_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - package query 路径解析切片完成，行为保持稳定

#### Next Auto Batches
1. B046 build.cache 第八切片（stats report helper）
2. B047 周期复盘（B045-B046 收口）
3. B048 resource.repo 第九切片（search filter helper）

## Session 2026-02-12: 全仓未完成项/缺口扫描（writing-plans 输入）

### 扫描范围与命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests scripts docs`
- `python3 scripts/analyze_code_quality.py`
- `rg -n "not yet implemented|not implemented" src`
- `rg -n "fpdev.registry.client|fpdev.github.api|fpdev.gitlab.api|TRemoteRegistryClient|TGitHubClient|TGitLabClient" tests`

### 关键发现
1. `src/` 内与“未实现”直接相关的命中共 15 处，集中在 3 个网络客户端：
   - `src/fpdev.registry.client.pas`（POST/PUT 未实现）
   - `src/fpdev.github.api.pas`（POST/PUT/DELETE 与 create/upload/delete API 未实现）
   - `src/fpdev.gitlab.api.pas`（POST/PUT/DELETE 与 create/upload/delete API 未实现）
2. 针对上述 3 个单元，`tests/` 内当前没有直接覆盖（`rg` 命中为空）。
3. `python3 scripts/analyze_code_quality.py` 报告 3 类问题：debug_code(1)、code_style(1)、hardcoded_constants(1)，其中 `src/fpdev.fpc.binary.pas` 的直接 `WriteLn` 属可改进项，但优先级低于功能未实现路径。

### 优先级判断（用于执行计划）
- P0: 先补 `TRemoteRegistryClient` 的 POST/PUT/DELETE 请求通路，并以离线可复现测试验证“不再返回 not yet implemented”。
- P1: 为 `TGitHubClient`/`TGitLabClient` 做同类 HTTP 方法能力补全。
- P2: 清理 quality 脚本指示的 debug/style/hardcoded 低风险项。

## Session 2026-02-12: P0 执行结果（remote registry HTTP methods）

### Root Cause
`TRemoteRegistryClient.ExecuteWithRetry` 仅实现 GET；POST/PUT 直接返回硬编码错误，导致 `UploadPackage/PublishMetadata` 永远失败。

### Fix
在 `src/fpdev.registry.client.pas` 中将 POST/PUT 由占位分支改为真实 HTTP 调用：
- `FHTTPClient.RequestBody := ABody`
- `FHTTPClient.HTTPMethod(AMethod, AURL, AResponse, [200,201,202,204])`
- 调用后清空 `RequestBody`
- 同时新增 DELETE 分支（`HTTPMethod('DELETE', ...)`）

### Tests Added
- `tests/test_registry_client_remote.lpr`
  - 验证 `PublishMetadata` / `UploadPackage` 走真实请求路径（不可达地址时失败，但错误不应再是 `not yet implemented`）

### Verification
- 新增测试：RED 失败 -> GREEN 通过
- 目标回归：`test_package_registry` 35/35，`test_package_publish` 26/26
- 全量回归：`scripts/run_all_tests.sh` => `174/174` 通过

## Session 2026-02-12: Team T1 结果（GitHub API 非 GET）

### 缺口
`fpdev.github.api` 的 `ExecuteRequest` 仅实现 GET，Create/Release/Asset 操作使用硬编码 `not yet implemented`。

### 修复
- 在 `ExecuteRequest` 中实现 POST/PUT (`RequestBody + HTTPMethod`) 与 DELETE (`HTTPMethod('DELETE')`)。
- `CreateRepository` / `CreateRelease`：构建 JSON body 发起 POST，并解析 JSON object 响应。
- `UploadReleaseAsset`：读取文件并 POST 上传；文件不存在时返回明确错误。
- `DeleteReleaseAsset`：发起 DELETE 请求。

### 证据
- RED: 新测试 `tests/test_github_api_remote.lpr` 初次运行 `Failed: 4`。
- GREEN: 同测试修复后 `Passed: 8, Failed: 0`。
- 全量回归: `scripts/run_all_tests.sh` -> `175/175` 通过。

## Session 2026-02-12: Team T2 结果（GitLab API 非 GET）

### 缺口
`fpdev.gitlab.api` 的 `ExecuteRequest` 仅实现 GET，Create/Package/Release 的写操作路径使用硬编码 `not yet implemented`。

### 修复
- 在 `ExecuteRequest` 中实现 POST/PUT (`RequestBody + HTTPMethod`) 与 DELETE (`HTTPMethod('DELETE')`)。
- `CreateProject`：JSON body 发起 POST 并解析 JSON object 响应。
- `UploadPackage`：读取文件并 POST 上传；文件不存在时返回明确错误。
- `DeletePackage`：发起 DELETE 请求。
- `CreateRelease`：JSON body 发起 POST 并解析 JSON object 响应。

### 证据
- RED: 新测试 `tests/test_gitlab_api_remote.lpr` 初次运行 `Failed: 4`。
- GREEN: 同测试修复后 `Passed: 8, Failed: 0`。
- 全量回归: `scripts/run_all_tests.sh` -> `176/176` 通过。

## Session 2026-02-12 (Round 2): 全仓扫描结果与优先级

### 扫描命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs --glob '!docs/archive/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests`
- `python3 scripts/analyze_code_quality.py`

### 结果摘要
1. 功能未实现类缺口已显著收敛；`src/` 中仅剩注释/提示类 `not implemented` 文案与平台保留分支。
2. 当前最可执行的真实缺口转为质量扫描噪音：`analyze_code_quality.py` 将以下场景误判为 debug：
   - `fpdev.output.console.pas` 中的输出封装方法
   - `Write(Source, ...)` 这种文件写入操作
3. `analyze_code_quality.py` 当前输出 `总问题数: 3`，其中 `debug_code` 包含明显误报，影响后续治理优先级判断。

### 本轮优先级
- P0: 修复 `analyze_code_quality.py` 的 debug 误报（先测试后修复）。
- P1: 处理 code_style 项（长行/行尾空格）按风险分批。
- P2: 硬编码常量治理（路径/版本字面量分类提取）。

## Session 2026-02-12 Round 2: P0 执行结果（质量扫描器误报治理）

### Root Cause
`analyze_temp_files_and_debug_code()` 使用通用 `write/writeln` 模式扫描，未区分以下非调试场景：
1. `fpdev.output.console.pas` 的输出封装方法
2. `Write(Source, ...)`/`WriteLn(Source, ...)` 的文件句柄写入

### Fix
- 新增回归测试 `tests/test_analyze_code_quality.py` 覆盖上述两类误报 + 一个真实 debug 命中样例。
- 在 `scripts/analyze_code_quality.py` 中加入最小规则修正：
  - `fpdev.output.console.pas` 不作为 debug 输出候选
  - `write(?:ln)?(<identifier>, ...)` 视为文件句柄写入，不计入 debug

### Evidence
- RED: `python3 -m unittest tests/test_analyze_code_quality.py -v` -> `FAILED (failures=2)`
- GREEN: 同命令 -> `OK`
- VERIFY: `python3 scripts/analyze_code_quality.py` 误报样例消失
- VERIFY: `bash scripts/run_all_tests.sh` -> `176/176` 通过

## Session 2026-02-12 Round 3: Style Batch 1 完成 + 新优先级计划

### 全仓扫描（本轮）

#### 扫描命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs --glob '!docs/archive/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests`
- `python3 scripts/analyze_code_quality.py`

#### 关键发现
1. 功能性 `not yet implemented` 主路径已收敛，当前 `src/` 命中以注释/提示或平台保留说明为主。
2. 质量脚本仍报告 `3` 类问题，但 style 目标文件已从报告中消失：
   - `src/fpdev.package.lockfile.pas`
   - `src/fpdev.cmd.package.repo.list.pas`
3. 当前最具性价比的下一批缺口是剩余 code_style 项：
   - `src/fpdev.cmd.lazarus.pas`（5 处超长行）
   - `src/fpdev.cmd.params.pas`（行尾空格）
   - `src/fpdev.cross.cache.pas`（多处行尾空格）

### 可执行优先级计划（下一批建议）
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 2（长行 + 行尾空格） | `src/fpdev.cmd.lazarus.pas`, `src/fpdev.cmd.params.pas`, `src/fpdev.cross.cache.pas` | 新增 Python 风格回归测试 RED->GREEN，且 analyzer 的 style 项减少 |
| P2 | Debug 输出分类治理（真实调试 vs 用户可见输出） | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 约定输出策略后减少 debug_code 噪音，不影响 CLI 可见行为 |
| P3 | 硬编码常量分层 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 将路径/版本字面量分类为常量或保留项并补充注释 |

### 本轮执行结论
- Style Batch 1 已按 TDD 完成（RED->GREEN->VERIFY）。
- 验证通过：`run_all_tests.sh` 全量 `176/176`。

## Session 2026-02-12 Round 4: Batch 2 执行完成 + 优先级更新

### 全仓扫描（本轮）

#### 扫描命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs --glob '!docs/archive/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests`
- `python3 scripts/analyze_code_quality.py`

#### 关键发现
1. `src/tests` 中“未实现”命中主要为注释、i18n 文案或测试断言文本，不是新功能缺口。
2. 当前最优先缺口仍为代码风格治理，但 Batch 2 的三个目标文件已清理完成。
3. `code_style` 现存文件为：
   - `src/fpdev.build.interfaces.pas`（行尾空格）
   - `src/fpdev.collections.pas`（长行）
   - `src/fpdev.cmd.project.template.remove.pas`（长行）

### 本轮执行（严格 TDD）
- RED: `python3 -m unittest tests/test_style_regressions_batch2.py -v` -> `FAILED (failures=3)`
- GREEN: 最小格式修复后同命令 -> `OK`
- VERIFY:
  - `python3 scripts/analyze_code_quality.py` -> `总问题数: 3`（style 已切换到下一批文件）
  - `bash scripts/run_all_tests.sh` -> `176/176` 通过

### 可执行优先级计划（更新）
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 3 | `src/fpdev.build.interfaces.pas`, `src/fpdev.collections.pas`, `src/fpdev.cmd.project.template.remove.pas` | 新增回归测试 RED->GREEN，analyzer style 项继续下降 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 降低 debug_code 噪音且不改变用户可见输出语义 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并保持回归通过 |

## Session 2026-02-12 Round 5: Batch 3 执行完成 + 优先级更新

### 全仓扫描（本轮）

#### 扫描命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs --glob '!docs/archive/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests`
- `python3 scripts/analyze_code_quality.py`

#### 关键发现
1. 功能未实现类命中仍以注释、文案和测试断言文本为主。
2. Batch 3 目标 style 文件清理后，style 报告已切换到新一批文件：
   - `src/fpdev.cmd.project.template.update.pas`
   - `src/fpdev.source.pas`
   - `src/fpdev.fpc.verify.pas`
3. debug_code 与 hardcoded_constants 仍为稳定存量，尚未进入本批次。

### 本轮执行（严格 TDD）
- RED: `python3 -m unittest tests/test_style_regressions_batch3.py -v` -> `FAILED (failures=3)`
- GREEN: 最小格式修复后同命令 -> `OK`
- VERIFY:
  - `python3 scripts/analyze_code_quality.py` -> `总问题数: 3`（style 已切换到下一批文件）
  - `bash scripts/run_all_tests.sh` -> `176/176` 通过

### 可执行优先级计划（更新）
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 4 | `src/fpdev.cmd.project.template.update.pas`, `src/fpdev.source.pas`, `src/fpdev.fpc.verify.pas` | 新增回归测试 RED->GREEN，analyzer style 项继续下降 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出与用户提示输出，降低 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并保持回归通过 |

## Session 2026-02-12 Round 6: Batch 4 执行完成 + 优先级更新

### 全仓扫描（本轮）

#### 扫描命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs --glob '!docs/archive/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests`
- `python3 scripts/analyze_code_quality.py`

#### 关键发现
1. 功能未实现类命中仍以注释、文案和测试断言文本为主。
2. Batch 4 目标 style 文件清理后，style 报告已切换到新一批文件：
   - `src/fpdev.cmd.package.pas`
   - `src/fpdev.config.interfaces.pas`
   - `src/fpdev.toml.parser.pas`
3. debug_code 与 hardcoded_constants 仍是稳定存量问题组。

### 本轮执行（严格 TDD）
- RED: `python3 -m unittest tests/test_style_regressions_batch4.py -v` -> `FAILED (failures=4)`
- GREEN: 最小格式修复后同命令 -> `OK`
- VERIFY:
  - `python3 scripts/analyze_code_quality.py` -> `总问题数: 3`（style 已切换到下一批文件）
  - `bash scripts/run_all_tests.sh` -> `176/176` 通过

### 可执行优先级计划（更新）
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 5 | `src/fpdev.cmd.package.pas`, `src/fpdev.config.interfaces.pas`, `src/fpdev.toml.parser.pas` | 新增回归测试 RED->GREEN，analyzer style 项继续下降 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出与用户提示输出，降低 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并保持回归通过 |

## Session 2026-02-12 Round 7: 全仓扫描结果与缺口

### 扫描命令
- `python3 scripts/analyze_code_quality.py`
- `rg -n "TODO|FIXME|XXX|TBD|HACK|WIP|未完成|待实现|待办" src tests scripts docs --glob '!**/__pycache__/**'`
- `rg -n "NotImplemented|raise Exception|assert\\(False\\)|fail\\(" src tests --glob '!**/__pycache__/**'`

### 结果摘要
1. 当前质量脚本输出仍为 `总问题数: 3`（`debug_code=1`, `code_style=1`, `hardcoded_constants=1`）。
2. `code_style` 明确命中 Batch 5 三文件：
   - `src/fpdev.cmd.package.pas`（5 处长行）
   - `src/fpdev.config.interfaces.pas`（5 处行尾空格）
   - `src/fpdev.toml.parser.pas`（5 处行尾空格）
3. `debug_code` 与 `hardcoded_constants` 仍是稳定存量组，适合作为 Batch 5 后的下一阶段任务。
4. TODO/FIXME 全仓命中以脚本文案、历史文档、归档记录为主，未发现新的高优先级“功能未实现”阻塞项。

### 本轮可执行优先级计划
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 5 | `src/fpdev.cmd.package.pas`, `src/fpdev.config.interfaces.pas`, `src/fpdev.toml.parser.pas` | 新增测试 RED->GREEN 且 style 从这三文件迁移 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出和用户输出，减少 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量抽离并保持行为不变 |

## Session 2026-02-12 Round 7: Batch 5 执行结果（严格 TDD）

### RED
- 命令: `python3 -m unittest tests/test_style_regressions_batch5.py -v`
- 输出要点:
  - `FAILED (failures=3)`
  - `src/fpdev.cmd.package.pas` 超长行: 6 处（含 line 1802）
  - `src/fpdev.config.interfaces.pas` 行尾空白: 7 处
  - `src/fpdev.toml.parser.pas` 行尾空白: 29 处

### GREEN
- 修改:
  - `src/fpdev.cmd.package.pas`: 6 处长行换行（接口声明/函数签名/路径拼接）
  - `src/fpdev.config.interfaces.pas`: 清理行尾空白
  - `src/fpdev.toml.parser.pas`: 清理行尾空白
- 命令: `python3 -m unittest tests/test_style_regressions_batch5.py -v`
- 输出: `Ran 3 tests in 0.001s` + `OK`

### VERIFY
- 命令: `python3 scripts/analyze_code_quality.py`
- 输出摘要:
  - `总问题数: 3`
  - `debug_code: 1`, `code_style: 1`, `hardcoded_constants: 1`
  - style 已切换到下一批文件：
    - `src/fpdev.cmd.fpc.pas`
    - `src/fpdev.cmd.package.repo.update.pas`
    - `src/fpdev.toolchain.pas`
- 命令: `bash scripts/run_all_tests.sh`
- 输出摘要: `Total 176 / Passed 176 / Failed 0 / Skipped 0`

### 下一批可执行优先级
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 6 | `src/fpdev.cmd.fpc.pas`, `src/fpdev.cmd.package.repo.update.pas`, `src/fpdev.toolchain.pas` | 新增测试 RED->GREEN，style 项继续收敛 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 降低 debug_code 噪音且行为不变 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量治理后回归通过 |

## Session 2026-02-12 Round 8: 全仓扫描结果与缺口

### 扫描命令
- `python3 scripts/analyze_code_quality.py`
- `rg -n "TODO|FIXME|XXX|TBD|HACK|WIP|未完成|待实现|待办" src tests scripts docs --glob '!docs/archive/**' --glob '!**/__pycache__/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests scripts docs --glob '!docs/archive/**' --glob '!**/__pycache__/**'`

### 结果摘要
1. 当前质量脚本输出仍为 `总问题数: 3`（`debug_code=1`, `code_style=1`, `hardcoded_constants=1`）。
2. `code_style` 明确命中 Batch 6 三文件（长行）：
   - `src/fpdev.cmd.fpc.pas`
   - `src/fpdev.cmd.package.repo.update.pas`
   - `src/fpdev.toolchain.pas`
3. `debug_code` 与 `hardcoded_constants` 仍是稳定存量组，适合作为 Batch 6 后的下一阶段任务。
4. TODO/FIXME 扫描命中以脚本/计划文档/roadmap 为主；“not implemented/stub/placeholder” 命中主要在 roadmap、注释与 i18n 文案，未发现新的高优先级阻塞项。

### 本轮可执行优先级计划
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 6 | `src/fpdev.cmd.fpc.pas`, `src/fpdev.cmd.package.repo.update.pas`, `src/fpdev.toolchain.pas` | 新增测试 RED->GREEN 且 style 从这三文件迁移 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出和用户输出，减少 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量抽离并保持行为不变 |

## Session 2026-02-12 Round 8: Batch 6 执行结果（严格 TDD）

### RED
- 命令: `python3 -m unittest tests/test_style_regressions_batch6.py -v`
- 输出要点:
  - `FAILED (failures=3)`
  - `src/fpdev.cmd.fpc.pas` 超长行: 3 处（77/387/523）
  - `src/fpdev.cmd.package.repo.update.pas` 超长行: 1 处（27）
  - `src/fpdev.toolchain.pas` 超长行: 1 处（245）

### GREEN
- 修改:
  - `src/fpdev.cmd.fpc.pas`: 3 处长行换行（签名 + 路径拼接）
  - `src/fpdev.cmd.package.repo.update.pas`: `FindSub` 单行展开（保留 `if AName <> '' then;` 语义）
  - `src/fpdev.toolchain.pas`: `ProbeFirstAvailable` 签名换行
- 命令: `python3 -m unittest tests/test_style_regressions_batch6.py -v`
- 输出: `Ran 3 tests in 0.002s` + `OK`

### VERIFY
- 命令: `python3 scripts/analyze_code_quality.py`
- 输出摘要:
  - `总问题数: 3`
  - `debug_code: 1`, `code_style: 1`, `hardcoded_constants: 1`
  - style 已切换到下一批文件：
    - `src/fpdev.fpc.interfaces.pas`
    - `src/fpdev.cmd.package.install_local.pas`
    - `src/fpdev.resource.repo.pas`
- 命令: `bash scripts/run_all_tests.sh`
- 输出摘要: `Total 176 / Passed 176 / Failed 0 / Skipped 0`

### 下一批可执行优先级
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 7 | `src/fpdev.fpc.interfaces.pas`, `src/fpdev.cmd.package.install_local.pas`, `src/fpdev.resource.repo.pas` | 新增测试 RED->GREEN，style 项继续收敛 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 降低 debug_code 噪音且行为不变 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量治理后回归通过 |

## Session 2026-02-12 Round 9: 全仓扫描结果与缺口

### 扫描命令
- `python3 scripts/analyze_code_quality.py`
- `rg -n "TODO|FIXME|XXX|TBD|HACK|WIP|未完成|待实现|待办" src tests scripts docs --glob '!docs/archive/**' --glob '!**/__pycache__/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests scripts docs --glob '!docs/archive/**' --glob '!**/__pycache__/**'`

### 结果摘要
1. 当前质量脚本输出仍为 `总问题数: 3`（`debug_code=1`, `code_style=1`, `hardcoded_constants=1`）。
2. `code_style` 明确命中 Batch 7 三文件：
   - `src/fpdev.fpc.interfaces.pas`（行尾空格）
   - `src/fpdev.cmd.package.install_local.pas`（长行）
   - `src/fpdev.resource.repo.pas`（长行）
3. `debug_code` 与 `hardcoded_constants` 仍是稳定存量组。
4. TODO/FIXME 与 stub/placeholder 命中仍以文档/注释为主，暂无新的高优先级阻塞项。

### 本轮可执行优先级计划
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 7 | `src/fpdev.fpc.interfaces.pas`, `src/fpdev.cmd.package.install_local.pas`, `src/fpdev.resource.repo.pas` | 新增测试 RED->GREEN 且 style 从这三文件迁移 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出和用户输出，减少 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量抽离并保持行为不变 |

## Session 2026-02-12 Round 9: Batch 7 执行结果（严格 TDD）

### RED
- 命令: `python3 -m unittest tests/test_style_regressions_batch7.py -v`
- 输出要点:
  - `FAILED (failures=3)`
  - `src/fpdev.fpc.interfaces.pas` 行尾空白: 13 处
  - `src/fpdev.cmd.package.install_local.pas` 长行: 1 处（27）
  - `src/fpdev.resource.repo.pas` 长行: 1 处（1060）

### GREEN
- 修改:
  - `src/fpdev.fpc.interfaces.pas`: 清理行尾空白
  - `src/fpdev.cmd.package.install_local.pas`: `FindSub` 单行展开（保留 `if AName <> '' then;` 语义）
  - `src/fpdev.resource.repo.pas`: `GetCrossToolchainInfo` 签名换行
- 命令: `python3 -m unittest tests/test_style_regressions_batch7.py -v`
- 输出: `Ran 3 tests in 0.001s` + `OK`

### VERIFY
- 命令: `python3 scripts/analyze_code_quality.py`
- 输出摘要:
  - `总问题数: 3`
  - `debug_code: 1`, `code_style: 1`, `hardcoded_constants: 1`
  - style 已切换到下一批文件：
    - `src/fpdev.cmd.project.template.list.pas`
    - `src/fpdev.registry.retry.pas`
    - `src/fpdev.git2.pas`
- 命令: `bash scripts/run_all_tests.sh`
- 输出摘要: `Total 176 / Passed 176 / Failed 0 / Skipped 0`

### 下一批可执行优先级
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 8 | `src/fpdev.cmd.project.template.list.pas`, `src/fpdev.registry.retry.pas`, `src/fpdev.git2.pas` | 新增测试 RED->GREEN，style 项继续收敛 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 降低 debug_code 噪音且行为不变 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量治理后回归通过 |

## 2026-03-09 Planning Switch + Isolation Findings

### Requirements
- 按 `planning-with-files` 改变工作方式，采用大块计划、大块实现。
- 继续在 `/home/dtamade/projects/fpdev` 内推进，不扩散到兄弟仓库。
- 默认直接推进，不频繁打断用户。
- 当前优先波次：测试配置隔离与环境污染治理。

### Research Findings
- 当前规划文件已存在，但需要补记本轮 session catchup 与新批次目标。
- `planning-with-files` 明确要求：复杂任务必须维护 `task_plan.md`、`findings.md`、`progress.md`，并在恢复会话后先同步差异。
- catchup 显示上一会话和当前规划文件之间存在大量未同步上下文，需以当前仓库实际状态和最新测试基线为准继续推进。
- 最新可靠验证基线：`bash scripts/run_all_tests.sh` = `216/216` passed。
- 下一大波最合适目标仍是“剩余 `Create('')` / 默认配置路径测试点收口”，因为此前已完成 helper 基础设施与两条关键回归测试。

### Decisions
| Decision | Rationale |
|----------|-----------|
| 继续把测试隔离作为本批次主线 | 相比再拆产品代码，回报更直接，能进一步降低用户环境污染风险 |
| 先分类剩余调用点，再成批修改 | 避免把本就安全的内存型构造误判成风险点 |
| 维持“focused + full suite”双层验证 | 当前仓库规模大，单靠 focused 不足以支撑完成声明 |

### Issues Encountered
| Issue | Resolution |
|-------|------------|
| catchup 脚本不可直接执行 | 使用 `python3` 调用脚本解释器 |

### Resources
- `/home/dtamade/.codex/skills/planning-with-files/SKILL.md`
- `task_plan.md`
- `findings.md`
- `progress.md`
- `tests/test_config_isolation.pas`
- `tests/test_temp_paths.pas`
- `tests/test_cmd_env.lpr`
- `tests/test_cli_fpc_lifecycle.lpr`

### Visual/Browser Findings
- 无 browser 内容；本轮主要来自本地技能文档、git diff 与规划文件同步。

### Research Findings
- `mcp__ace-tool__search_context` 在本轮两次调用均返回 `Transport closed`，当前批次改用 `rg` 做精确扫描与人工分类。

### Issues Encountered
| Issue | Resolution |
|-------|------------|
| `search_context` 两次返回 `Transport closed` | 降级到 `rg` 精确扫描；后续如需更深语义检索再单独重试 |

### Research Findings
- 剩余 `TConfigManager.Create('')` 站点大多已因 `test_config_isolation` import 而安全，或属于 `TFPCCfgManager.Create('')` 这种纯内存型测试，不会落真实用户配置目录。
- 当前这波真正值得收口的是“无参 `TDefaultCommandContext.Create` 出现在命令测试里”的场景，集中在：
  - `tests/test_config_list.lpr`
  - `tests/test_cmd_cache.lpr`
  - `tests/test_cmd_index.lpr`
  - `tests/test_cmd_env.lpr`
  - `tests/test_cmd_cross_build.lpr`
  - `tests/test_cmd_perf.lpr`
- `tests/test_cmd_env.lpr` 还适合作为默认 context 隔离的回归承载点，因为它已经有 explicit config path 测试。

### Research Findings
- 这波完成后，命令测试里无参 `TDefaultCommandContext.Create` 已统一纳入 `test_config_isolation` 保护。
- 新增回归证明：在引入 helper 的测试进程内，默认 `TDefaultCommandContext.Create` 会解析到系统临时目录下的隔离配置路径，而不是用户真实配置目录。
- 全量测试基线保持不变：`216/216` passed。

### Research Findings
- 仓库根目录当前仍有 `1689` 个 `test_archive_cleanup_*` 残留目录。
- 源头已定位到 `tests/test_logger_integration.lpr:353`，该文件使用相对路径在仓库根目录创建临时目录，并通过自写 `CleanupTestDir` 做浅层清理；对子目录 `archive/` 只调用 `RemoveDir`，导致非空目录无法删净。
- 同一文件中多个测试 (`test_logger_integration_` / `test_full_pipeline_` / `test_multi_rotation_` / `test_levels_rotation_` / `test_archive_cleanup_` / `test_concurrent_` / `test_output_toggle_`) 都在仓库根目录直接造目录，适合整文件迁移到 `test_temp_paths` helper。

### Research Findings
- `tests/test_logger_integration.lpr` 已迁移到 `test_temp_paths`，不再在仓库根目录创建 `test_full_pipeline_*` / `test_archive_cleanup_*` 目录。
- 历史残留 `test_full_pipeline_*` 与 `test_archive_cleanup_*` 已清零。
- 根目录剩余脏目录热点已缩窄为：
  - `test_run_temp_*` ≈ 396（对应 `tests/test_project_run.lpr`）
  - `test_testcmd_temp_*` ≈ 361（仍需单独 tracing）
  - `test_current_root_*` ≈ 115（对应 `tests/test_fpc_current.lpr`）
- 文档中的测试数量口径当前已统一到 `216`，但仍是多处硬编码，不是自动生成。
- 入口职责问题相较先前已显著改善：`src/fpdev.lpr` 当前仅 `86` 行，主要剩余关注点转向“默认 context 注入可测试性”。
- 当前最大的代码热点已转移到：`src/fpdev.fpc.installer.pas` (`1241` 行)、`src/fpdev.cmd.package.pas` (`1237` 行)、`src/fpdev.config.managers.pas` (`1166` 行)、`src/fpdev.resource.repo.pas` (`1160` 行)、`src/fpdev.cmd.fpc.pas` (`1137` 行)、`src/fpdev.cmd.lazarus.pas` (`1091` 行)、`src/fpdev.build.manager.pas` (`1032` 行)。

### Research Findings
- `tests/test_project_run.lpr`、`tests/test_project_clean.lpr`、`tests/test_project_test.lpr`、`tests/test_fpc_current.lpr` 现在统一通过 `test_temp_paths` 创建与回收临时目录；focused run 证明不会再增长 `test_run_temp_*` / `test_current_root_*` / `test_testcmd_temp_*`。
- `tests/test_structured_logger.lpr` 与 `tests/test_log_rotation.lpr` 也已迁移到 `test_temp_paths`，不再向仓库根目录写 `test_logs` / `test_rotation_logs`。
- 历史残留目录已清理；最终在完整跑完 `bash scripts/run_all_tests.sh` 后，仓库根目录 `test_*` / `fpdev_*` / `tmp_*` 目录数为 `0`。
- `test_testcmd_temp_*` 在本轮 focused 回归中不再增长，说明当前工作树里的直接源头已消失，剩余目录主要是历史垃圾而非当前测试继续制造。
- 下一批最值得做的两项仍是：
  - 把 README / docs 里的 `216` 改成自动生成，避免再次失真。
  - 持续拆大文件热点，优先 `src/fpdev.fpc.installer.pas`、`src/fpdev.cmd.package.pas`、`src/fpdev.resource.repo.pas`。

### Research Findings
- `scripts/update_test_stats.py` 已经是当前测试口径同步脚本，但生成逻辑仍主要依赖正则替换，缺少显式生成区块标记。
- 现状并非完全健康：`python3 scripts/update_test_stats.py --check` 当前直接失败，至少 `docs/testing.md` 已 out-of-sync。
- 这意味着“数量口径自动生成”基础已经存在，但还不够稳：既容易被手工编辑漂移，也不容易从文档结构上看出哪些内容是生成的。

### Research Findings
- `scripts/update_test_stats.py --check` 原先会因为 `docs/testing.md` 中“as of <today>”与 `Last Updated` 的日期滚动而在新的一天自发失败，这是比“手写数字分散”更底层的稳定性问题。
- 现已修复为稳定生成：测试数量变化才会导致 out-of-sync，不会因为日期变更而每天红灯。
- README 与 `docs/testing.md` 现已用显式 marker 区块包住可安全标记的生成内容：
  - `README.md` / `README.en.md`: `TEST-INVENTORY-BADGE`, `TEST-INVENTORY-SUMMARY`
  - `docs/testing.md`: `TEST-INVENTORY-COVERAGE`, `TEST-INVENTORY-FOOTER`
- README 状态代码块中的“Discoverable test programs”一行仍保留正则更新，而不是 marker，因为 HTML 注释放进 fenced code block 会直接出现在渲染结果里。
- 新增 `tests/test_update_test_stats.py`，覆盖 marker block 替换、`render_testing_md` 的稳定性，以及 README 生成逻辑。
- 当前验证结果：
  - `python3 -m unittest discover -s tests -p 'test_update_test_stats.py'` 通过
  - `python3 scripts/update_test_stats.py --check` 通过
  - `python3 scripts/update_test_stats.py --count` 输出 `216`
  - `bash scripts/run_all_tests.sh` 仍为 `216/216 passed`
  - 仓库根目录 temp-like 目录仍为 `0`

## 2026-03-09 Installer Campaign Findings

### Scope Reset
- 当前长期主线明确收敛到 `src/fpdev.fpc.installer.pas`，本轮不再扩散到 docs / inventory / 其他 side wave。
- `mcp__ace-tool__search_context` 再次尝试时 transport closed，因此本轮 installer 分析改用本地源码审阅；后续可再补 semantic scan。

### Responsibility Map
- `TFPCBinaryInstaller` 目前混合了承担 6 类职责：安装路径/环境注册、repo 安装尝试、legacy SourceForge 下载、manifest 缓存与 target 解析、归档下载/解压、安装后 config/cache 收尾。
- 已有切片：`src/fpdev.fpc.installer.extract.pas` 负责多层归档查找/解压，`src/fpdev.fpc.installer.config.pas` 负责编译器 wrapper 与 `fpc.cfg` 生成。
- 尚未切开的高耦合热点是 `InstallFromManifest`：它同时做 manifest cache 读取、target 选择、临时路径构建、下载 orchestration、解压 orchestration。

### First Extraction Decision
- 第一刀选择抽离 `manifest install plan helper`，目标是把 `InstallFromManifest` 的“manifest/cache/target/temp-path 规划”整体迁出到新 helper 单元。
- 新 helper 预计提供离线可测的 plan 构造能力：基于隔离的 manifest cache 文件解析目标平台、生成下载/解压临时路径，并把错误收敛为明确字符串。
- 这样可保留 `TFPCBinaryInstaller` 作为 orchestrator，只负责日志、下载调用、解压调用和收尾 cleanup。

## 2026-03-09 Installer Campaign Findings (Manifest Plan Slice Result)

### What Landed
- `src/fpdev.fpc.installer.manifestplan.pas` 现在承接 manifest 安装准备阶段：
  - 从 config/install-root 推导 scoped manifest cache 目录；
  - 从 cache 加载 `fpc.json`；
  - 解析当前 platform 的 target；
  - 规划 download/extract 临时路径。
- `src/fpdev.fpc.installer.pas` 的 `InstallFromManifest` 已从“解析 + 规划 + orchestration”降到“日志 + Fetch + Extract + cleanup”。
- manifest extract 临时目录 cleanup 已改为 `DeleteDirRecursive`，避免多层解压后 `RemoveDir` 留下空壳或残留子目录。

### Validation Notes
- 新 helper 可完全离线测试，只需写入 scoped cache 下的 `fpc.json` fixture。
- 新增顶层测试后 discoverable test count 从 `216` 升到 `217`，因此必须同步 `README.md`、`README.en.md`、`docs/testing.md` 生成区块，避免 `update_test_stats.py --check` 失败。

### Next Candidate Seams
1. `InstallFromBinary` 的 post-install 收尾仍混合了 `fpc.cfg` 生成、environment setup、cache save，可抽成 `postinstall helper`。
2. `TryInstallFromRepo` 仍内嵌 repo 初始化与错误输出，可抽成 `repo helper` / `repo session`。
3. `InstallFromSourceForge` 仍保留平台分支和临时目录处理，后续可与 manifest flow 共享 cleanup/path helper。

## 2026-03-09 Installer Campaign Findings (Post-Install Slice Result)

### What Landed
- `src/fpdev.fpc.installer.postinstall.pas` 现在承接 binary install 成功后的 post-install 收尾：
  - 条件性生成 wrapper / `fpc.cfg`；
  - environment setup 回调；
  - completion summary 输出；
  - cache save（受 `--no-cache` 控制）。
- `src/fpdev.fpc.installer.pas` 的 `InstallFromBinary` 已进一步降为“安装链路分发 + post-install helper 调用”，主流程更接近 orchestrator。

### Validation Notes
- 新 helper 可离线回归：用真实 temp install tree + `TBuildCache` + 假 `SetupEnvironment` 回调即可覆盖 config generation / cache / warning 路径。
- 新增顶层测试后 discoverable test count 从 `217` 升到 `218`，README/docs 已同步。

### Next Candidate Seams
1. `TryInstallFromRepo`：抽 repo session/helper，收掉初始化、mirror config 和错误报告。
2. `InstallFromSourceForge`：抽 legacy download/extract helper，统一 temp path / cleanup 行为。
3. `ExtractArchive`：平台分支与用户提示仍很厚，可继续向 extract family 下沉。

## 2026-03-09 Installer Campaign Findings (Repo Flow Slice Result)

### What Landed
- `src/fpdev.fpc.installer.repoflow.pas` 现在承接 fpdev-repo 安装流程：
  - repo init；
  - binary release 命中判断；
  - repo install 调用；
  - fallback 提示与错误输出。
- `src/fpdev.fpc.installer.pas` 新增轻量 wrapper：
  - `EnsureResourceRepoInitialized`
  - `RepoHasBinaryRelease`
  - `RepoInstallBinaryRelease`
- `TryInstallFromRepo` 已收口为 helper 调用，installer 主类继续朝 orchestration-only 演进。

### Validation Notes
- 新 helper 通过 callback-based 设计实现离线测试，不需要真实 `TResourceRepository` / 网络仓库。
- 本轮全量回归中出现过一轮 `Disk Full / No space left on device` 假阴性；清理 stale build session 与 `bin/lib` 后，重跑恢复 `219/219 passed`。这说明问题是环境噪音，不是本次代码回归。

### New Review Suggestion
- `scripts/run_all_tests.sh` 可以考虑增加 `Disk Full/No space left on device` 检测与一次受控清理重试（例如清理 `bin/lib` 和 stale `fpdev-tests.*`），减少这种环境假阴性打断自治节奏。

### Next Candidate Seams
1. `InstallFromSourceForge`：抽 legacy download/extract helper，统一 temp path / cleanup。
2. `ExtractArchive`：继续把平台分支与提示文案下沉到 extract family。
3. `scripts/run_all_tests.sh`：补环境恢复分支，降低全量回归脆弱性。

## 2026-03-09 Installer Campaign Findings (SourceForge Flow Slice Result)

### What Landed
- `src/fpdev.fpc.installer.sourceforgeflow.pas` 现在承接 SourceForge fallback flow：
  - download；
  - Linux extract temp dir 创建/递归清理；
  - Windows/macOS 手动安装提示；
  - install verification 与失败指导输出。
- `src/fpdev.fpc.installer.pas` 新增 `ExtractSourceForgeLinuxTarball` wrapper，并将 `InstallFromSourceForge` 收口为 helper 调用。
- 这让 installer 的 3 条安装分支都已经有独立 helper：manifest / repo / sourceforge / post-install。

### Validation Notes
- 新 helper 可完全离线测试：用 fake download/extract callback 即可覆盖 success、download failure、extract failure、verify failure。
- 新增顶层测试后 discoverable test count 从 `219` 升到 `220`，README/docs 已同步。

### Next Candidate Seams
1. `src/fpdev.fpc.installer.pas:704` `ExtractArchive`：继续下沉平台分支与提示文案，减少 installer 中的条件编译噪音。
2. `src/fpdev.fpc.installer.pas:826` `InstallFromBinary`：主流程仍包含 fallback order 与 summary 输出，可再抽一个 install orchestration helper。
3. `scripts/run_all_tests.sh`：补 `Disk Full` 环境恢复分支，降低全量回归假阴性。

## 2026-03-09 Installer Campaign Findings (Archive Flow Slice Result)

### What Landed
- `src/fpdev.fpc.installer.archiveflow.pas` 现在承接 generic archive dispatch：
  - missing file 校验；
  - zip / tar / tar.gz 分发与输出；
  - `.exe` / `.dmg` 手动安装提示；
  - unsupported format 错误输出。
- `src/fpdev.fpc.installer.pas` 新增 3 个轻量 wrapper：
  - `ExtractZipArchive`
  - `ExtractTarArchive`
  - `ExtractTarGzArchive`
- `ExtractArchive` 已收口为 helper 调用，installer 内部的条件分支和 `TUnZipper`/`tar` 调用显著减少。

### Validation Notes
- 新 helper 通过 callback-based 设计完成纯离线回归；不依赖真实 zip/tar 执行即可验证 dispatch/output/error 契约。
- 新增顶层测试后 discoverable test count 从 `220` 升到 `221`，README/docs 已同步。

### Next Candidate Seams
1. `src/fpdev.fpc.installer.pas:728` `InstallFromBinary`：将 fallback order、summary 输出再抽一层 orchestration helper，installer 主流程会进一步收缩。
2. `scripts/run_all_tests.sh`：补 `Disk Full` 环境恢复分支，降低全量回归的环境假阴性。
3. `src/fpdev.cmd.fpc.pas`：它和 installer 仍有一部分遗留重复逻辑，可在 installer campaign 收口后做第二战场整合。

## 2026-03-09 Installer Campaign Findings (Binary Flow Slice Result)

### What Landed
- `src/fpdev.fpc.installer.binaryflow.pas` 现在承接 binary install orchestration：
  - 安装 header / target / platform 输出；
  - manifest → fpdev-repo → SourceForge fallback chain；
  - SourceForge success summary；
  - callback 异常兜底错误输出。
- `src/fpdev.fpc.installer.pas` 的 `InstallFromBinary` 现在只负责：
  - 解析 install path；
  - 解析 platform；
  - 调用 binary flow helper；
  - 触发 post-install helper。
- `src/fpdev.fpc.installer.pas` 行数从 `978` 进一步降到 `929`。

### Validation Notes
- 新增 `tests/test_fpc_installer_binaryflow.lpr`，通过 callback probe 离线覆盖 orchestration 行为，不依赖真实下载/仓库。
- 新增顶层测试后 discoverable test count 从 `221` 升到 `222`，README/docs 已同步。
- 全量回归通过，根目录 temp-like 目录保持 `0`。

### Current Review Readout
1. `InstallFromManifest` 仍然偏厚：manifest load / fetch / extract / cleanup / nested extract validation 混在一起，下一刀适合做 manifest runtime helper。
2. `ExtractNestedFPCPackage` 仍是独立厚块：目录扫描、archive 搜索、base package 二段 extraction、post-validate 可独立抽成 nested extract helper。
3. `DownloadBinaryLegacy` + `GetBinaryDownloadURLLegacy` 仍保留老式 SourceForge URL/下载职责，适合后续收成 legacy download helper。
4. `build.manager` 之前计划中的两刀已收敛完成：`Preflight` 已委托 `fpdev.build.preflight.pas`，phase runner 已委托 `fpdev.build.pipeline.pas`，当前主战场可继续留在 installer campaign。

### Next Candidate Waves
1. Manifest Execution Wave：抽 `InstallFromManifest` 运行态 helper，收掉 fetch / extract / cleanup orchestration。
2. Nested Package Wave：抽 `ExtractNestedFPCPackage` helper，隔离多层 archive 搜索和 post-validate。
3. Legacy Download Wave：抽旧版 SourceForge URL + download helper，进一步压缩 installer 尾部兼容逻辑。

## 2026-03-09 Installer Campaign Findings (Manifest Execution Wave Result)

### What Landed
- `src/fpdev.fpc.installer.manifestflow.pas` 现在承接 manifest install runtime flow：
  - manifest load guidance / error routing；
  - target summary output（platform / mirrors / hash / size）；
  - download / outer extract orchestration；
  - download file + extract dir cleanup；
  - exception handling。
- `src/fpdev.fpc.installer.nestedflow.pas` 现在承接 nested package flow：
  - extracted subdir 发现；
  - binary archive / base archive 搜索；
  - direct extraction fallback；
  - post-extraction validation。
- `src/fpdev.fpc.installer.pas` 只保留薄 wrapper：
  - `PrepareManifestInstallPlan`
  - `FetchManifestDownload`
  - `ExtractNestedFPCPackage`
  - `InstallFromManifest`
- installer 主文件从 `929` 行进一步降到 `809` 行。

### Validation Notes
- 新增 `tests/test_fpc_installer_manifestflow.lpr`，离线覆盖 manifest success、manifest load failure、generic prepare error、download failure、outer extract failure、exception path。
- 新增 `tests/test_fpc_installer_nestedflow.lpr`，离线覆盖 nested success、direct fallback、nested/base failure、post-validation failure。
- 新增顶层测试后 discoverable test count 从 `222` 升到 `224`，README/docs 已同步。
- 全量回归通过，根目录 temp-like 目录保持 `0`。

### Current Review Readout
1. `DownloadBinaryLegacy` + `GetBinaryDownloadURLLegacy` 仍是 installer 中最厚的兼容下载块，下一波适合做 legacy download helper。
2. `VerifyChecksum` 仍直接混在 installer 中，可和 legacy download/URL/path 规划一起收成 download-verify wave。
3. `SetupEnvironment` 体量不大，但和 post-install/helper 路径存在天然耦合；等 legacy download wave 完成后，再看是否把 toolchain record 构造下沉为 env helper。

### Next Candidate Waves
1. Legacy Download Wave：抽 `GetBinaryDownloadURLLegacy` / `DownloadBinaryLegacy` / temp-file planning，隔离 HTTP 与平台后缀细节。
2. Download Verify Wave：把 `VerifyChecksum` 和 legacy download path 组合成更完整的 download/verify helper 家族。
3. Environment Registration Wave：若需要进一步瘦身，再抽 `SetupEnvironment` 里的 `TToolchainInfo` 构造与配置写入。

## 2026-03-09 Installer Campaign Findings (Legacy Download + Verify Wave Result)

### What Landed
- `src/fpdev.fpc.installer.downloadflow.pas` 现在承接 legacy binary download/verify 家族：
  - SourceForge URL resolve；
  - platform-specific file extension 选择；
  - temp download path planning；
  - download orchestration 与 partial-file cleanup；
  - checksum verify 输出。
- `src/fpdev.fpc.installer.pas` 中 `GetBinaryDownloadURLLegacy`、`DownloadBinaryLegacy`、`VerifyChecksum` 现在都已收口到 helper；installer 仅保留：
  - 实际 HTTP GET wrapper；
  - SHA256 计算 wrapper。
- installer 主文件从 `809` 行进一步降到 `752` 行。

### Validation Notes
- 新增 `tests/test_fpc_installer_downloadflow.lpr`，离线覆盖 URL/plan、download success/failure/exception、verify success/missing-file/empty-hash。
- 新增顶层测试后 discoverable test count 从 `224` 升到 `225`，README/docs 已同步。
- 全量回归通过，根目录 temp-like 目录保持 `0`。

## 2026-03-09 Installer Campaign Findings (Environment Registration Wave Result)

### What Landed
- `src/fpdev.fpc.installer.environmentflow.pas` 现在承接 installed toolchain registration：
  - `TToolchainInfo` 构造；
  - `fpc-<version>` naming；
  - add-toolchain 调用；
  - add failure / exception error routing。
- `src/fpdev.fpc.installer.pas` 的 `SetupEnvironment` 已缩成 path resolve + helper delegate。
- `src/fpdev.cmd.fpc.pas` 的重复 `SetupEnvironment` 逻辑已复用同一 helper，消除 duplicated registration block。
- `src/fpdev.fpc.installer.pas` 继续保持在 `752` 行级别，而不是重新长回去。

### Validation Notes
- 新增 `tests/test_fpc_installer_environmentflow.lpr`，离线覆盖 info mapping、success、empty version、missing dir、add failure、exception path。
- 新增顶层测试后 discoverable test count 从 `225` 升到 `226`，README/docs 已同步。
- 全量回归通过，根目录 temp-like 目录保持 `0`。

### Current Review Readout
1. installer 主文件现在剩余的“厚方法”主要是 IO wrappers：`ExecuteLegacyBinaryHTTPGet`、`ExtractZipArchive`、`ExtractTarArchive`、`ExtractTarGzArchive`。这些已经偏 infrastructure/bridge，不再是 orchestration 块。
2. 结构上更值得关注的下一主战场已从 installer 转向 `src/fpdev.cmd.package.pas` / `src/fpdev.build.manager.pas` 之外的高重复点，尤其是 command-side duplicated helper/wrapper 逻辑。
3. 若继续留在 installer 主线，下一波可以做 `IO Bridge Wave`：把 HTTP/tar/zip wrappers 统一抽到 transport/extract bridge helper，令 `TFPCBinaryInstaller` 近乎纯 facade。
4. 若切回高收益主战场，建议回到 package command 大文件，继续做 query/view/installflow/publishflow 拆分。

### Next Candidate Waves
1. Installer IO Bridge Wave：抽 HTTP download bridge 与 archive extraction bridge，进一步清空 installer 内部 IO 细节。
2. Package Command Wave：继续压 `src/fpdev.cmd.package.pas`，优先 query/view/installflow/publishflow 方向。
3. Test Harness Wave：给 `scripts/run_all_tests.sh` 增加 `Disk Full` 检测和受控重试，减少环境假阴性。

## 2026-03-09 Installer Campaign Findings (IO Bridge Wave Result)

### What Landed
- `src/fpdev.fpc.installer.iobridge.pas` 现在承接 installer 底层 IO bridge：
  - local/remote HTTP file download；
  - ZIP extraction；
  - TAR extraction；
  - TAR.GZ extraction。
- `src/fpdev.fpc.installer.pas` 中原先较厚的 bridge wrappers 已收成单行 delegate：
  - `ExecuteLegacyBinaryHTTPGet`
  - `ExtractZipArchive`
  - `ExtractTarArchive`
  - `ExtractTarGzArchive`
- installer 主文件从 `733` 行进一步降到 `651` 行左右（当前 `wc -l` 为 `651` if re-counted after final save; earlier focused count showed low-700 band before this final wave, and structure now只剩 orchestration + thin wrappers）。

### Validation Notes
- 新增 `tests/test_fpc_installer_iobridge.lpr`，用本地 Python HTTP server + temp zip/tar/targz fixture 离线覆盖 bridge 行为。
- 新增顶层测试后 discoverable test count 从 `226` 升到 `227`，README/docs 已同步。
- 全量回归通过，根目录 temp-like 目录保持 `0`。

### Current Review Readout
1. `TFPCBinaryInstaller` 现在几乎只剩 orchestration 与 facade wrapper，installer campaign 的结构化目标基本达成。
2. 接下来更高收益的主战场已经转移到超大 command 单元，尤其是 `src/fpdev.cmd.package.pas`。
3. 若还留在 installer 域，收益会明显递减，更多是微型 facade/bridge 清洁，而不是高杠杆结构收益。

### Next Candidate Waves
1. Package Command Wave：继续压 `src/fpdev.cmd.package.pas`，优先 query/view/installflow/publishflow 四块。
2. Test Harness Wave：给 `scripts/run_all_tests.sh` 增加 `Disk Full/No space left on device` 检测与一次受控 cleanup/retry。
3. CLI Entry Cohesion Wave：回看 `src/fpdev.lpr` 的 global param pre-parse / registry 双轨，做统一入口层。

## 2026-03-09 Batch: Package Command Wave (Lifecycle Slice)

### Recon
- `ace-tool/search_context` attempted first per repo rule, but failed with `Transport closed`.
- `src/fpdev.cmd.package.pas` remaining high-ROI orchestration seam is `TPackageManager.UninstallPackage` + `TPackageManager.UpdatePackage`.
- Existing helpers already cover install/download/query/info/publish metadata; lifecycle branch is still in main unit.
- Planned extraction target: new lifecycle helper that owns uninstall/update flow messages, warnings, delegate calls, and update-plan application.

## 2026-03-09 Package Command Wave (Lifecycle Slice)

- `ace-tool/search_context` 按仓库规则先尝试，但再次失败：`Transport closed`。
- `src/fpdev.cmd.package.pas` 剩余最厚且最容易独立测试的 seam 是 `TPackageManager.UninstallPackage` + `TPackageManager.UpdatePackage`。
- 新增 `src/fpdev.cmd.package.lifecycle.pas` 后，package 主单元已降到 `1188` 行；新增 helper 为 `156` 行。
- `UpdatePackageCore` 复用既有 `BuildPackageUpdatePlanCore`，负责 latest-version 选择、up-to-date 短路、uninstall/install delegate 编排以及错误 hint 输出。
- `UninstallPackageCore` 负责 not-installed 短路、install path 删除和 warning 输出。
- 调试发现 `tests/test_package_lifecycle_flow.lpr` 初版的 `TInterfacedObject` 输出 stub 被按接口参数临时持有后释放，导致对象指针悬空；根因是测试生命周期管理，不是生产代码问题。
- 通过在测试里显式保留 `IOutput` 接口引用修复悬空问题后，focused 与全量回归全部恢复为绿。
- 下一轮最高 ROI 仍然是 `src/fpdev.build.manager.pas:767` 的 preflight：issue collection / log formatting 已抽出，但 input assembly + env probing 还在 manager 本体里。
- 次高 ROI 是 `src/fpdev.cmd.fpc.pas:510` 的 `InstallVersion`，仍然串着已安装校验、cache restore、source install、post-setup 多条路径。
- 第三梯队是 `src/fpdev.resource.repo.pas:629` 的 bootstrap fallback chain，常量链与选择策略还压在主类方法里。

## 2026-03-09 Batch: Build Manager Flow Wave

### Recon
- `ace-tool/search_context` attempted first again, but failed with `Transport closed`.
- `src/fpdev.build.manager.pas` still keeps two orchestration-heavy zones:
  1. `Preflight` input assembly + env probing (`767` onward)
  2. `FullBuild` phase-runner setup / success log tail (`864` onward)
- Existing helpers already cover issue collection/log formatting (`src/fpdev.build.preflight.pas`) and generic phase execution (`src/fpdev.build.pipeline.pas`).
- Planned extraction targets: `preflightflow` for input assembly, `fullbuildflow` for phase-runner orchestration.

## 2026-03-09 Build Manager Flow Wave

- `ace-tool/search_context` 本轮按仓库规则继续优先尝试，但依旧失败：`Transport closed`。
- `src/fpdev.build.manager.pas` 在上一轮已把 preflight 的 issue collection / log formatting 抽到 `src/fpdev.build.preflight.pas`，本轮继续把剩余高 ROI orchestration 拆成两个 helper：
  - `src/fpdev.build.preflightflow.pas`：负责 strict/non-strict policy probing、make probing、sandbox/log dir ensure、writable probing、`TBuildPreflightInputs` 组装。
  - `src/fpdev.build.fullbuildflow.pas`：负责 `FullBuild` 的 start/end log、默认 phase sequence 构建、phase runner 执行、success summary。
- `src/fpdev.build.manager.pas` 现已降到 `990` 行，明显低于本轮前的 `1032` 行。
- `TBuildManager` 新增的 wrapper 只有三个很薄的 probe adapter：`DetectMakeAvailable`、`RunPreflightPolicyCheck`、`BuildToolchainReportJSONValue`。
- `BuildBuildPreflightInputsCore` 保持了原语义：strict 模式不探测 make，non-strict 模式不做 policy/json；只在 `AllowInstall=True` 时创建 sandbox dest 根目录，但始终计算 dest path/existence。
- `RunFullBuildCore` 复用了既有 `CreateDefaultBuildPhaseSequenceCore` / `ExecuteBuildPhaseSequenceCore`，没有重新定义 phase semantics；失败时仍由 pipeline helper 负责 abort log 与 step reset，成功时才写 fullbuild summary。
- 经过这一波后，`build.manager` 的剩余复杂度主要集中在具体 phase 实现方法本身，而不是 orchestration glue。
- 当前下一优先级已经转移到 `src/fpdev.cmd.fpc.pas:510` 的 `InstallVersion`，它仍然串着已安装验证、cache restore、source build、post-setup 多条路径。
- 次高优先级是 `src/fpdev.resource.repo.pas:629` 的 bootstrap fallback selection；常量链和选择策略依旧压在方法本体里。

## 2026-03-09 FPC InstallVersion Flow Wave

- `ace-tool/search_context` 本轮按规则继续优先尝试，但仍然失败：`Transport closed`。
- `TFPCManager.InstallVersion` 的高复杂度主要来自四条交织路径：
  1. already-installed verify short-circuit
  2. build cache restore fast path
  3. source build fallback path
  4. binary install path
- 新增 `src/fpdev.cmd.fpc.installversionflow.pas` 后，这四条路径都被放进纯 helper：
  - `ShouldReuseInstalledFPCVersionCore`
  - `BuildFPCInstalledExecutablePathCore`
  - `BuildFPCSourceInstallPathCore`
  - `ResolveFPCInstallPathCore`
  - `ExecuteFPCInstallVersionCore`
- `src/fpdev.cmd.fpc.pas` 中只补了一个很薄的 verifier adapter：`VerifyInstalledExecutableVersion`，其余通过现有 manager/service 方法直接作为 callbacks 传给 helper。
- `FBuildCache` 的 `HasArtifacts` / `RestoreArtifacts` / `SaveArtifacts` 可以直接作为 `of object` callbacks 传入，不需要额外 wrapper，这让 manager 收缩得更干净。
- `src/fpdev.cmd.fpc.pas` 当前降到 `1049` 行；虽然仍大于 1000，但最厚的 install orchestration 已经从 manager 本体移除。
- 新 focused 测试 `tests/test_fpc_installversionflow.lpr` 覆盖了：verify short-circuit、verify-fail->reinstall、cache fast path、cache miss build-and-cache、bootstrap failure。
- 下一优先级清晰转移到 `src/fpdev.resource.repo.pas:629`：bootstrap fallback chain 现在仍把版本常量链、required-version 定位和 fallback 选择策略压在方法本体里，且已经有 `tests/test_resource_repo_bootstrap.lpr` 可复用。
- 再下一梯队是 `src/fpdev.cmd.project.pas` / `src/fpdev.cmd.cross.pas` 这类 `1000+` 行 command 聚合单元，但相较之下，`resource.repo` 的 bootstrap selector 更适合下一刀快速见效。

## 2026-03-09 Resource Repo Bootstrap Selector Wave

- `ace-tool/search_context` 本轮按仓库规则继续优先尝试，但仍失败：`Transport closed`。
- `TResourceRepository.FindBestBootstrapVersion` 的高复杂度主要来自三段纯策略逻辑：required-version 缺省、fallback chain 向后回退、最后一档 any-available 兜底。
- 初版把 selector 抽到新单元 `src/fpdev.resource.repo.bootstrapselector.pas` 后，focused resource tests 通过，但若干大型 CLI/registry 工程在 lazbuild 链接阶段失败，表征为 `Failed to execute "/usr/bin/ld.bfd", error code: -7`。
- 真实根因不是 selector 逻辑错误，而是主依赖树新增单元后，部分大测试工程触发了平台级链接器脆弱点；因此最终方案不是回退抽离，而是把 selector helper 并回既有 `src/fpdev.resource.repo.bootstrap.pas`，保留职责切分同时不增加主依赖树单元数。
- `src/fpdev.resource.repo.pas` 现仅保留 required version / available versions gather、helper delegate、log replay 三步，selector 纯策略测试由 `tests/test_resource_repo_bootstrapselector.lpr` 单独覆盖。
- 这次经验说明：在 FP/Lazarus 大工程里，helper 抽离不只是“减行数”，还要把“是否增加主依赖树编译/链接压力”作为一等约束。
- 当前下一优先级更适合转向超大 command 聚合单元（`src/fpdev.cmd.project.pas`、`src/fpdev.cmd.cross.pas`），而不是继续在 `resource.repo` 上做更细碎的新增单元切片。

## 2026-03-09 Project Exec Flow Wave

- `ace-tool/search_context` 本轮按仓库规则继续优先尝试，但仍失败：`Transport closed`。
- `src/fpdev.cmd.project.pas` 的 `BuildProject` / `TestProject` / `RunProject` 三个方法，本质上都在重复做四件事：目录存在性校验、目标文件发现、参数准备、进程执行结果转译。
- 这块非常适合像前几波一样抽成一个 flow helper，而且不需要新增跨域依赖；helper 只依赖 `IOutput`、i18n strings 和 `TProcessResult`。
- 新 helper `src/fpdev.cmd.project.execflow.pas` 的高价值点，不只是减行数，而是把“文件发现/参数拆分/执行语义”集中成一处，后续 `project` / `lazarus` 类命令能复用同样的切法。
- `BuildProject` 仍保留 `RunDirect` 语义，继续避免 chatty build tools 的 pipe deadlock；本轮没有回退这个行为。
- `RunProject` 的参数拆分仍沿用原有 `ExtractStrings([' '], ...)` 语义，没有顺手引入引号解析新行为，避免无意改变 CLI 契约。
- 这波新增顶层 focused test 后 discoverable test count 从 `232` 升到 `233`，README/docs 已同步。
- 当前下一优先级最自然地转到 `src/fpdev.cmd.cross.pas`：其 `InstallTarget` / `EnableTarget` / `DisableTarget` / `TestTarget` / `BuildTest` / `ConfigureTarget` 仍是同一类“状态校验 + config mutation + output formatting”混杂方法。

## 2026-03-09 Cross Target Flow Wave

- `ace-tool/search_context` 本轮按仓库规则继续优先尝试，但仍失败：`Transport closed`。
- `src/fpdev.cmd.cross.pas` 的 `EnableTarget` / `DisableTarget` / `ConfigureTarget` / `TestTarget` / `BuildTest` 其实是一类高度重复的方法：读取 target config、做状态/路径校验、转成一条配置写回或一个执行动作、再把结果翻译成输出。
- 这类方法很适合一起收进一个 `targetflow` helper；比继续碎切 `install` 更稳，因为不牵涉 downloader / repo / manual hint 那条较长链。
- 新 helper `src/fpdev.cmd.cross.targetflow.pas` 把五个方法压成纯 orchestration core，同时保留 `cross` 现有 CLI 契约和输出文案。
- 本轮没有改动 `InstallTarget` / `UpdateTarget` 主逻辑，因此避免把 downloader、system compiler auto-detect、manual install hint 三条路径混在同一波里，提高了单波成功率。
- 这波还顺手收掉了新 helper 自己带来的 managed-type hint，并把前一波 `resource repo` selector 相关的同类初始化 hint 一并补齐。
- 经过 `project exec flow` + `cross targetflow` 两波后，超大 command 单元的高重复“状态校验 + 执行 + 输出”模式已经形成稳定切法，下一波最自然的是去收测试 harness，或者对 `lazarus` 做同构切片。


## 2026-03-09 Test Runner Resilience Wave

### Scope
- 目标：增强 `scripts/run_all_tests.sh` 对 transient/resource 类失败的韧性，尤其是 lazbuild“成功”但没生成可运行 binary 的脏成功场景；同时让脚本支持被单元测试直接 source。

### Changes
- `scripts/run_all_tests.sh`
  - 顶层流程改为 `main()` + guarded entry，source 时不再直接执行整套回归。
  - 新增 `SCRIPT_DIR` / `REPO_ROOT`，测试清单加载不再依赖当前工作目录。
  - 新增 `get_test_binary_candidates`、`cleanup_test_binary_candidates`、`has_valid_test_binary`、`build_test_with_recovery`。
  - 每次构建前先清掉候选 binary，避免旧产物掩盖“本次未生成 binary”的假绿。
  - lazbuild/fpc 返回成功后，显式校验 binary 是否存在且非零字节；若无效则清理产物与 `.compiled` 状态并重试一次。
  - `is_transient_build_failure` 新增 `No space left on device` / `Disk quota exceeded` 检测。
- `tests/test_run_all_tests.py`
  - 新增脚本级回归，覆盖 disk-full 识别、零字节 binary 成功重试、缺失 binary 后 fallback 到 fpc。
- `.github/workflows/ci.yml`
  - 新增 `python3 -m unittest discover -s tests -p 'test_*.py'`，把 Python 脚本回归纳入 CI。

### Why This Matters
- 之前 `run_all_tests.sh` 只要 `lazbuild` exit 0 就认为构建成功，若留下旧 binary、零字节 binary 或根本没产物，脚本可能误跑旧产物或直接把问题归类成 `SKIPPED (no binary)`，对 CI 诊断不够稳定。
- 脚本不可 source，导致这类 shell 编排逻辑只能靠整套 Pascal 回归“顺带覆盖”，修复成本偏高。
- 这次把恢复链和主流程拆开后，后续再补脚本级韧性回归会轻很多。

### Verify
- RED: `python3 -m unittest discover -s tests -p 'test_run_all_tests.py'` -> fail（修复前脚本无 guarded entry / 无 recovery helper）
- GREEN: `python3 -m unittest discover -s tests -p 'test_run_all_tests.py'` -> `3 tests` passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `79 tests` passed
- `bash scripts/run_all_tests.sh` -> `234/234` passed

### Next Review Suggestions
1. `src/fpdev.cmd.lazarus.pas:374`
   - `InstallVersion` 仍有两段几乎重复的 source build + env setup + configure 收尾，适合做类似 `project execflow` / `cross targetflow` 的 orchestration helper。
2. `src/fpdev.cmd.lazarus.pas:957`
   - `ConfigureIDE` 仍把 config root 解析、FPC path 推导、IDEConfig mutation、summary/output 混在一起，是下一块最肥的可测试 seam。
3. `src/fpdev.cmd.lazarus.pas:663` / `724`
   - `UpdateSources` / `CleanSources` 共享 version resolution + source dir existence 前置，适合先抽小 helper 做低风险预热。

## 2026-03-09 Lazarus Install/Configure Flow Wave

### Scope
- 目标：把 `TLazarusManager.InstallVersion` 中 source-install / env-setup / auto-config 编排，以及 `ConfigureIDE` 中 config path 推导、FPC path 推导、IDEConfig mutation，抽到可单测 helper。

### Changes
- `src/fpdev.cmd.lazarus.flow.pas`
  - 新增 `TLazarusInstallPlan` / `TLazarusConfigurePlan`。
  - 新增 `CreateLazarusInstallPlanCore`。
  - 新增 `ExecuteLazarusInstallPlanCore`。
  - 新增 `ResolveLazarusConfigDirCore`。
  - 新增 `CreateLazarusConfigurePlanCore`。
  - 新增 `ApplyLazarusConfigurePlanCore`。
- `src/fpdev.cmd.lazarus.pas`
  - `InstallVersion` 改为 validate/installed short-circuit + helper delegate。
  - `ConfigureIDE` 改为 output setup + plan build + helper delegate。
- `tests/test_lazarus_flow.lpr`
  - 新增 focused 回归，覆盖 requested/recommended FPC resolution、binary fallback warning、download failure、configure non-fatal warning、config dir resolution、real `TLazarusIDEConfig` 写入。
- `tests/test_update_test_stats.py`
  - 新增 `render_run_all_tests` 对 `mapfile` inventory loader 的回归。
- `scripts/update_test_stats.py`
  - `render_run_all_tests` 兼容旧 `TEST_FILES=...` 和新 `mapfile -t TEST_FILES < <(...)` 两种结构。
- `README.md` / `README.en.md` / `docs/testing.md`
  - discoverable test count 更新到 `235`。

### Why This Matters
- `InstallVersion` 之前有两段几乎相同的 source build 流程，唯一差别只是 binary-path fallback warning；这类复制非常适合抽 plan + execute helper。
- `ConfigureIDE` 之前同时承担路径推导、文件存在性探测、TLazarusIDEConfig mutation、summary 输出，review 和 targeted regression 都偏重。
- 前一波把 `run_all_tests.sh` 改成 `mapfile` loader 后，`update_test_stats.py --write` 不再能命中老正则；这次顺手补齐脚本兼容和 Python 回归，避免统计同步再次卡住。

### Verify
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_lazarus_flow.lpr` -> `Can't find unit fpdev.cmd.lazarus.flow`
- GREEN: `test_lazarus_flow`: `21/21` passed
- `test_lazarus_configure_workflow`: `6 passed, 0 failed`
- `test_cli_lazarus`: `89/89` passed
- `test_lazarus_commands`: `15/15` passed
- `python3 -m unittest discover -s tests -p 'test_update_test_stats.py'`: `4/4` passed
- `python3 -m unittest discover -s tests -p 'test_*.py'`: `80/80` passed
- `bash scripts/run_all_tests.sh`: `235/235` passed

### Next Review Suggestions
1. `src/fpdev.cmd.lazarus.pas:663` / `724`
   - `UpdateSources` / `CleanSources` 共享 `UseVersion` 解析与 `SourceDir` 组装，是一块低风险、适合继续薄化 manager 的 seam。
2. `src/fpdev.cmd.lazarus.pas:890`
   - `LaunchIDE` 仍在自己做 version fallback、install path/executable path 推导和进程启动输出，可继续 helper 化。
3. `src/fpdev.cmd.package.pas`
   - 经过前几波后依旧是 repo 内最重的 orchestration 聚合点之一，可以重新盘一轮剩余胖方法并定下一刀。

## 2026-03-09 Lazarus Runtime/Source Flow Wave

### Scope
- 目标：在既有 `lazarus flow` helper 基础上继续收 `UpdateSources` / `CleanSources` / `LaunchIDE`，把 version fallback、source-dir 路径、git 决策和 launch 输出变成 focused-testable core。

### Changes
- `src/fpdev.cmd.lazarus.flow.pas`
  - 新增 `TLazarusSourcePlan` / `TLazarusLaunchPlan`。
  - 新增 `CreateLazarusSourcePlanCore`。
  - 新增 `ExecuteLazarusUpdatePlanCore`。
  - 新增 `ExecuteLazarusCleanPlanCore`。
  - 新增 `CreateLazarusLaunchPlanCore`。
  - 新增 `ExecuteLazarusLaunchPlanCore`。
- `src/fpdev.cmd.lazarus.pas`
  - 新增薄 wrappers：`CleanSourceArtifacts`、`LaunchLazarusExecutable`。
  - `UpdateSources` 改为 source plan + `ExecuteLazarusUpdatePlanCore`。
  - `CleanSources` 改为 source plan + `ExecuteLazarusCleanPlanCore`。
  - `LaunchIDE` 改为 launch plan + `ExecuteLazarusLaunchPlanCore`。
- `tests/test_lazarus_runtimeflow.lpr`
  - 新增 focused 回归，覆盖 current-version fallback、git backend 缺失、local-only repo success、pull failure non-fatal、clean exception、launch no-version / not-installed / success。
- `README.md` / `README.en.md` / `docs/testing.md`
  - discoverable test count 更新到 `236`。

### Why This Matters
- `UpdateSources` / `CleanSources` / `LaunchIDE` 三个方法原本都各自做“有无显式版本 -> fallback 当前版本 -> 构造路径 -> 再决定流程”的重复前置逻辑，manager 可读性差。
- `UpdateSources` 的 git 行为本质是一个很稳定的决策树：无 backend=false、非 repo=false、无 remote=true、pull fail 也 true；这类逻辑最适合 focused regression 固定。
- `LaunchIDE` 之前没有 manager 级 focused 行为测试；这次把运行时路径与输出语义收进 helper 后，后续再动 CLI 不容易回归漂移。

### Verify
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_lazarus_runtimeflow.lpr` -> compile errors for missing runtime/source helper symbols
- GREEN: `test_lazarus_runtimeflow`: `19/19` passed
- `test_lazarus_flow`: `21/21` passed
- `test_lazarus_update`: `5 passed, 0 failed`
- `test_lazarus_clean`: `17 passed, 0 failed`
- `test_cli_lazarus`: `89/89` passed
- `python3 -m unittest discover -s tests -p 'test_*.py'`: `80/80` passed
- `bash scripts/run_all_tests.sh`: `236/236` passed

### Next Review Suggestions
1. `src/fpdev.cmd.package.pas`
   - 现在 `lazarus` 一组主要 orchestration seam 已经相对收薄，下一批性价比最高的目标重新回到 `package` 聚合单元。
2. `src/fpdev.cmd.lazarus.pas:707` / `772`
   - `ShowVersionInfo` 与 `TestInstallation` 还保留了路径/可执行文件推导，适合和 runtime helper 继续合并到 shared resolver。
3. `src/fpdev.cmd.fpc.pas`
   - 可以复盘剩余 install/update/test 管理路径，看是否还有类似 `lazarus` 这种轻量可抽的 runtime facade seam。

## 2026-03-09 Package Install/Update Manager Orchestration Wave

### What Changed
- `src/fpdev.cmd.package.lifecycle.pas`
  - 新增 install/update manager orchestration callback 类型：`TPackageNameValidator`、`TPackageInstalledChecker`、`TPackageInfoProvider`、`TPackageAvailableProvider`、`TPackageDependencyInstallAction`、`TPackageDownloadPlanBuilder`、`TPackageCachedDownloadAction`、`TPackageArchiveInstallAction`。
  - 新增 `ExecutePackageManagerInstallCore`，统一处理 installed short-circuit、dependency install、download plan、archive install 与 cleanup warning 输出。
  - 新增 `ExecutePackageManagerUpdateCore`，统一处理 package name 校验、installed 判定、installed version fallback 与 latest-version install delegate。
  - helper 内部显式固定 unknown version fallback 为 `0.0.0`，避免 manager 再拼装默认值。
- `src/fpdev.cmd.package.pas`
  - 新增薄 adapter：`BuildPackageDownloadPlan`、`EnsurePackageDownloaded`、`InstallPackageArchive`。
  - `InstallPackage` / `UpdatePackage` 退回 facade wrapper：只保留 config/path 准备、callback 组装与异常边界。
  - 修复 interface / implementation 同时引入 `fpdev.cmd.package.fetch` 导致的 duplicate identifier 编译错误。
- `tests/test_package_manager_installupdateflow.lpr`
  - 新增 focused 回归，覆盖 installed short-circuit、dependency failure fast-stop、cleanup warning、invalid package、missing install hint、unknown installed version fallback 六类行为。
- `README.md` / `README.en.md` / `docs/testing.md` / `.github/workflows/ci.yml`
  - 通过测试统计脚本同步 discoverable test count 到 `237`，收敛文档与 CI 口径。

### Why This Matters
- `InstallPackage` / `UpdatePackage` 之前同时承担 validation、依赖编排、下载计划、archive 安装与用户消息输出，测试 seam 很浅，任何变更都容易把 CLI 行为和 manager 内部实现绑死。
- 抽到 lifecycle helper 后，manager 层变成 callback orchestration，后续继续拆 `package` 大单元时可以沿着同一 seam 把 registry / uninstall / local-install 等行为平移出去。
- 本波也顺手把“测试数口径漂移”收回脚本生成，避免 README / docs / CI 再次出现 171 / 170 / 214 / 236 之类分叉。

### Fresh Evidence
- `./bin/test_package_manager_installupdateflow` -> `19/19` passed
- `./bin/test_cli_package` -> `223/223` passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `237/237` passed

## 2026-03-09 Build TestResults Flow Wave

### What Changed
- `src/fpdev.build.testresultsflow.pas`
  - 新增 `ExecuteBuildTestResultsCore`，统一处理 sandbox 结果校验、strict empty bin/lib 判定、verbose sample 输出、strict config delegate，以及 source-tree fallback 验证。
- `src/fpdev.build.manager.pas`
  - `TestResults` 改为薄 wrapper，只负责把 `FSandboxRoot`、`FAllowInstall`、`FStrictResults`、`FLogger.Verbosity` 与现有 callbacks 传给 helper。
  - 增加 `BuildManagerDirectoryExists` wrapper，规避 `DirectoryExists` 默认参数签名和 callback type 的不兼容。
- `tests/test_build_testresultsflow.lpr`
  - 新增 focused 回归，覆盖 sandbox success、missing root、strict empty bin、nonstrict empty lib、strict config failure、source fallback success、source fallback missing compiler。
- `README.md` / `README.en.md` / `docs/testing.md`
  - discoverable test count 经脚本同步到 `238`。

### Why This Matters
- `TestResults` 之前同时承担 sandbox 路径推导、文件系统探测、strict 分支、verbose log/sample、summary 输出和 source fallback，多职责混在 manager 内，不利于沿着现有 `preflightflow` / `fullbuildflow` 模式继续拆。
- 抽到 helper 后，`build.manager` 的主要 orchestration seam 更清晰：`Preflight`、`FullBuild`、`TestResults` 都已经具备独立 focused 回归，后面继续收 `resource.repo` 和 `cmd.fpc` 时可以直接复用同样的“helper + callback probe”套路。

### Fresh Evidence
- `./bin/test_build_testresultsflow` -> `29/29` passed
- `./bin/test_build_preflightflow` -> `21/21` passed
- `./bin/test_build_fullbuildflow` -> `12/12` passed
- `bash scripts/run_all_tests.sh` -> `238/238` passed

## 2026-03-09 Resource Repo Lifecycle / Manifest Flow Wave

### What Changed
- `src/fpdev.resource.repo.lifecycle.pas`
  - 新增 `ExecuteResourceRepoInitializeCore`，统一处理 existing repo short-circuit、optional pull、mirror fallback clone、manifest load delegate。
  - 新增 `ExecuteResourceRepoUpdateCore`，统一处理 uninitialized repo、force/auto update、manifest reload warning 和 up-to-date message。
  - 新增 `LoadResourceRepoManifestCore`，统一处理 manifest.json 读盘、JSON parse、state output 和日志输出。
  - 新增 `EnsureResourceRepoManifestLoadedCore`，统一 manifest cached short-circuit / reload delegate。
- `src/fpdev.resource.repo.pas`
  - 新增 `MarkUpdateCheckNow`，把 `FLastUpdateCheck := Now` 收口成单点 callback。
  - `Initialize` / `Update` / `LoadManifest` / `EnsureManifestLoaded` 现均退回 thin wrapper，只负责组装现有 git/log/state callbacks。
- `tests/test_resource_repo_lifecycleflow.lpr`
  - 新增 focused 回归，覆盖 existing repo refresh、mirror fallback clone、all-source clone failure、update on uninitialized repo、reload warning、fresh repo no-op、manifest parse success / missing file、cached ensure / delegated reload。
- `README.md` / `README.en.md` / `docs/testing.md`
  - discoverable test count 经脚本同步到 `239`。

### Why This Matters
- `TResourceRepository` 之前既承担 git lifecycle，又承担 manifest 文件 I/O / parse / state reset，和已经拆出去的 `bootstrap` / `package` / `cross` helper 风格不一致。
- 本波之后，`resource.repo` 的“repo 生命周期”和“manifest 状态管理”也进入 helper 化轨道，后续继续下沉 `status` / query 边界会更自然。
- 这也给下一波 `cmd.fpc` 提供了现成模式：shared source path / version resolution / output emission 都可以走同类 callback helper。

### Fresh Evidence
- `./bin/test_resource_repo_lifecycleflow` -> `38/38` passed
- `./bin/test_resource_repo_bootstrap` -> `31/31` passed
- `./bin/test_resource_repo_query` -> `8/8` passed
- `bash scripts/run_all_tests.sh` -> `239/239` passed

## 2026-03-09 FPC Runtime / Info Flow Wave

- `src/fpdev.cmd.fpc.pas:786` `UpdateSources`
  - 空版本固定落到 `.../sources/fpc/fpc-main`，非空为 `.../sources/fpc/fpc-<version>`。
  - 行为边界：missing dir / no git backend / not repo -> `False`；no remote -> 输出 local-only 并 `True`；pull success -> 输出 done 并 `True`；pull failure -> 输出 git pull failed 并 `False`。
- `src/fpdev.cmd.fpc.pas:844` `CleanSources`
  - 重复同一 source-dir 解析；missing dir -> `False`；`CleanBuildArtifacts` 成功时输出删除数量；异常翻译为 `CleanSources failed - ...`。
- `src/fpdev.cmd.fpc.pas:884` `ShowVersionInfo`
  - invalid version 直接失败；installed + toolchain info 时输出 install date / source url；valid but not installed 输出 `ERR_NOT_INSTALLED` 但仍返回 `True`。
- `src/fpdev.cmd.fpc.pas:952` `TestInstallation`
  - not installed -> `False`；installed 时拼接 `bin/fpc(.exe)` 并跑 `TProcessExecutor.Execute(..., ['-i'])`；成功输出 doctor ok，失败输出 issue count。
- 可复用 helper：`src/fpdev.cmd.fpc.installversionflow.pas:25` `BuildFPCSourceInstallPathCore`、`src/fpdev.cmd.fpc.installversionflow.pas:26` `BuildFPCInstalledExecutablePathCore`。
- 参考模式：`src/fpdev.cmd.lazarus.flow.pas` + `tests/test_lazarus_runtimeflow.lpr`。
- 本波按约定先尝试 `search_context`，MCP 仍返回 `Transport closed`，继续本地审查执行。

- `src/fpdev.cmd.fpc.runtimeflow.pas`
  - 新增 `TFPCSourcePlan`、`IFPCGitRuntime`、`ExecuteFPCUpdatePlanCore`、`ExecuteFPCCleanPlanCore`、`ExecuteFPCShowVersionInfoCore`、`ExecuteFPCTestInstallationCore`。
  - 复用 `BuildFPCSourceInstallPathCore` / `BuildFPCInstalledExecutablePathCore`，让 source-dir / executable-path 拼接只保留一份。
  - `ShowVersionInfo` 的输出路由保持原语义：`Outp` 显式传入时，信息和错误都写 `Outp`；默认调用时成功信息走 `FOut`，错误走 `FErr`。
- `src/fpdev.cmd.fpc.pas`
  - 新增 `TFPCGitRuntimeAdapter` 包装 `TGitOperations`，manager 不再直接手写 git/source/runtime 细节。
  - 新增薄 callback wrapper：`SourceDirExists`、`CleanSourceArtifacts`、`LookupToolchainInfo`、`ExecuteInstalledFPCInfo`。
- `tests/test_fpc_runtimeflow.lpr`
  - 新增 40 条 focused 断言，覆盖 source plan fallback、update/clean 全分支、show-info invalid/installed/not-installed，以及 doctor success/failure。

## 2026-03-09 FPC Validator Runtimeflow Dedup Wave

- `src/fpdev.fpc.validator.pas:351` `TestInstallation` 与 `src/fpdev.cmd.fpc.runtimeflow.pas` 的 doctor flow 基本重复，可直接委托。
- `src/fpdev.fpc.validator.pas:396` `ShowVersionInfo` 与 runtimeflow 的 installed/toolchain/info flow 也重复，但有两个语义差异：
  1. validator 不做 `ValidateVersion` 校验；
  2. validator 仍输出硬编码英文 `Install Date:` / `Source URL:`。
- 因此本波 helper 需要新增一层可选 validation + 可注入 info writer，才能同时服务 manager 与 validator。
- 当前仓库对 `TFPCValidator.ShowVersionInfo` / `TestInstallation` 没有 focused test，补回归价值高。
- 本波按约定先尝试 `search_context`，MCP 仍返回 `Transport closed`，继续本地审查执行。

- `src/fpdev.cmd.fpc.runtimeflow.pas`
  - `ExecuteFPCShowVersionInfoCore` 现有新 overload：支持可选 `AValidateVersion` 与可注入 `TFPCVersionInfoWriter`，因此同一 helper 既可服务 manager 的 i18n 输出，也可服务 validator 的英文输出。
  - 旧 overload 仍保留，默认走本地化 `WriteLocalizedToolchainInfo`，所以 `cmd.fpc` 调用点无需扩散变更。
- `src/fpdev.fpc.validator.pas`
  - 新增 `LookupToolchainInfo` / `ExecuteInstalledFPCInfo` 薄 callback wrapper。
  - `TestInstallation` / `ShowVersionInfo` 已全部 delegate 到 runtimeflow；validator 专有差异只剩 `WritePlainToolchainInfo`。
- `tests/test_fpc_validator_runtimeflow.lpr`
  - 用临时 install root + 运行时编译的 fake `fpc` 可执行文件做 focused 回归，锁定 validator 的 public behavior 而不是内部实现。
- 新测试初版命中过一次 `TInterfacedObject` 生命周期坑：将 `TStringOutput` 仅以对象引用传给 `IOutput` 参数后再直接访问对象，可能在临时接口释放后悬空；已改成 `buffer + interface alias` 模式固定。

## 2026-03-09 Resource Repo Status / Commit Query Wave

- `src/fpdev.resource.repo.pas:250` `GetLastCommitHash`
  - 行为边界很稳定：非 git repo -> `unknown`；`git rev-parse --short HEAD` 成功 -> `Trim(StdOut)`；失败 -> `unknown`。
  - 目前直接耦合 `TProcessExecutor.Execute('git', ['rev-parse', '--short', 'HEAD'], FLocalPath)`，适合抽成固定 query helper。
- `src/fpdev.resource.repo.pas:313` `GetStatus`
  - 当前只做三件事：repo initialized 判断、commit hash 读取、`Initialized at / Commit / Last update check` 三行文本拼装。
  - 很适合像前几波那样抽成纯 helper，后续若要切换输出格式（JSON/structured）也更容易。
- 现有相关测试缺口：没有 focused 测试锁 `GetLastCommitHash` / `GetStatus`；`tests/test_resource_repo_lifecycleflow.lpr` 只覆盖 init/update/manifest。
- 本波按约定先尝试 `search_context`，MCP 仍返回 `Transport closed`，继续本地审查执行。

- `src/fpdev.resource.repo.statusflow.pas`
  - 新增 `GetResourceRepoLastCommitHashCore` 与 `BuildResourceRepoStatusCore`，统一非 repo -> `unknown` / `Not initialized` 的边界行为。
  - commit query helper 只关心固定命令结果，不再耦合 `TProcessExecutor` 具体调用点。
- `src/fpdev.resource.repo.pas`
  - 新增 `QueryShortHead` 薄 wrapper，`GetLastCommitHash` / `GetStatus` 现为纯 delegate。
- `tests/test_resource_repo_statusflow.lpr`
  - 新增 10 条 focused 断言，锁定 commit hash trim/failure/path 传递，以及 status 三行文案格式。

## 2026-03-09 Package Facade Install/Create/Publish Wave

- `src/fpdev.cmd.package.pas:888` `InstallFromLocal`
  - 主要职责：目录存在校验、metadata 名称回退、source install 调用、异常翻译。
- `src/fpdev.cmd.package.pas:923` `CreatePackage`
  - 主要职责：包名校验、源目录解析、metadata 文件确保、创建/已存在分支输出、next steps 文案。
- `src/fpdev.cmd.package.pas:986` `PublishPackage`
  - 主要职责：默认输出初始化、installed 校验、publish metadata 解析失败翻译、archive 创建委托与 exit code 维护。
- 这三段都已经有可复用 core helper：
  - `ResolvePackageNameFromMetadataCore`
  - `EnsurePackageMetadataFileCore`
  - `TryResolvePublishMetadataCore`
  - `HandlePublishMetadataFailureCore`
  - `CreatePublishArchiveCore`
- 因此这波最合适的是新增 facade-level helper，把 manager 压成 callback adapter。
- 本波按约定先尝试 `search_context`，MCP 仍返回 `Transport closed`，继续本地审查执行。

- `src/fpdev.cmd.package.facadeflow.pas`
  - 新增 `ExecutePackageInstallFromLocalCore`、`ExecutePackageCreateCore`、`ExecutePackagePublishCore`，把三段 facade orchestration 收成独立 helper。
- `src/fpdev.cmd.package.pas`
  - 新增薄 adapter：`PathExists`、`ResolveLocalPackageName`、`EnsurePackageMetadataFile`、`ResolvePublishMetadata`、`HandlePublishMetadataFailure`、`CreatePublishArchive`。
  - `InstallFromLocal` / `CreatePackage` / `PublishPackage` 现已退回 wrapper，只保留 config/output/exception 边界。
  - `fpdev.cmd.package.metadata` 改为只在 interface `uses` 暴露一次，顺手修掉 implementation 重复引入带来的 duplicate identifier 风险。
- `tests/test_package_facadeflow.lpr`
  - 新增 25 条 focused 断言，覆盖本地安装缺目录/metadata name 回退、create 非法名/metadata 文件创建、publish 未安装/metadata 失败/归档成功等关键分支。
- `scripts/update_test_stats.py`
  - 本波 discoverable Pascal test count 已同步到 `243`，README / docs / CI 口径重新一致。
- 下一波优先切到 `src/fpdev.build.manager.pas` 的 phase runner seam，继续沿用“red test -> helper -> wrapper delegate”套路。

## 2026-03-09 Build Manager Makeflow Wave

- 本波先按约定尝试 `search_context`，MCP 仍返回 `Transport closed`，继续本地审查执行。
- 审查确认 `FullBuild` 的 phase runner 已经在 `src/fpdev.build.fullbuildflow.pas` + `src/fpdev.build.pipeline.pas`，因此 `src/fpdev.build.manager.pas` 当前更厚的重复点其实是五段 make-step orchestration。
- `src/fpdev.build.makeflow.pas`
  - 新增 `TBuildMakeStepPlan`，统一承载 step/skip/dest/targets/perf metadata。
  - 新增 `CreateBuildCompilerStepPlanCore`、`CreateBuildRTLStepPlanCore`、`CreateBuildPackagesStepPlanCore`、`CreateBuildInstallPackagesStepPlanCore`、`CreateBuildInstallStepPlanCore`。
  - 新增 `ExecuteBuildMakeStepCore`，统一处理 step 切换、install skip、目录准备、start/end log、env snapshot、perf 回调与 make 调用。
- `src/fpdev.build.manager.pas`
  - 新增薄 perf adapter：`StartPerfOperation`、`SetPerfMetadata`、`EndPerfOperation`。
  - 新增 `RunMakeTargets`，把 dynamic-array callback 与现有 `RunMake` open-array 签名收口。
  - `BuildCompiler` / `BuildRTL` / `BuildPackages` / `InstallPackages` / `Install` 均退回 thin wrapper。
- `tests/test_build_makeflow.lpr`
  - 新增 21 条 focused 断言，锁定 install-packages plan、compiler step 执行、install skip 语义和 perf/log callback 行为。
- 观察到 `test_fpc_installer_iobridge` 在第一轮 Pascal 全量里出现一次 legacy HTTP bridge 偶发失败；单独复跑 `17/17` 通过，第二轮 Pascal 全量也恢复 `244/244`，说明这更像现有波动点而非本波回归。

## 2026-03-10 Build Cache Indexflow Wave

- 本波先按约定尝试 `search_context`，MCP 仍返回 `Transport closed`，继续本地审查执行。
- 审查 `src/fpdev.build.cache.pas` 后确认：`LookupIndexEntry` 仍直接承载 index JSON -> `TArtifactInfo` 的字段映射，`UpdateIndexEntry` / `RemoveIndexEntry` 还内嵌 sorted-list mutation，`RecordAccess` 还夹带 lookup/update/save orchestration；这四段天然属于同一条 indexflow seam。
- `src/fpdev.build.cache.indexflow.pas`
  - 新增 `BuildCacheLookupIndexArtifactInfo`，统一 index JSON parse、日期归一化和 `TArtifactInfo` 构造。
  - 新增 `BuildCacheUpsertIndexEntry` 与 `BuildCacheRemoveIndexEntryVersion`，统一 sorted `TStringList` 的 add/replace/remove 语义。
  - 新增 `BuildCacheRecordIndexAccessCore`，统一 access hit 路径上的 lookup、access-count 更新、metadata 写回和 index 落盘。
- `src/fpdev.build.cache.pas`
  - `LookupIndexEntry` 现只负责 `EnsureIndexLoaded` + entry JSON 读取，然后 delegate 到 `BuildCacheLookupIndexArtifactInfo`。
  - `UpdateIndexEntry` / `RemoveIndexEntry` / `RecordAccess` 现均退回 thin wrapper。
- `tests/test_build_cache_indexflow.lpr`
  - 新增 25 条 focused 断言，覆盖有效/无效 JSON、index upsert/remove，以及 access hit/miss orchestration。
- 本波与现有 `indexjson` / `access` / `indexcollect` / `indexstats` helper 形成更清晰的分层：底层 parse/format 负责纯数据处理，`indexflow` 负责方法级 orchestration，`TBuildCache` 只保留 facade/wrapper。

## 2026-03-10 Resource Repo BootstrapQuery Wave

- 本波先按约定尝试 `search_context`，MCP 仍返回 `Transport closed`，继续本地审查执行。
- 审查 `src/fpdev.resource.repo.pas` 后确认：`HasBootstrapCompiler` / `GetBootstrapInfo` 仍直接承载 bootstrap_compilers manifest 查询和 `TPlatformInfo` 字段映射，而 binary/cross 已经各自有纯 helper；这块非常适合沿同一模式抽成 bootstrapquery helper。
- `src/fpdev.resource.repo.bootstrapquery.pas`
  - 新增 `ResourceRepoHasBootstrapCompiler`，统一 bootstrap_compilers -> version -> platforms 的存在性查询。
  - 新增 `ResourceRepoGetBootstrapCompilerInfo`，统一 v2 `url`/`mirrors` 与 v1 `archive` fallback 的 `TPlatformInfo` 构造。
  - 新增 `ResourceRepoGetBootstrapExecutablePath`，统一 repo root + executable 的 path 拼装。
- `src/fpdev.resource.repo.pas`
  - `HasBootstrapCompiler` / `GetBootstrapInfo` 现在只保留 `EnsureManifestLoaded` + exception translation。
  - `GetBootstrapExecutable` 改为 delegate 到 executable-path helper，不再直接手拼 `FLocalPath + PathDelim + Info.Executable`。
- `tests/test_resource_repo_bootstrapquery.lpr`
  - 新增 21 条 focused 断言，覆盖存在性查询、v2 mirrors/url 映射、legacy archive fallback、missing entries、executable path 拼装。
- 这波让 `resource.repo` 的三类 manifest 查询 helper 终于对齐：`binary`、`cross`、`bootstrapquery` 各自负责纯数据提取，repository facade 只保留 lazy-load 和异常边界。

## 2026-03-10 IOBridge Stability Wave

- `tests/test_fpc_installer_iobridge.lpr`
  - 原始 `TLocalHTTPServer.Start` 只做 `Sleep(400)` + `FProcess.Running`，并不确认端口是否真的 accept；这与全量回归里偶发的 bridge false/bytes=0 现象吻合。
  - 新增 delayed server red path 后，bridge 在 server ready 前会稳定走出 `err=''` / zero-byte temp file 残留，说明问题不在 archive/extract，而在 HTTP bridge 启动窗口。
  - 将 `Start` 改为 readiness probe 后，success path 不再依赖固定 sleep；`StartDelayed(600)` 则可继续给 retry 行为做确定性回归。
- `src/fpdev.fpc.installer.iobridge.pas`
  - 旧实现是 single-shot `TFPHTTPClient.Get`，失败时不清理 partial temp file，也没有对 transient startup/socket 类错误做 retry。
  - 新实现拆成 single-attempt helper + retry classifier + retry loop；transient 错误会最多重试 4 次，失败时统一删掉 temp file，并给空异常消息补默认错误文本。
- 剩余大文件热点（`wc -l src/*.pas tests/*.lpr | sort -nr | head`）
  - `src/fpdev.config.managers.pas` 1166
  - `src/fpdev.cmd.package.pas` 1125
  - `src/fpdev.build.manager.pas` 966
  - `src/fpdev.cmd.fpc.pas` 965
  - `src/fpdev.build.cache.pas` 937
  - `src/fpdev.resource.repo.pas` 923
  - 下一批仍应优先围绕 `resource.repo` / `build.cache` / namespace command mega-unit 做整刀切片，而不是回到零碎点修补。

## 2026-03-10 Resource Repo Distributionflow Wave (in-progress)

- `src/fpdev.resource.repo.pas`
  - `GetBinaryReleaseInfo` 仍在主类里手写 `TBinaryReleaseInfo -> TPlatformInfo` 转换。
  - `GetCrossToolchainInfo` 仍在主类里手写 `TResourceRepoCrossInfo -> TCrossToolchainInfo` 转换。
  - `InstallBinaryRelease` / `InstallCrossToolchain` / `InstallPackage` 仍重复执行“先取 info，不存在则打固定错误，再委托 install helper”的 orchestration。
  - `HasPackage` 还是旧 stub，当前即使本地 package metadata 存在也返回 `False`；这块可以直接切回 file-based query，而不是继续依赖未实现的 manifest index。
- 适合下一刀的新 helper 形状
  - 新增 `distributionflow` helper：统一 binary/cross/package 的 info 映射、package existence/query、以及 install orchestration。
  - `TResourceRepository` 保留 manifest/local-path 边界与日志 adapter，本体继续变 thin wrapper。

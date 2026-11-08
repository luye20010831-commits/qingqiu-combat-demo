# 源码与文件校验说明

Release完整提交包内的file-manifest.json和source-snapshot.json用于校验压缩包内的原始文件字节。

Git仓库按项目已有.gitattributes把文本行尾统一为LF。核对733份源码／依赖后，639份字节完全一致，其余94份差异仅为Windows CRLF与LF行尾；没有其他内容变化。Release附件的GitHub SHA-256与本地文件一致，四个附件均已匿名访问确认可下载。

入口：project/project.godot（本仓库路径为submission/project/project.godot）。校验数据、录制方式和未完成项分别见此目录及上级docs。

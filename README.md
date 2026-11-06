# 云吞插件：PhotoPrism

开发流程见[插件开发指南](https://github.com/geraldpeng6/wonton-docs/blob/main/develop.md)。

PhotoPrism（[photoprism.app](https://www.photoprism.app)，AGPL-3.0）是自托管相册：按时间、人物和画面内容
整理、浏览、搜索照片。这个插件把它装进云吞：照片读共享文件夹 photos（只读），索引和缓存放在插件自己的数据目录里，
网页经核心网关打开，应用自己不设登录，打开就能用。

插件用上游官方镜像 `photoprism/photoprism`（社区版），按摘要固定。单用户场景用 SQLite（上游兼容列表里有，也是
镜像的默认驱动），不额外起数据库。

## 图标来源与许可

`icon.svg` 取自 PhotoPrism 官方标志（photoprism.app 的 logo.svg），原样使用，只加了白色底和 `viewBox`；来源、版权、
商标说明见 [NOTICE](NOTICE)。该标志为 PhotoPrism UG 的商标，仅用于识别本插件所集成的应用；本插件不代表
PhotoPrism 官方，也不表示获得 PhotoPrism 的合作、认可或背书。

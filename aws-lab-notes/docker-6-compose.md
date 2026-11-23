# Docker 第 6 章：Docker Compose

- **状态：** ✅ 完成（基础实验 + TLS/ELK 实验）
- **日期：** 2026-11-23
- **课程原文：** [docker/docker_6_compose/](../docker/docker_6_compose/)

## 实验 1：基础实验（nginx + Flask app + redis）

| 检查项 | 结果 |
|---|---|
| `docker compose config` | ✅ 通过 |
| 启动顺序 | redis 健康 → app 健康 → nginx 启动（`depends_on` + `healthcheck`） |
| `curl http://127.0.0.1:8080/` 三次 | `hits` 依次为 1、2、3 |
| app 以什么用户运行 | `uid=10001(appuser)`，不是 root |
| 服务发现 | app 容器里解析 `redis` → `172.19.0.2`（Compose 内置 DNS） |
| 网络隔离 | 两个网络 `basic_frontend`、`basic_backend`；宿主机连不上 redis 的 6379，因为没有发布端口 |
| `down` 再 `up` | `hits` 变成 4，**数据保存在具名卷里** |
| `down -v` | 卷被删除 |

## 实验 2：TLS + ELK + Nginx

| 服务 | 状态 |
|---|---|
| cert-init | Exited (0)，生成了 4 张证书 |
| elasticsearch | Up (healthy) |
| kibana-auth-init | Exited (0)，`kibana_system password updated` |
| kibana | Up (healthy) |
| nginx | Up |
| filebeat | Up |

镜像总共约 4.7 GB（Elasticsearch 和 Kibana 各约 2 GB），机器内存用了约 2.9 GB。

| 验证项 | 结果 |
|---|---|
| 16.3 HTTPS 首页 `https://www.qytdocker2026.com/` | HTTP 200，证书用课程 CA 校验通过（`ssl_verify=0`），标题“首页 - Compose TLS Demo” |
| 16.4 经 Nginx 反代访问 Kibana | HTTP 200，跳转到 `/login?next=%2F`，就是登录页 |
| 证书 SAN | `DNS:www.qytdocker2026.com, DNS:nginx` |
| 16.5 Nginx 日志写入共享卷 | `access-compose.log` 里有访问记录（含一次 404） |
| 16.6 Filebeat 看到同一个文件 | 内容一致 ✅ |
| 16.7 日志进入 Elasticsearch | 索引 `.ds-filebeat-8.19.0-2026.11.23-000001`，8 条 |

## 和课程原版的区别

- **16.3、16.4 没用 Windows 浏览器访问**，而是在实验机上用 `curl --resolve` 把域名指到 127.0.0.1，并用课程 CA 校验证书，效果一样。要在你的浏览器里看，需要：① 开一条 SSH 隧道把 443 端口带到你电脑；② 改 Windows 的 `hosts`，把两个域名指到 `127.0.0.1`；③ 信任课程的根证书 `docker/docker_6_compose/certs/ca.cer`。后两步会改系统设置，要先征得你同意。
- **16.7 没在 Kibana 网页里建 Data View**，改用 Elasticsearch API 确认日志已经写进去。
- ELK 目前**还在运行**，方便你去浏览器里看；不看的话执行 `docker compose down -v` 清理。

## 笔记 / 疑问

（自己补充）

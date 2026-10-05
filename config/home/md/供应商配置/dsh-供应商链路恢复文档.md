# DSH 供应商链路恢复文档（AgentRouter / AnyRouter 本地代理）

> **用途**：重装系统后，把这套「本地代理 → Clash 翻墙 → 供应商」的链路原样恢复，让 dsh 里的
> **AnyRouter / AgentRouter** 继续可用。写给未来的我，也写给要帮我恢复的 AI。
> **实测时间**：2026-09-30（两个代理都在跑；带 key 调 `/v1/models` 均返回 **200**）。
> **本文件不含任何明文密钥。** 配套的恢复包（代理源码 + systemd 单元）在
> `~/md/供应商配置/dsh-provider-kit/`（**只是快照**：里面的 `anyrouter-proxy.mjs` 是
> `~/scripts/dsh/` 的生成副本，权威源在那边；见 §三 第 3 项）。

---

## 一、先回答两个常问的问题

**Q1：any（AnyRouter）和 agent（AgentRouter）这两个供应商还能用吗？**
**能用。** 2026-09-30 实测：`agentrouter /v1/models` → **200**（4 个模型）、
`anyrouter /v1/models` → **200**（32 个模型）。判定标准见 §四第 4 步。

**Q2：恢复这套东西需要 codex 吗？**
**不需要，而且 codex 本身已于 2026-09-30 卸载**（用户确认不再使用）。dsh 这条链路只用 `node` +
两个 `.mjs` + systemd 用户单元，与 codex / cc-switch **完全无关**。细节见 §六。

---

## 二、架构（一屏看懂）

```
dsh 桌面版（profile: ~/.dsh/profiles/desktop）
 ├─ provider anyrouter        → http://127.0.0.1:8321/v1 ─┐
 ├─ provider agentrouter-anth → http://127.0.0.1:8320    │ 两个 node 反向代理
 └─ provider agentrouter-resp → http://127.0.0.1:8320/v1 ┘ （经 Clash 出网）
                                    │  HTTPS_PROXY=http://127.0.0.1:7890
                                    ▼
                            Clash（本机 7890 —— 出网唯一通道）
                                    │
                    https://anyrouter.top / https://agentrouter.org
```

- **密钥不在代理里**：代理只做转发。dsh 按 provider 配置的 `apiKeyEnv` 名字去
  `~/.dsh/.credentials.yaml` 取密钥。
- 两个代理都只监听 `127.0.0.1`（无鉴权的本机回环服务），局域网不可达。

### 当前 provider 事实（2026-09-30 实测）

| provider id | 显示名 | api 协议 | baseURL | 取哪个 key | 模型 |
|---|---|---|---|---|---|
| `anyrouter` | AnyRouter | `openai-responses` | `http://127.0.0.1:8321/v1` | `ANYROUTER_API_KEY` | gpt-6-astra |
| `agentrouter-anth` | AgentRouter (Anthropic) | `anthropic-messages` | `http://127.0.0.1:8320` | `AGENTROUTER_API_KEY` | deepseek-v4-flash 等 |
| `agentrouter-resp` | AgentRouter (Responses) | `openai-responses` | `http://127.0.0.1:8320/v1` | `AGENTROUTER_API_KEY` | gpt-6-astra |

（同一层里还有 `opencode-go-zen`、`workbuddy2api`（本机 7863）、`qwen`，与本文档的两个代理无关。）

---

## 三、重装前必须带走的 5 样（缺一个都恢复不了）

| # | 路径 | 作用 | 丢了会怎样 |
|---|---|---|---|
| 1 | `~/.dsh/.credentials.yaml`（权限 **600**） | 全部供应商密钥 + 浏览器会话签名。键名：`AGENTROUTER_API_KEY`、`ANYROUTER_API_KEY`、`DEEPSEEK_API_KEY`、`OPENCODE_GO_API_KEY`、`QWEN_API_KEY`、`WORKBUDDY2API_KEY`、`GOOGLE_API_KEY`、`WORKBUDDY_LOGIN_SESSION(S)` | 所有供应商 401，只能逐个人工重新登录/填 key |
| 2 | `~/.dsh/profiles/desktop/cordis.patch.yml` | dsh 侧 `llm-pi-ai` 的 provider 定义（baseURL / apiKeyEnv / 模型清单 / 两个 AgentRouter 段的 `Originator`、`Version` 头） | 界面上**供应商整批消失**（踩过，见 §七） |
| 3 | `~/.local/bin/{agentrouter,anyrouter}-proxy.mjs` | 两个代理本体。**权威源**：`anyrouter` 那份在 `~/scripts/dsh/anyrouter-proxy.mjs`（2026-10-04 起，见下"版本纪律"）；`agentrouter` 那份只在 `~/.local/bin/` | 8320 / 8321 没进程 |
| 4 | `~/.config/systemd/user/{agentrouter,anyrouter}-proxy.service` | 用户级开机自启 + 注入 Clash 代理环境变量（**副本也在恢复包**） | 重启后代理不在 |
| 5 | **Clash 及其配置**（监听 `127.0.0.1:7890`） | 出网唯一通道 | 代理返回 **502** `cannot reach … Is Clash running?` |

> ⚠️ 另外把 `~/.dsh/notes/REINSTALL-INVENTORY.md`（重建整个 dsh 的配方）也带走或复制进 `~/md/`——
> 本文档只管**供应商链路**，不管 dsh 本体怎么装。
>
> ⚠️ **本目录所在的 `~/md` 没有 git 远端**（`git remote` = 0）⇒ 它只是本地仓库，
> **重装会一起没**。重装前必须自己把整个 `~/md` 拷到 U 盘/网盘/私有仓库，
> 连同 `~/.dsh/.credentials.yaml`（那份**不能**进任何仓库，要单独加密保管）。

---

## 四、恢复步骤（AI 按序执行）

1. **依赖**：`node`（≥ 22，本机是 `/usr/bin/node`）、systemd `--user` 会话正常、Clash 已在 7890 监听。
2. **放回文件**（§三 第 1–4 项）。**anyrouter 走安装器，别手抄**：
   ```bash
   bash ~/scripts/dsh/install-anyrouter-proxy.sh          # 装 .mjs + 写单元 + 起服务 + 验连通
   bash ~/scripts/dsh/install-anyrouter-proxy.sh --check  # 只体检（退出码 0 = 全一致）
   ```
   `agentrouter` 没有安装器，从恢复包手放：
   - `dsh-provider-kit/agentrouter-proxy.mjs` → `~/.local/bin/`（可执行）
   - `dsh-provider-kit/{agentrouter,anyrouter}-proxy.service` → `~/.config/systemd/user/`（644）
     （anyrouter 那个单元由安装器自己写，**不用**手放；恢复包里那份只是备份快照）
3. **起服务并设开机自启**：
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now agentrouter-proxy.service anyrouter-proxy.service
   systemctl --user status agentrouter-proxy.service anyrouter-proxy.service --no-pager | head -20
   ```
4. **验收（唯一判据，别凭感觉）**：
   ```bash
   ss -ltnp | grep -E ':(8320|8321)'                                  # 两个都在听 127.0.0.1
   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8320/v1/models
   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8321/v1/models
   ```
   - **401 = 好消息**：上游在回答，只是请求没带 key ⇒ 链路通。
   - **502 = 故障**：Clash 没跑或走不通（响应体会直接写 `Is Clash (127.0.0.1:7890) running?`）。
   - **200**：完全正常（带 key 时）。带 key 复验：
     ```bash
     AK=$(grep -m1 '^  AGENTROUTER_API_KEY:' ~/.dsh/.credentials.yaml | sed 's/^  AGENTROUTER_API_KEY: *//')
     curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $AK" http://127.0.0.1:8320/v1/models
     ```
5. **重启 dsh 桌面应用** → 设置 → 模型：应能看到 **AnyRouter**、**AgentRouter (Anthropic)**、**AgentRouter (Responses)**。

---

## 五、两个代理为什么存在（**不要"顺手删掉"**）

两个都是"本机回环 → 上游"的直通反向代理，代码几乎一样，**区别只在要不要伪装请求头**：

- **agentrouter-proxy**（端口 8320 → `https://agentrouter.org`）
  1. agentrouter.org 直连被墙，必须经 Clash 出网；
  2. 它的 **WAF 只认 Codex 官方客户端的握手特征**，所以代理会把请求头换成：
     `Originator: codex_cli_rs` / `Version: 0.101.0` /
     `User-Agent: codex_cli_rs/0.101.0 (Mac OS 26.0.1; arm64) Apple_Terminal/464`。
     dsh 自己的 HTTP 客户端**不能自定义 User-Agent**（会被归属标记），所以这层代理是**必需的**，不是可选优化。
     上游若调整白名单 → 改 `~/.local/bin/agentrouter-proxy.mjs` 顶部的 `WIRE_HEADERS` 与 `Version`。
- **anyrouter-proxy**（端口 8321 → `https://anyrouter.top`）
  直连在 TLS 握手阶段就失败（2026-09-18 实测，IPv4 同样）⇒ 靠 Clash 出网。
  **2026-10-04 起它不只做转发**：① **注入 Codex 线形头**（`originator` / `version` / `OpenAI-Beta` /
  `session_id`），AnyRouter 的 `gpt-6-astra` 信道缺这些头直接回 `400 invalid codex request`，
  站点要求 codex ≥ `0.153.0`（旧版 `0.101.0` 已作废）；② **挤信道重试 + 对冲并发**
  （信道常满，网关会把请求挂 ~80 秒才回 500，故在转发层重试）。旧版 09-18 那份**没有这两样，
  装上也用不了 astra**。参数在 systemd 单元的 `ANYROUTER_PROXY_*` 里，改法见
  `~/scripts/dsh/README.md` 的 A2 节。

两者都用 Node 的 env-proxy 支持出网：进程环境里要有
`NODE_USE_ENV_PROXY=1`、`HTTPS_PROXY=http://127.0.0.1:7890`、`NO_PROXY=127.0.0.1,localhost`
——这正是 systemd 单元里 `Environment=` 那几行的作用。**手动跑代理时必须自己带上这些变量**，否则必然 502。

---

## 六、codex / cc-switch 那条链路（**codex 已于 2026-09-30 退役**）

**恢复 dsh 完全不用管 codex**：`~/.codex/`（181M 历史与日志）、`~/.local/bin/codex` 包装脚本、
`age-env.fish` 与 `anyrouter-env.fish` 都已删除；`AGE_API_KEY`（**全机只此一份**，dsh 不存它）已归档到
`~/.dsh/backup/config-files/codex-retired-20260930/`（600）。系统包 `openai-codex`（`/usr/bin/codex`，319M）
待执行 **`sudo pacman -Rns openai-codex`** 移除 —— 实测它**没有任何反向依赖**。

**`cc-switch` 也已退役（2026-09-30，用户确认不用）**：用户侧 `~/.cc-switch/`（8.1M）+ 自启动项已删除、进程已停；
系统包待执行 **`sudo pacman -Rns cc-switch`**（反向依赖为 0）。
它的 DB 是**密钥仓**（`settings_config` 列里存着 claude / gemini / codex / grok 各家 key），删前已归档到
`~/.dsh/backup/config-files/cc-switch-retired-20260930/`（600，含 `cc-switch.db`）。确认不再需要可整目录删掉。

> **对 grok 无影响**（已核实）：grok 的认证写在**它自己的** `~/.grok/config.toml`（`[auth_provider.*]` 段）与
> `~/.grok/auth.json`（x.ai OIDC 登录）里，cc-switch 只是当初写这些文件的编辑器。删掉后 grok 照常可用，
> 只是以后换 grok 的供应商要**手改** `~/.grok/config.toml`，没有 GUI 了。

> 历史说明见同目录 `ccswitch-codex-any-age.md`：codex 部分已作废，**grok 的 tabi/seek 部分仍有效**。
> `~/.config/fish/conf.d/proxy-env.fish`（通用代理变量）**保留**。

---

## 七、历史坑（踩过的，别重犯）

1. **「供应商整批消失」的真因**：某个插件自带 patch 把 `llm-pi-ai` 层 `disabled: true` 掉、用自家层顶替，
   而那个顶替层起不来 ⇒ 界面上供应商全没了。修法是在 profile 补丁里**显式** `disabled: false` 恢复本层
   （`cordis.patch.yml` 里那段注释就是这块墓碑）。改完必须**重启应用**（宿主半是启动时 import 的）。
2. **代理不是"起了就行"**：忘了 `NODE_USE_ENV_PROXY`/`HTTPS_PROXY` 就会 502；systemd 单元里已经写好，
   手动 `node xxx-proxy.mjs` 测试时要自己 export。
3. **`settings.yaml` 已退役**（0.1.7 起设置落在 profile 的 `cordis.patch.yml`）。
   同目录的 `check-settings.mjs`（CLI 时代的一次性校验脚本，依赖已删除的 `~/.dsh/settings.yaml`
   与已删除的源码树 ⇒ **已于 2026-09-30 删除**（若要找回：`git -C ~/md checkout -- 供应商配置/check-settings.mjs`）。
4. 判定链路时**只看状态码**：401 是通、502 是 Clash 断、连不上是代理没起。

---

## 八、密钥卫生

- 本文档**不含任何明文密钥**；唯一副本是 `~/.dsh/.credentials.yaml`（权限必须保持 600）。
- 恢复包 `dsh-provider-kit/` 里的两个 `.mjs` 与两个 `.service` **不含密钥**，可以安全进 git。
- 别把 `.credentials.yaml` 的内容、或带 key 的 shell 输出，贴进任何会话、日志、文档。

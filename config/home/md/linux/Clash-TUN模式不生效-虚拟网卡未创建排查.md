# Clash TUN 模式没生效：为什么、怎么解决的

> 日期：2026-10-01
> 现象：FlClash 里「虚拟网卡」开关**是打开的**，配置文件也写着 `tun: enable: true`，但系统里根本没有虚拟网卡，流量也没被接管 —— 实际只有「系统代理」在工作。
> 结果：已修复。补上 `/dev/net/tun` 设备节点 + 设为开机自动加载，TUN 实测生效。
> 环境：Arch Linux + niri（Wayland）+ FlClash 0.8.96（archlinuxcn）+ linux-zen 7.2.7。

## 先分清：系统代理 vs 虚拟网卡（TUN）

**一句话**：系统代理是"**告诉程序代理在哪，认的程序才走**"；TUN 是"**造一块网卡改掉路由，谁都跑不掉**"。

| | 系统代理 | 虚拟网卡 / TUN |
|---|---|---|
| 实现方式 | 环境变量 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` + GNOME 代理设置（`manual → 127.0.0.1:7890`） | 建虚拟网卡 + 策略路由（`table 2022` + `ip rule 9000/9001/9002`）+ DNS 劫持（`dns-hijack: any:53`） |
| 谁会被代理 | **主动读这些设置的程序** | 所有按路由表走的 TCP/UDP 流量 |
| 需要 root | 否 | 是 |
| 典型漏网 | sudo、docker 守护进程、systemd 服务、不认代理的程序 | ICMP（ping）、自建协议/绑定网卡的程序 |

### 使用场景举例

| 场景 | 系统代理 | TUN | 说明 |
|---|---|---|---|
| 浏览器 / 大部分 GUI 应用 | ✅ | ✅ | 读 GNOME 代理设置 |
| 终端里 `git` / `npm` / `pip`（普通用户） | ✅ | ✅ | 读环境变量 |
| **`sudo pacman -Syu`** 走国外源 | ❌ | ✅ | **sudo 默认清空环境变量**，pacman 看不见代理 |
| **`docker pull`** 拉境外镜像 | ❌ | ✅ | 拉镜像的是 **dockerd 守护进程**，不读你 shell 的环境变量 |
| systemd 服务 / 定时任务自动更新 | ❌ | ✅ | 不继承登录环境 |
| 不支持代理设置的游戏 / 客户端 | ❌ | ✅ | 只要走 TCP/UDP |
| `ping`（ICMP） | ❌ | ⚠️ | 代理只处理 TCP/UDP，ICMP 一般不转发 |
| 只想让浏览器翻墙，其余走本地宽带 | ✅ 更合适 | ⚠️ | 需写分流规则才能达到同样效果 |
| 内网 / 银行站点 | ✅ | ⚠️ | 内网直连子网路由仍走本地，但境外出口 IP 可能触发风控 |

**结论**：日常只有浏览器 + 终端命令行，系统代理就够用；**需要 `sudo`、`docker`、后台服务也走代理时，才必须 TUN**。

## 怎么判断"TUN 到底有没有生效"

```bash
ip -brief link show | grep -i flclash   # 空 = 没有虚拟网卡
ip rule show                            # 只有 0 / 32766 / 32767 三条 = 策略路由没接管
ls -l /dev/net/tun                      # 不存在 = 根因就在这
grep '^tun ' /proc/modules              # 空 = 内核模块没加载
```

**决定性实测**（区分"真没生效"和"只是不会看"）：

```bash
curl -s https://api.ipify.org                # 走系统代理 → 代理出口 IP
curl -s --noproxy '*' https://api.ipify.org  # 绕过代理 → TUN 生效时**同样**是代理出口 IP
```

- 生效前：第二条**连不上**（说明 IP 层没有被接管）
- 生效后：两条返回**同一个**境外 IP

## 根因：`/` 的属主不是 root，systemd 拒绝创建设备节点

```console
$ stat -c '%u %U' /
1001 UNKNOWN      ← 根目录属主是一个**不存在的用户**（正常应为 root / 0）
$ id -u
1000              ← 本机账号是 1000
```

systemd 在开机创建静态设备节点前会做安全检查：**路径上每一层的属主必须是可信的**（否则普通用户可能替换路径组件做手脚）。`/ (1001) → /dev (root)` 这个属主跳变被判为 unsafe path transition，于是**跳过创建**：

```console
systemd-tmpfiles[513]: Detected unsafe path transition / (owned by 1001) → /dev (owned by root)
                       during canonicalization of dev/net.      ← 就是这里
```

本次开机共 **21 条**这类报错，涉及 `dev`、`dev/fuse`、`dev/mapper`、`dev/net`、`dev/snd`、`dev/vfio`、`etc/polkit-1`。

**对照实验**最能说明问题：

| 设备节点 | 谁负责创建 | 状态 |
|---|---|---|
| `/dev/kvm`、`/dev/fuse`、`/dev/dri/*` | 内核驱动注册后 **devtmpfs 自动建** | ✅ 都在 |
| `/dev/net/tun`、`/dev/vhost-net`、`/dev/loop-control` | **systemd-tmpfiles 开机建** | ❌ 全缺 |

→ 不是设备系统坏了，**就是 tmpfiles 那一步被安全策略挡掉了**。

## 完整因果链

1. `/` 属主 = 1001（系统里不存在的用户）
2. 开机时 tmpfiles 检测到 unsafe path transition（21 条）→ **拒绝创建 `/dev/net/tun`**
3. 节点不存在 → 任何程序 open 它都得到 **ENOENT**，内核也就无法"按需加载" tun 模块
   （且 `/etc/modules-load.d/` 是空的，没有任何东西主动加载它）
4. FlClash 打开 TUN 后建卡失败 → **但它不报错**，界面开关照样亮着
5. 于是表现为"开着，但没生效"

## 为什么 FlClash 打开 TUN 时不问密码

```console
-rwsr-sr-x 1 root root 64298192  /usr/lib/flclash/FlClashCore
   ↑↑↑ setuid + setgid 位
```

它的内核程序被设了 **setuid root**，任何用户执行都直接是 root —— 所以不问密码、不弹认证框（日志里也没有 pkexec / polkit 认证记录）。`ps` 可见：`flclash`（普通用户）的子进程 `FlClashCore` 身份是 **root**。

> ⚠️ 安全含义：这台机器上**任何程序只要执行它就能拿到 root**。这是该软件包的实现方式（Clash Verge 走的是另一条路：装一个独立的 root 服务），不是配置问题。

**但要注意：这次的失败不是权限问题。** 拿着 root 去 open 一个不存在的设备节点，得到的是 ENOENT（没有那个文件），不是 EPERM（权限不够）。

## 解决

```bash
# ① 立刻补上设备节点（模块加载后 devtmpfs 会自动创建 /dev/net/tun）
~/scripts/desktop/gsudo modprobe tun

# ② 设为开机自动加载（重启也有效）
echo tun | ~/scripts/desktop/gsudo tee /etc/modules-load.d/tun.conf
```

然后在 FlClash 里 **把「虚拟网卡」开关关掉再打开**（或重启 FlClash）。

> 这一步不能省：内核进程是开机就起来的，它尝试建卡失败之后**不会自动重试**，必须手动触发一次。

## 验证

```bash
ls -l /dev/net/tun                            # crw-rw-rw- 10, 200
grep '^tun ' /proc/modules                    # 有 tun 一行
ip -brief link show | grep -i flclash         # FlClash ... UP
ip rule show                                  # 出现 9000 / 9001 / 9002 与 table 2022
curl -s --noproxy '*' https://api.ipify.org   # 返回代理出口 IP = 真生效
```

> **一个坑**：`ip route` 里默认网关**看起来还是物理网卡**，这是**正常的** —— mihomo 用策略路由（另一张路由表），并不替换主默认路由（它得留一条直连去访问代理服务器本身）。
> **判断 TUN 是否生效要看 `ip rule` 和 `curl --noproxy`，不要看主路由表。**

## 副作用与注意事项

1. **DNS 被接管**：本机/容器的解析会返回 **fake-ip**（形如 `198.18.0.6`），再由 mihomo 映射回域名。这是正常现象，但意味着解析依赖 mihomo 存活。
2. **FlClash 成了前置依赖**：它退出后，TUN 的路由与 ip rule 会被撤销，**但系统代理设置不会自动撤销**（GNOME 仍是 `manual → 127.0.0.1:7890`，环境变量也还在）→ 表现为"看着一切正常，却上不了网"。
   **排查口诀：先看 FlClash 还开着吗。**
   （本机已设开机自启：`~/.config/autostart/FlClash.desktop`）
3. **`/` 属主问题没修**：同一个原因还会影响其它 tmpfiles 规则 —— `/dev/vhost-net`（虚拟机网络加速）、`/dev/loop-control`（挂载镜像文件）、`/etc/polkit-1` 权限。
   根治办法是把根目录属主改回 root：`sudo chown root:root /`。**这是全盘根目录，改动前想清楚**（本次没做，只是绕开了影响面）。
4. TUN 生效后，宿主上所有走 host 网络的容器（如 workbuddy2api 网关）流量也会进 TUN；实测网关体检与端到端对话均正常，但**它现在依赖 FlClash 存活**。

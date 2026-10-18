# Clash TUN 模式没生效：为什么、怎么解决的

> 日期：2026-10-01
> 现象：FlClash 里「虚拟网卡」开关**是打开的**，配置文件也写着 `tun: enable: true`，但系统里根本没有虚拟网卡，流量也没被接管 —— 实际只有「系统代理」在工作。
> 结果：已修复。补上 `/dev/net/tun` 设备节点 + 设为开机自动加载，TUN 实测生效。
> 环境：Arch Linux + niri（Wayland）+ FlClash 0.8.96（archlinuxcn）+ linux-zen 7.2.7。
>
> 2026-10-06 补记：升级 FlClash 0.8.99 后出现**同样表象、不同根因**（helper 服务对核心做哈希校验、因打包不一致而失败），且旧问题（`/` 属主、`/dev/net/tun`）已根治。处理记录见文末「2026-10-06 补记」。
>
> 2026-10-17 补记：第三次「开关开着、无网卡」，根因是**开机竞态** —— helper 排在 `network-online.target` 之后（本次开机第 68 秒才起），而 FlClash 的 xdg 自启第 18 秒就拉起了无特权核心；应用之后不会重试。见文末「2026-10-17 补记」。

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
ps -eo pid,ppid,user,euser,lstart,args | grep -i flclash   # 核心须 EUSER=root 且 PPID=helper
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

> 2026-10-06 更新：0.8.99 起 FlClash 在 Linux 上**不再用 setuid**，改为系统服务方案（`flclash-helper.service`，首次由应用弹密码经 pkexec 安装）——本节描述的是 0.8.96 及更早版本的行为；新机制与新的排查判据见文末补记。

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

   > 2026-10-06 更新：**已根治** —— 根目录属主已改回 `root:root`，本次开机 0 条 unsafe path 报错；`/dev/vhost-net`、`/dev/loop-control` 均已正常创建。

4. TUN 生效后，宿主上所有走 host 网络的容器（如 workbuddy2api 网关）流量也会进 TUN；实测网关体检与端到端对话均正常，但**它现在依赖 FlClash 存活**。
5. **core 是 helper 的子进程**（同一 cgroup）：`systemctl restart flclash-helper` 会一并杀掉核心，**必须接着重启 FlClash 应用**，否则又落到无特权核心。

## 2026-10-06 补记：升级 0.8.99 后又是「开关开着但不生效」（helper 核心哈希校验失败）

> 前提更新：本条与上方旧问题无关 —— `/` 属主已改回 `root:root`，开机无 unsafe path 报错；`/dev/net/tun` 由 systemd-tmpfiles 正常创建、打开时自动加载 tun 模块，`modules-load.d` 方案已不需要。

### 机制变化（0.8.99 起）

- Linux 的 TUN 改由特权服务 **`flclash-helper.service`**（二进制 `/usr/lib/flclash/FlClashHelperService`，单元文件在 `/etc/systemd/system/`，首次由应用弹密码经 pkexec 安装并 enable）负责：helper 以 root 身份拉起核心（核心成为 helper 的子进程、EUID=root），TUN 才建得起来。
- helper 启动核心前会**校验核心文件的 SHA256**：期望值编译时写死在 helper 里，同时记录在 `/usr/lib/flclash/manifest.json`。校验失败时应用**不报错，而是静默回退到无特权的直连核心** —— 表现就是「开关开着，但 TUN 不生效」。

### 根因（2026-10-06 实测）

archlinuxcn 的 **flclash 0.8.99-3 打包不一致**：包内 `FlClashCore` 实际哈希为 `103dc05a…`（打包方本地构建），而 helper 常量与 `manifest.json` 里是上游预构建核心的 `a1841621…`（`pacman -Qkk` 证实不是安装后被改）。helper 校验不过 → 拒绝启动核心 → 应用回退直连核心 → TUN 永远建不起来。

### 新判据（定位本次问题用得上）

```bash
# ① 核心是否由 helper 拉起：父进程应为 helper、EUID 应为 root；父进程是应用则是回退后的直连核心
ps -eo pid,ppid,user,euser,comm,args | grep -i flclash

# ② 直接问 helper：喂实际核心哈希，正常返回 helper 路径；返回 coreSha256Mismatch 即打包哈希不一致
curl -s --http2-prior-knowledge --unix-socket /run/flclash/helper.sock \
  -H 'x-flclash-helper-protocol: 6' \
  "http://localhost/ping?coreSha256=$(sha256sum /usr/lib/flclash/FlClashCore | awk '{print $1}')"

# ③ helper 自己的环形日志（校验/自检记录都在里面）
curl -s --http2-prior-knowledge --unix-socket /run/flclash/helper.sock \
  -H 'x-flclash-helper-protocol: 6' http://localhost/logs
```

核心由 helper 拉起后，核心日志会进 `journalctl -u flclash-helper.service`。

### 解决（本地绕过打包 bug；2026-10-06 已实施）

把 helper 内的期望哈希常量与 `manifest.json` **同时**改成当前核心的真实哈希（只改一边会被 helper 的 `/ping` 拒绝）：

```bash
NEW=$(sha256sum /usr/lib/flclash/FlClashCore | awk '{print $1}')
~/scripts/desktop/gsudo systemctl stop flclash-helper   # 运行中的二进制不能就地写入（Text file busy）
~/scripts/desktop/gsudo python3 - "$NEW" <<'PY'
import json, sys
new = sys.argv[1]
hp, mp = '/usr/lib/flclash/FlClashHelperService', '/usr/lib/flclash/manifest.json'
old = json.load(open(mp))['coreSha256']
b = open(hp, 'rb').read()
n = b.count(old.encode())
assert n >= 1, f'helper 中未找到 {old}'
open(hp, 'wb').write(b.replace(old.encode(), new.encode()))
open(mp, 'w').write(json.dumps({'coreSha256': new}, separators=(',', ':')) + '\n')
print(f'helper 替换 {n} 处，manifest 已更新')
PY
~/scripts/desktop/gsudo systemctl start flclash-helper
# 然后重启 FlClash（完全退出后重新打开），再按正文的方法验证 TUN
```

> 本次原文件备份与恢复说明：`/var/backups/flclash-0.8.99-3-hash-repair-20261006-132933/`。恢复途径：用备份文件覆盖后重启 helper 服务，或直接 `pacman -S flclash` 重装。

### 注意事项

- **每次 flclash 更新后复查**：`sha256sum /usr/lib/flclash/FlClashCore` 与 `manifest.json`、helper 内常量（`strings /usr/lib/flclash/FlClashHelperService | grep -E '^[0-9a-f]{64}$'`）比对；不一致就按上面重打，或等上游修复。`pacman -Qkk flclash` 会对被改的两个文件报「校验和不一致」，属预期。
- 修复效果判据与正文相同：`ip rule` 出现 9000/9001/9002/9010，`curl -s --noproxy '*' https://api.ipify.org` 等于代理出口 IP。本次实测全部通过（网卡 `FlClash`，198.18.0.1/30）。

## 2026-10-17 补记：第三次同样表象，根因是开机竞态（helper 起得比应用晚）

> 环境：FlClash 0.8.99-4（archlinuxcn）、systemd 262、0.8.99 的 helper 机制。
> 现象：`ip link` 没有 `FlClash` 网卡、`ip rule` 只有 0 / 32766 / 32767，但界面里虚拟网卡开关是开的；系统代理（gsettings `manual → 127.0.0.1:7890`）正常，浏览器能翻墙。
> 结果：已修复，TUN 实测生效。同样**不是**前面两个根因 —— `/dev/net/tun` 正常、helper 哈希校验也通过。

### 判据：先看核心是谁拉起的

```bash
ps -eo pid,ppid,user,euser,lstart,args | grep -i flclash
```

| 输出 | 含义 |
|---|---|
| `FlClashCore` 的 `PPID` = helper 的 PID、`EUSER` = `root` | ✅ 特权核心，TUN 才有戏 |
| `PPID` = `FlClash` 应用、`EUSER` = 当前用户 | ❌ 回退后的无特权核心，TUN 必然建不起来 |

### 本次实测

| 检查 | 结果 |
|---|---|
| `ls -l /dev/net/tun` | `crw-rw-rw- root root 10,200`，`open()` 成功，`tun` 模块随打开自动加载 |
| `stat -c '%u %U' /` | `0 root`（旧问题已根治） |
| helper `/ping?coreSha256=<真实哈希>` | `200`，`manifest.json` 与核心哈希一致（`a1841621…`） |
| 核心属主 | `PPID=1352`（应用）`EUSER=pang` |
| 运行时 `tun.enable` | **false**（应用自己降级写回的） |
| 启动时间（monotonic） | 应用 `T+18s`、核心 `T+20s`、**helper `T+68s`** |
| `network-online.target` | `T+68.2s`，且排在 `docker.service`、`rjsupplicant.service` 之后 |
| `multi-user.target` | `T+80.5s`（`user@1000.service` 已在 `T+11s` 起来） |

### 根因

单元里 `After=network-online.target` 把 helper 排到了 `network-online.target` 后面，而这个 target 要等 `docker.service` + `rjsupplicant.service`；FlClash 的 xdg 自启却在 `user@1000.service`（`T+11s`）之后、第 18 秒就拉核心。

应用先起 → 连不上 helper 的 socket（尚未就绪）→ 只能拉起无特权核心 → 没有 `CAP_NET_ADMIN`，TUN 建不起来 → 应用把 `tun.enable` 写成 `false`，**而且之后不会重试**。界面开关来自持久化设置，于是长期停在「开着但不生效」。

### 解决

1. **立刻恢复**：helper 已在运行时，把 FlClash 完全退出再启动即可（这时应用会改由 helper 拉起核心）。

   ```bash
   kill -TERM $(pgrep -x FlClash)                       # 完全退出（核心随之结束）
   setsid /usr/lib/flclash/FlClash >/dev/null 2>&1 &    # 重新启动
   ```

2. **根治开机竞态**：把 `After=` 里的 `network-online.target` 去掉 —— helper 只负责以 root 拉起核心，不需要网络就绪。

   ```console
   $ grep '^After=' /etc/systemd/system/flclash-helper.service
   After=nftables.service iptables.service     # 原为: After=network-online.target nftables.service iptables.service
   ```

   > **为什么不用 drop-in**：`After=` 空值「重置依赖列表」在 systemd 262 上**实测无效**。对照实验：自建 `zz-test.service`（主单元 `After=zz-foo.service network-online.target`）+ drop-in 写空 `After=`，`daemon-reload` 后 `systemctl show -p After` 里两项仍在。排序依赖只能改主单元文件。

   改前备份：`/var/backups/flclash-20261017-unit/flclash-helper.service.orig`。

   改完后 helper 只等 `basic.target`（本次 `T+7.9s`）与 `nftables/iptables`（本次未启用，启用时也在早期启动），比应用自启的 `T+18s` 早约 10 秒。

### 验证

```bash
ip -brief addr show FlClash                          # FlClash ... 198.18.0.1/30
ip rule show | grep -cE '900[0-2]|9010'              # 7 条
ps -o pid,ppid,user,euser -p $(pgrep -x FlClashCore) # PPID=helper, EUSER=root
curl -s https://api.ipify.org                        # 172.105.121.164 ← 走系统代理
curl -s --noproxy '*' https://api.ipify.org          # 172.105.121.164 ← 绕过代理同一个 IP = TUN 生效
curl -s --http2-prior-knowledge --unix-socket /run/flclash/helper.sock \
  -H 'x-flclash-helper-protocol: 6' \
  "http://localhost/ping?coreSha256=$(sha256sum /usr/lib/flclash/FlClashCore | awk '{print $1}')"   # 200
```

顺带验证了最初触发排查的场景：`env -u http_proxy -u https_proxy … curl raw.githubusercontent.com/…/v1.3.0/LICENSE` → `200`（0.34s）。TUN 接管 IP 层后，`makepkg` 即使拿不到代理环境变量也不会再卡在 0 字节。

### 注意

- **单元文件不属于任何软件包**：`pacman -Qo /etc/systemd/system/flclash-helper.service` 报「没有软件包拥有」，它是应用首次运行时经 pkexec 装出来的。**FlClash 升级后复查** `grep '^After=' /etc/systemd/system/flclash-helper.service`，被写回就再删一次 `network-online.target`。
- 若某次开机仍出现同样表象（应用自启早于 helper，如磁盘慢、开机慢），临时办法照旧：**重启 FlClash**，不必去动 TUN 开关。
- 本次开机 `nftables.service` / `iptables.service` 实际未启动（`ActiveEnterTimestamp` 为空），helper 等效只等 `basic.target`；将来启用它们也不改变上面的时间余量。


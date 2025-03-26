# Soundness Labs 白名单注册指南

## 项目说明
Soundness Labs 是 Sui 网络上的 ZK 验证层，得到了 @SuccinctLabs @SuiNetwork @WalrusProtocol 等顶级项目的支持。本项目提供了自动化的测试网白名单注册工具，支持批量生成和管理密钥。
## 快速开始

### 方式一：一键安装（推荐）
1. 下载安装脚本
```bash
wget -O install_soundness.sh https://raw.githubusercontent.com/0xbaiwan/soundness_bot/main/install_soundness.sh
```
2. 添加执行权限
```bash
chmod +x install_soundness.sh
```
3. 运行安装脚本
```bash
./install_soundness.sh
```

### 方式二：手动安装

1. 安装 Rust（如已安装可跳过）
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

2. 安装 Soundness CLI
```bash
curl -sSL https://raw.githubusercontent.com/soundnesslabs/soundness-layer/main/soundnessup/install | bash
source ~/.bashrc
soundnessup install
soundnessup update
```

3. 生成密钥

- 生成单个密钥
```bash
soundness-cli generate-key --name my-key
```
- 批量生成密钥
```bash
./install_soundness.sh 10  # 生成10个密钥
./install_soundness.sh 20  # 生成20个密钥
```
- 查询已生成的密钥
```bash
./install_soundness.sh query
```

### 批量生成说明
- 批量生成的密钥将保存在 `./soundness_keys` 目录下
- 文件名格式为 `keys_时间戳.txt`
- 每个密钥都会有清晰的分隔标记
- 请务必妥善保存生成的助记词

### 密钥管理建议
- 建议将生成的密钥文件备份到安全的离线存储设备
- 每个密钥文件建议设置强密码保护
- 定期检查密钥的有效性
- 不要在不安全的网络环境下传输密钥文件

### 密钥文件格式说明
生成的 `keys_时间戳.txt` 文件内容格式如下：

```
=== Soundness Keys Generated at 2024-03-15 10:30:45 ===
----------------------------------------
=== Key 1: lucky_tiger_1234 ===
Key name: lucky_tiger_1234
Public key: 0x123...abc
Recovery phrase: word1 word2 word3 ... word24
----------------------------------------
=== Key 2: brave_eagle_5678 ===
Key name: brave_eagle_5678
Public key: 0x456...def
Recovery phrase: word1 word2 word3 ... word24
----------------------------------------
... (其他密钥信息)
```

每个密钥记录包含：
- 密钥名称：随机生成的形如 "形容词_动物_数字" 的组合
- 公钥地址（Public key）
- 24个助记词（Recovery phrase）

### 密钥生成策略
- 每个密钥名称都是独特的随机组合
- 生成过程包含随机时间间隔（2-5秒）
- 命名格式自然，避免机械的序号命名

### 密钥查询功能说明
- 使用 `./install_soundness.sh query` 查看已生成的密钥
- 按时间倒序显示所有密钥文件
- 可以选择具体文件查看详细内容
- 建议定期备份密钥文件

## 注意事项
- 请确保系统为 Ubuntu 22.04
- 务必保存生成的24个助记词
- 如遇安装问题，请查看错误日志或访问官方文档

## 常见问题解决
1. Rust 安装失败
   - 检查网络连接
   - 确保系统已更新：`sudo apt update && sudo apt upgrade`

2. Soundness CLI 安装失败
   - 检查 Rust 是否正确安装
   - 尝试清除缓存后重新安装


## 功能特点
- 支持单个/批量生成密钥
- 智能随机命名系统
- 密钥查询和管理功能
- 安全的密钥存储方案

## 系统要求
- Ubuntu 22.04 或更高版本
- 稳定的网络连接

## 相关链接
- [项目仓库](https://github.com/0xbaiwan/soundness_bot)
- [Soundness Labs 官方文档](https://github.com/SoundnessLabs/soundness-layer)
- [问题反馈](https://github.com/0xbaiwan/soundness_bot/issues)
- [Soundness Labs Discord](https://discord.gg/soundnesslabs)


## 免责声明
本工具仅用于简化 Soundness Labs 测试网注册流程，请遵守相关规则和条款。作者不对使用本工具造成的任何损失负责。

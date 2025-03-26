# Soundness Labs 白名单注册指南

## 项目说明
Soundness Labs 是 Sui 网络上的 ZK 验证层，得到了 @SuccinctLabs @SuiNetwork @WalrusProtocol 等顶级项目的支持。本项目提供了自动化的测试网白名单注册工具，支持批量生成和管理密钥。

## 功能特点
- 支持单个/批量生成密钥
- 智能随机命名系统
- 自动化密码处理（无需手动输入）
- 密钥查询和管理功能
- 安全的密钥存储方案

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
./install_soundness.sh
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

### 密钥生成说明
- 所有密钥使用空密码生成（全自动处理）
- 密钥名称采用随机组合：形容词_动物_数字
- 批量生成时会自动添加2-5秒随机延迟
- 所有密钥信息保存在 `./soundness_keys` 目录下

### 密钥文件格式
生成的 `keys_时间戳.txt` 文件内容格式如下：
```
=== Soundness Keys Generated at 2024-03-15 10:30:45 ===
Total keys to generate: 10
----------------------------------------

=== Key: lucky_tiger_1234 ===
----------------------------------------
[完整的密钥信息和助记词]
----------------------------------------

=== Key: brave_eagle_5678 ===
----------------------------------------
[完整的密钥信息和助记词]
----------------------------------------

=== Generation Summary ===
Total attempted: 10
Successfully generated: 10
Failed: 0
----------------------------------------
```

### 密钥管理建议
- 生成后立即备份密钥文件
- 将备份文件存储在安全的离线设备中
- 定期检查密钥的有效性
- 不要在不安全的网络环境下传输密钥文件

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

# Soundness Labs 测试网白名单管理工具

这是一个用于管理 Soundness Labs 测试网白名单注册的命令行工具。该工具提供了简单的交互式界面，帮助用户轻松完成白名单注册流程。

## 🚀 一键运行

复制以下命令到终端运行即可：

```bash
curl -sSL https://raw.githubusercontent.com/0xbaiwan/soundness_bot/main/soundness_manager.sh > /tmp/soundness_manager.sh && bash /tmp/soundness_manager.sh
```

## 功能特点

- 🔑 批量生成密钥对（单次最多10个）
- 📝 自动保存密钥信息
- 👀 查看已生成的所有密钥
- 💾 密钥文件自动备份功能
- 🔒 安全的文件权限管理
- 🎨 彩色命令行界面
- ✨ 简单易用的交互菜单
- 🛠️ 自动安装所需依赖
- 🔄 安装失败自动重试
- ⏱️ 密钥生成时间记录

## 使用说明

1. 在主菜单中选择操作：
   - 选项 1：注册白名单（如果未安装依赖，会自动安装）
   - 选项 2：查看密钥信息
   - 选项 3：备份密钥文件
   - 选项 4：退出程序

2. 密钥信息存储：
   - 所有生成的密钥信息将保存在 `~/.soundness_keys.txt` 文件中
   - 包含密钥名称、公钥和助记词
   - 自动记录生成时间
   - 文件权限自动设置为600（仅用户可读写）

## 安全特性

- 🔐 密钥文件权限自动管理
- 📦 自动备份功能
- 🛡️ 防止重复执行
- 💽 磁盘空间检查
- ⚠️ 错误处理和重试机制

## 注意事项

- 请务必安全保管生成的助记词
- 建议定期使用备份功能备份密钥文件
- 不要与他人分享您的私钥或助记词
- 单次最多生成10个密钥，防止滥用
- 确保系统有足够的磁盘空间（至少1GB）

## 环境要求

- Ubuntu 22.04 或其他 Linux 发行版
- 网络连接正常
- 至少1GB可用磁盘空间

## 贡献指南

欢迎提交 Issue 和 Pull Request 来帮助改进这个工具。

## 许可证

MIT License

## 相关链接

- [Soundness Labs GitHub](https://github.com/SoundnessLabs/soundness-layer)
- [官方文档](https://github.com/SoundnessLabs/soundness-layer/tree/main/soundness-cli)

## 支持项目

- @SuccinctLabs
- @SuiNetwork
- @WalrusProtocol

## 更新日志

### v1.1.0
- 添加密钥文件备份功能
- 添加安全性检查
- 改进错误处理机制
- 添加安装重试功能
- 优化环境变量处理

### v1.0.0
- 初始版本发布
- 实现基本的白名单注册功能
- 添加密钥管理功能

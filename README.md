# Soundness Labs 测试网白名单管理工具

这是一个用于管理 Soundness Labs 测试网白名单注册的命令行工具。该工具提供了简单的交互式界面，帮助用户轻松完成白名单注册流程。

## 🚀 一键运行

复制以下命令到终端运行即可：

```bash
curl -sSL https://raw.githubusercontent.com/0xbaiwan/soundness_bot/main/soundness_manager.sh | bash
```

## 功能特点

- 🔑 批量生成密钥对
- 📝 自动保存密钥信息
- 👀 查看已生成的所有密钥
- 🎨 彩色命令行界面
- ✨ 简单易用的交互菜单
- 🛠️ 自动安装所需依赖

## 使用说明

1. 在主菜单中选择操作：
   - 选项 1：注册白名单（如果未安装依赖，会自动安装）
   - 选项 2：查看已保存的密钥信息
   - 选项 3：退出程序

2. 密钥信息存储：
   - 所有生成的密钥信息将保存在 `~/.soundness_keys.txt` 文件中
   - 包含密钥名称、公钥和助记词

## 注意事项

- 请务必安全保管生成的助记词
- 建议对 `~/.soundness_keys.txt` 文件进行备份
- 不要与他人分享您的私钥或助记词

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

### v1.0.0
- 初始版本发布
- 实现基本的白名单注册功能
- 添加密钥管理功能

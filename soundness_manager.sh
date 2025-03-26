#!/bin/bash

# 关闭未绑定变量的错误检查，仅对脚本开头部分
set +u

# 防止重复执行
if [ -n "${SCRIPT_RUNNING:-}" ]; then
    exit 0
fi
export SCRIPT_RUNNING=1

# 开启严格模式
set -euo pipefail
umask 077  # 设置文件权限

# 存储密钥信息的文件
KEYS_FILE="$HOME/.soundness_keys.txt"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 添加文件权限检查
check_file_permissions() {
    if [ -f "$KEYS_FILE" ]; then
        current_perms=$(stat -c "%a" "$KEYS_FILE")
        if [ "$current_perms" != "600" ]; then
            chmod 600 "$KEYS_FILE"
            echo -e "${BLUE}已修复密钥文件权限${NC}"
        fi
    fi
}

# 加载环境变量
load_env() {
    # 加载 Cargo 环境
    if [ -f "$HOME/.cargo/env" ]; then
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
    fi
    
    # 设置 PATH（确保不重复添加）
    if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
    if [[ ":$PATH:" != *":$HOME/.soundness/bin:"* ]]; then
        export PATH="$HOME/.soundness/bin:$PATH"
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}正在安装必要组件...${NC}"
    
    # 检查并安装 Rust
    if ! command -v cargo &> /dev/null; then
        echo -e "${GREEN}安装 Rust...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || {
            echo -e "${RED}Rust 安装失败${NC}"
            return 1
        }
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
    fi

    # 安装 soundness-cli
    echo -e "${GREEN}安装 soundness-cli...${NC}"
    curl -sSL https://raw.githubusercontent.com/soundnesslabs/soundness-layer/main/soundnessup/install | bash || {
        echo -e "${RED}soundness-cli 安装失败${NC}"
        return 1
    }
    
    # 更新环境变量
    load_env
    
    # 添加环境变量到 .bashrc（如果不存在）
    {
        echo 'export PATH="$HOME/.soundness/bin:$PATH"'
        echo 'export PATH="$HOME/.cargo/bin:$PATH"'
    } >> "$HOME/.bashrc.tmp"
    
    # 安全地更新 .bashrc
    if [ -f "$HOME/.bashrc.tmp" ]; then
        # 移除已存在的相同行
        grep -v "export PATH.*soundness/bin\|export PATH.*cargo/bin" "$HOME/.bashrc" > "$HOME/.bashrc.new" || true
        cat "$HOME/.bashrc.tmp" >> "$HOME/.bashrc.new"
        mv "$HOME/.bashrc.new" "$HOME/.bashrc"
        rm -f "$HOME/.bashrc.tmp"
    fi

    # 安装和更新 soundness
    echo -e "${GREEN}安装和更新 soundness...${NC}"
    
    # 尝试多次安装（有时候第一次可能失败）
    for i in {1..3}; do
        if soundnessup install; then
            break
        elif [ "$i" -eq 3 ]; then
            echo -e "${RED}soundness 安装失败，已重试 3 次${NC}"
            return 1
        else
            echo -e "${BLUE}安装失败，正在重试 ($i/3)...${NC}"
            sleep 2
        fi
    done

    # 更新 soundness
    soundnessup update || {
        echo -e "${RED}soundness 更新失败${NC}"
        return 1
    }

    echo -e "${GREEN}依赖安装完成！${NC}"
    return 0
}

# 检查必要的命令是否安装
check_requirements() {
    if ! command -v soundness-cli &> /dev/null; then
        echo -e "${BLUE}检测到未安装必要组件，开始安装...${NC}"
        install_dependencies
        
        # 验证安装结果
        if ! command -v soundness-cli &> /dev/null; then
            echo -e "${RED}安装失败，请尝试手动安装：${NC}"
            echo "1. curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
            echo "2. source \$HOME/.cargo/env"
            echo "3. curl -sSL https://raw.githubusercontent.com/soundnesslabs/soundness-layer/main/soundnessup/install | bash"
            echo "4. source ~/.bashrc"
            echo "5. soundnessup install"
            echo "6. soundnessup update"
            exit 1
        fi
    fi
}

# 生成并保存密钥
generate_keys() {
    local count=$1
    
    # 验证输入数量
    if [ "$count" -gt 10 ]; then
        echo -e "${RED}为防止滥用，单次最多生成 10 个密钥${NC}"
        return 1
    fi
    
    # 检查磁盘空间
    if [ "$(df -P "$HOME" | awk 'NR==2 {print $4}')" -lt 1048576 ]; then
        echo -e "${RED}磁盘空间不足，请确保有至少 1GB 可用空间${NC}"
        return 1
    fi
    
    for ((i=1; i<=count; i++)); do
        echo -e "${GREEN}正在生成第 $i 个密钥...${NC}"
        local key_name="soundness_key_$i"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # 生成密钥并捕获输出
        output=$(soundness-cli generate-key --name "$key_name" 2>&1)
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}生成密钥失败，请确保 soundness-cli 已正确安装${NC}"
            return 1
        fi
        
        # 提取公钥和助记词
        public_key=$(echo "$output" | grep "Public key:" | cut -d' ' -f3)
        mnemonic=$(echo "$output" | grep -A 1 "Mnemonic:" | tail -n 1)
        
        # 更严格的输出验证
        if [ -z "$public_key" ] || [ -z "$mnemonic" ]; then
            echo -e "${RED}无法提取密钥信息，请重试${NC}"
            return 1
        fi
        
        # 保存到文件（时间戳放在开头）
        {
            echo "------------------------"
            echo "Generated at: $timestamp"
            echo "Key $i:"
            echo "Name: $key_name"
            echo "Public Key: $public_key"
            echo "Mnemonic: $mnemonic"
            echo "------------------------"
        } >> "$KEYS_FILE"
        
        echo -e "${GREEN}第 $i 个密钥生成完成${NC}"
        echo "------------------------"
    done
}

# 显示所有密钥信息
show_keys() {
    if [ -f "$KEYS_FILE" ]; then
        echo -e "${BLUE}已保存的密钥信息：${NC}"
        cat "$KEYS_FILE"
    else
        echo -e "${RED}未找到已保存的密钥信息${NC}"
    fi
}

# 添加备份函数
backup_keys() {
    if [ -f "$KEYS_FILE" ]; then
        backup_file="$KEYS_FILE.$(date +%Y%m%d_%H%M%S).bak"
        cp "$KEYS_FILE" "$backup_file"
        echo -e "${GREEN}已创建备份: $backup_file${NC}"
    fi
}

# 主菜单
show_menu() {
    while true; do
        echo -e "\n${BLUE}=== Soundness Labs 测试网白名单管理 ===${NC}"
        echo "1. 注册白名单"
        echo "2. 查看密钥信息"
        echo "3. 备份密钥文件"
        echo "4. 退出"
        echo -n "请选择操作 (1-4): "
        
        read choice
        case $choice in
            1)
                echo -n "请输入要注册的账号数量: "
                read count
                if [[ "$count" =~ ^[0-9]+$ ]]; then
                    check_requirements
                    generate_keys "$count"
                else
                    echo -e "${RED}请输入有效的数字${NC}"
                fi
                ;;
            2)
                show_keys
                ;;
            3)
                backup_keys
                ;;
            4)
                echo -e "${GREEN}感谢使用，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择，请重试${NC}"
                ;;
        esac
    done
}

# 添加清理函数
cleanup() {
    # 清理临时文件
    rm -f /tmp/soundness_*.tmp 2>/dev/null || true
    
    # 重置终端颜色
    echo -e "${NC}"
}

# 添加信号处理
trap cleanup EXIT
trap 'echo -e "${RED}脚本被中断${NC}"; exit 1' INT TERM

# 主程序入口
main() {
    check_file_permissions
    
    # 确保密钥文件存在
    touch "$KEYS_FILE"
    
    # 加载环境变量
    load_env
    
    # 运行菜单
    show_menu
}

# 运行主程序
main 

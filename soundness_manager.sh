#!/bin/bash
set -euo pipefail  # 严格模式
umask 077  # 设置文件权限

# 初始化 SCRIPT_RUNNING 变量
SCRIPT_RUNNING=${SCRIPT_RUNNING:-}

# 防止重复执行
if [ -n "${SCRIPT_RUNNING:-}" ]; then
    exit 0
fi
export SCRIPT_RUNNING=1

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

# 添加进度显示函数
show_progress() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}正在安装必要组件...${NC}"
    (
        # 检查并安装 Rust
        if ! command -v cargo &> /dev/null; then
            echo -e "${GREEN}安装 Rust...${NC}"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
        fi

        # 安装 soundness-cli
        echo -e "${GREEN}安装 soundness-cli...${NC}"
        curl -sSL https://raw.githubusercontent.com/soundnesslabs/soundness-layer/main/soundnessup/install | bash
        export PATH="$HOME/.soundness/bin:$PATH"
        source "$HOME/.bashrc"
        soundnessup install
        soundnessup update

        # 添加环境变量到 .bashrc 如果不存在
        if ! grep -q "PATH=\"\$HOME/.soundness/bin:\$PATH\"" "$HOME/.bashrc"; then
            echo 'export PATH="$HOME/.soundness/bin:$PATH"' >> "$HOME/.bashrc"
        fi
        if ! grep -q "PATH=\"\$HOME/.cargo/bin:\$PATH\"" "$HOME/.bashrc"; then
            echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
        fi

        # 等待安装完成
        sleep 2
        echo -e "${GREEN}依赖安装完成！${NC}"
    ) &
    show_progress $!
}

# 检查必要的命令是否安装
check_requirements() {
    if ! command -v soundness-cli &> /dev/null; then
        echo -e "${BLUE}检测到未安装必要组件，开始安装...${NC}"
        install_dependencies
        # 重新加载环境变量
        source "$HOME/.bashrc"
        export PATH="$HOME/.soundness/bin:$PATH"
        if ! command -v soundness-cli &> /dev/null; then
            echo -e "${RED}安装失败，请手动安装依赖${NC}"
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
        
        # 保存到文件
        echo "Key $i:" >> "$KEYS_FILE"
        echo "Name: $key_name" >> "$KEYS_FILE"
        echo "Public Key: $public_key" >> "$KEYS_FILE"
        echo "Mnemonic: $mnemonic" >> "$KEYS_FILE"
        echo "------------------------" >> "$KEYS_FILE"
        
        # 添加时间戳
        echo "Generated at: $(date '+%Y-%m-%d %H:%M:%S')" >> "$KEYS_FILE"
        
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
    
    # 设置环境变量
    export PATH="$HOME/.cargo/bin:$HOME/.soundness/bin:$PATH"
    
    # 运行菜单
    show_menu
}

# 运行主程序
main 

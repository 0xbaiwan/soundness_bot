#!/bin/bash

# 防止重复执行
if [ -n "$SCRIPT_RUNNING" ]; then
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

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}正在安装必要组件...${NC}"
    
    # 检查并安装 Rust
    if ! command -v cargo &> /dev/null; then
        echo -e "${GREEN}安装 Rust...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
    fi

    # 安装 soundness-cli
    echo -e "${GREEN}安装 soundness-cli...${NC}"
    curl -sSL https://raw.githubusercontent.com/soundnesslabs/soundness-layer/main/soundnessup/install | bash
    source ~/.bashrc
    soundnessup install
    soundnessup update

    echo -e "${GREEN}依赖安装完成！${NC}"
}

# 检查必要的命令是否安装
check_requirements() {
    if ! command -v soundness-cli &> /dev/null; then
        echo -e "${BLUE}检测到未安装必要组件，开始安装...${NC}"
        install_dependencies
    fi
}

# 生成并保存密钥
generate_keys() {
    local count=$1
    for ((i=1; i<=count; i++)); do
        echo -e "${GREEN}正在生成第 $i 个密钥...${NC}"
        local key_name="soundness_key_$i"
        
        # 生成密钥并捕获输出
        output=$(soundness-cli generate-key --name "$key_name" 2>&1)
        
        # 提取公钥和助记词
        public_key=$(echo "$output" | grep "Public key:" | cut -d' ' -f3)
        mnemonic=$(echo "$output" | grep -A 1 "Mnemonic:" | tail -n 1)
        
        # 保存到文件
        echo "Key $i:" >> "$KEYS_FILE"
        echo "Name: $key_name" >> "$KEYS_FILE"
        echo "Public Key: $public_key" >> "$KEYS_FILE"
        echo "Mnemonic: $mnemonic" >> "$KEYS_FILE"
        echo "------------------------" >> "$KEYS_FILE"
        
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

# 主菜单
show_menu() {
    while true; do
        echo -e "\n${BLUE}=== Soundness Labs 测试网白名单管理 ===${NC}"
        echo "1. 注册白名单"
        echo "2. 查看密钥信息"
        echo "3. 退出"
        echo -n "请选择操作 (1-3): "
        
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
                echo -e "${GREEN}感谢使用，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择，请重试${NC}"
                ;;
        esac
    done
}

# 主程序入口
main() {
    # 创建临时脚本文件
    TMP_SCRIPT=$(mktemp)
    cat > "$TMP_SCRIPT" << 'EOF'
#!/bin/bash
# 确保密钥文件存在
touch "$HOME/.soundness_keys.txt"
# 运行菜单
$(declare -f show_menu generate_keys show_keys check_requirements install_dependencies)
show_menu
EOF
    
    # 添加执行权限并运行
    chmod +x "$TMP_SCRIPT"
    bash "$TMP_SCRIPT"
    rm "$TMP_SCRIPT"
}

# 如果是直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 

#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "开始安装 Soundness Labs 测试网环境..."

# 检查系统要求
check_system() {
    if [ ! -f /etc/lsb-release ]; then
        echo "${RED}错误: 仅支持 Ubuntu 系统${NC}"
        exit 1
    fi
}

# 检查并安装 Rust
install_rust() {
    if ! command -v cargo &> /dev/null; then
        echo "正在安装 Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
    else
        echo "Rust 已安装，跳过..."
    fi
}

# 安装 Soundness CLI
install_soundness() {
    echo "正在安装 Soundness CLI..."
    curl -sSL https://raw.githubusercontent.com/soundnesslabs/soundness-layer/main/soundnessup/install | bash
    source ~/.bashrc
    
    echo "正在更新 Soundness..."
    soundnessup install
    soundnessup update
}

# 生成随机密钥名称
generate_random_name() {
    # 常用单词库
    local adjectives=("happy" "lucky" "sunny" "clever" "bright" "swift" "calm" "wise" "brave" "noble" "proud" "kind" "pure" "fair" "bold")
    local nouns=("tiger" "eagle" "wolf" "bear" "lion" "hawk" "deer" "fox" "owl" "whale" "seal" "dove" "swan" "fish" "bird")
    
    # 随机选择单词
    local adj=${adjectives[$((RANDOM % ${#adjectives[@]}))]}
    local noun=${nouns[$((RANDOM % ${#nouns[@]}))]}
    
    # 生成3-4位随机数字
    local num=$((RANDOM % 9000 + 1000))
    
    # 组合名称
    echo "${adj}_${noun}_${num}"
}

# 批量生成密钥
generate_multiple_keys() {
    local count=$1
    echo "正在批量生成 ${count} 个密钥..."
    echo "${RED}注意：请务必保存每组生成的24个助记词！${NC}"
    
    # 创建日志目录
    mkdir -p ./soundness_keys
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="./soundness_keys/keys_${timestamp}.txt"
    
    echo "=== Soundness Keys Generated at $(date) ===" > "$log_file"
    echo "----------------------------------------" >> "$log_file"
    
    for i in $(seq 1 $count); do
        local key_name=$(generate_random_name)
        echo "${GREEN}正在生成密钥 $key_name...${NC}"
        echo "=== Key $i: $key_name ===" >> "$log_file"
        soundness-cli generate-key --name "$key_name" | tee -a "$log_file"
        echo "----------------------------------------" >> "$log_file"
        # 随机延迟2-5秒
        sleep $((RANDOM % 4 + 2))
    done
    
    echo "${GREEN}所有密钥已生成完成！${NC}"
    echo "密钥信息已保存至: $log_file"
}

# 查询密钥信息
query_keys() {
    local keys_dir="./soundness_keys"
    
    if [ ! -d "$keys_dir" ]; then
        echo "${RED}未找到密钥目录！${NC}"
        return 1
    }
    
    echo "${GREEN}=== 密钥文件列表 ===${NC}"
    local files=($(ls -t $keys_dir))
    
    if [ ${#files[@]} -eq 0 ]; then
        echo "${RED}未找到任何密钥文件${NC}"
        return 1
    }
    
    for ((i=0; i<${#files[@]}; i++)); do
        echo "[$((i+1))] ${files[$i]}"
    done
    
    echo -n "请选择要查看的文件编号 (1-${#files[@]}): "
    read choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#files[@]} ]; then
        echo "${GREEN}=== 文件内容 ===${NC}"
        cat "$keys_dir/${files[$((choice-1))]}"
    else
        echo "${RED}无效的选择！${NC}"
        return 1
    fi
}

# 修改主流程，添加参数支持
main() {
    if [ "$1" = "query" ]; then
        query_keys
        return
    fi
    
    check_system
    install_rust
    install_soundness
    
    # 检查是否传入了生成密钥数量参数
    if [ -n "$1" ] && [ "$1" -gt 0 ] 2>/dev/null; then
        generate_multiple_keys "$1"
    else
        generate_key
    fi
    
    echo "${GREEN}安装完成！${NC}"
    echo "请查看项目文档了解后续步骤：https://github.com/SoundnessLabs/soundness-layer"
}

# 获取命令行参数
if [ $# -eq 0 ]; then
    main
elif [ "$1" = "query" ]; then
    main "query"
else
    main "$1"
fi 
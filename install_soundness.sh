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

# 生成单个密钥并保存
generate_key() {
    local key_name=$1
    local log_file=$2
    local is_batch=$3
    local password=$4  # 新增密码参数
    
    echo "${GREEN}正在生成密钥 ${key_name}...${NC}"
    
    # 创建日志目录（如果是单个生成）
    if [ -z "$is_batch" ]; then
        mkdir -p ./soundness_keys
        local timestamp=$(date +%Y%m%d_%H%M%S)
        log_file="./soundness_keys/keys_${timestamp}.txt"
        echo "=== Soundness Keys Generated at $(date) ===" > "$log_file"
        echo "----------------------------------------" >> "$log_file"
    fi
    
    # 记录密钥信息到日志
    echo "=== Key: $key_name ===" >> "$log_file"
    echo "----------------------------------------" >> "$log_file"
    
    # 执行生成命令并捕获输出
    local output
    if [ -n "$password" ]; then
        # 使用expect自动处理密码输入
        output=$(expect -c "
            set timeout 10
            spawn soundness-cli generate-key --name \"$key_name\"
            expect \"Enter password for secret key:\"
            send \"$password\r\"
            expect \"Confirm password:\"
            send \"$password\r\"
            expect eof
            catch wait result
            exit [lindex \$result 3]
        " 2>&1)
    else
        # 正常生成（单个模式或批量模式的第一个密钥）
        output=$(soundness-cli generate-key --name "$key_name" 2>&1)
    fi
    local status=$?
    
    # 保存输出到日志
    echo "$output" >> "$log_file"
    echo "----------------------------------------" >> "$log_file"
    echo "" >> "$log_file"
    
    # 显示结果
    if [ $status -eq 0 ]; then
        echo "${GREEN}✓ 密钥 $key_name 生成成功${NC}"
        if [ -z "$password" ]; then
            echo "$output"  # 只在没有提供密码时显示输出
        fi
    else
        echo "${RED}✗ 密钥 $key_name 生成失败${NC}"
        echo "Error: $output"
    fi
    
    # 如果是单个生成，显示保存位置
    if [ -z "$is_batch" ]; then
        echo "${GREEN}密钥信息已保存至: $log_file${NC}"
        echo "${RED}请立即备份该文件！${NC}"
    fi
    
    return $status
}

# 检查并安装expect
install_expect() {
    if ! command -v expect &> /dev/null; then
        echo "正在安装 expect..."
        sudo apt-get update
        sudo apt-get install -y expect
    fi
}

# 批量生成密钥
generate_multiple_keys() {
    local count=$1
    echo "正在批量生成 ${count} 个密钥..."
    echo "${RED}注意：请务必保存第一个密钥的助记词和密码！${NC}"
    
    # 创建日志目录和文件
    mkdir -p ./soundness_keys
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="./soundness_keys/keys_${timestamp}.txt"
    
    echo "=== Soundness Keys Generated at $(date) ===" > "$log_file"
    echo "Total keys to generate: $count" >> "$log_file"
    echo "----------------------------------------" >> "$log_file"
    echo "" >> "$log_file"
    
    local success_count=0
    local first_key_name=$(generate_random_name)
    local password=""
    
    # 生成第一个密钥并获取密码
    echo "${GREEN}生成第一个密钥，请输入密码...${NC}"
    generate_key "$first_key_name" "$log_file" "batch"
    if [ $? -eq 0 ]; then
        ((success_count++))
        # 提取第一个密钥的密码
        read -s -p "请再次输入刚才设置的密码（用于后续密钥生成）: " password
        echo
    else
        echo "${RED}第一个密钥生成失败，终止批量生成${NC}"
        return 1
    fi
    
    # 生成剩余的密钥
    for i in $(seq 2 $count); do
        local key_name=$(generate_random_name)
        generate_key "$key_name" "$log_file" "batch" "$password"
        
        if [ $? -eq 0 ]; then
            ((success_count++))
        fi
        
        # 随机延迟2-5秒
        sleep $((RANDOM % 4 + 2))
    done
    
    # 添加统计信息
    echo "" >> "$log_file"
    echo "=== Generation Summary ===" >> "$log_file"
    echo "Total attempted: $count" >> "$log_file"
    echo "Successfully generated: $success_count" >> "$log_file"
    echo "Failed: $((count - success_count))" >> "$log_file"
    echo "----------------------------------------" >> "$log_file"
    
    echo "${GREEN}批量生成完成！${NC}"
    echo "成功生成: $success_count 个密钥"
    echo "失败: $((count - success_count)) 个密钥"
    echo "密钥信息已保存至: $log_file"
    echo "${RED}请立即备份该文件！${NC}"
}

# 查询密钥信息
query_keys() {
    local keys_dir="./soundness_keys"
    
    if [ ! -d "$keys_dir" ]; then
        echo "${RED}未找到密钥目录！${NC}"
        return 1
    fi
    
    echo "${GREEN}=== 密钥文件列表 ===${NC}"
    local files=($(ls -t $keys_dir))
    
    if [ ${#files[@]} -eq 0 ]; then
        echo "${RED}未找到任何密钥文件${NC}"
        return 1
    fi
    
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

# 检查 Soundness CLI 是否已安装
check_soundness_installed() {
    if command -v soundness-cli &> /dev/null && command -v soundnessup &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 主流程
main() {
    if [ "$1" = "query" ]; then
        query_keys
        return
    fi
    
    # 只在首次安装时执行安装步骤
    if ! check_soundness_installed; then
        echo "${GREEN}首次运行，开始安装必要组件...${NC}"
        check_system
        install_rust
        install_soundness
    else
        echo "${GREEN}Soundness CLI 已安装，跳过安装步骤...${NC}"
    fi
    
    # 确保expect已安装
    install_expect
    
    # 检查是否传入了生成密钥数量参数
    if [ -n "$1" ] && [ "$1" -gt 0 ] 2>/dev/null; then
        generate_multiple_keys "$1"
    else
        generate_key "$(generate_random_name)" "" ""
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

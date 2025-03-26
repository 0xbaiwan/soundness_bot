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
set -o monitor  # 确保子进程也被终止
umask 077  # 设置文件权限

# 确保 HOME 变量存在
if [ -z "${HOME:-}" ]; then
    export HOME=$(eval echo ~$USER)
fi

# 存储密钥信息的文件
KEYS_FILE="$HOME/.soundness_keys.txt"

# 添加日志记录
LOG_FILE="$HOME/.soundness/soundness.log"

# 添加配置文件支持
CONFIG_FILE="$HOME/.soundness/config"

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 安全的文件写入函数
safe_write() {
    local file=$1
    local temp_file="${file}.tmp"
    cat > "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$file"
}

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
    # 确保基础目录存在
    mkdir -p "$HOME/.soundness/bin" "$HOME/.cargo/bin"
    
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
    log_message "INFO" "开始安装依赖"
    # 确保有 sudo 权限
    if ! sudo -v; then
        echo -e "${RED}需要 sudo 权限来安装依赖${NC}"
        return 1
    fi
    
    # 确保网络连接（使用多个目标）
    local connected=false
    for host in google.com baidu.com github.com; do
        if ping -c 1 "$host" &> /dev/null; then
            connected=true
            break
        fi
    done
    
    if ! $connected; then
        echo -e "${RED}网络连接异常，请检查网络${NC}"
        return 1
    fi
    
    echo -e "${BLUE}正在安装必要组件...${NC}"
    
    # 安装 expect
    if ! command -v expect &> /dev/null; then
        echo -e "${GREEN}安装 expect...${NC}"
        sudo apt-get update && sudo apt-get install expect -y || {
            echo -e "${RED}expect 安装失败${NC}"
            return 1
        }
    fi
    
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
    
    # 验证所有组件
    local all_deps=("expect" "cargo" "soundness-cli" "soundnessup")
    for dep in "${all_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}${dep} 安装失败${NC}"
            return 1
        fi
    done

    echo -e "${GREEN}依赖安装完成！${NC}"
    log_message "INFO" "依赖安装完成"
    return 0
}

# 检查必要的命令是否安装
check_requirements() {
    local need_install=false
    
    # 检查所有依赖
    local all_deps=("expect" "cargo" "soundness-cli" "soundnessup")
    for dep in "${all_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            need_install=true
            break
        fi
    done
    
    # 如果需要安装任何组件
    if [ "$need_install" = true ]; then
        echo -e "${BLUE}检测到未安装的必要组件，开始安装...${NC}"
        install_dependencies
        
        # 验证安装结果
        local failed=false
        for dep in "${all_deps[@]}"; do
            if ! command -v "$dep" &> /dev/null; then
                echo -e "${RED}${dep} 安装失败${NC}"
                failed=true
            fi
        done
        
        if [ "$failed" = true ]; then
            echo -e "${RED}部分组件安装失败，请尝试手动安装：${NC}"
            echo "1. sudo apt-get update && sudo apt-get install expect"
            echo "2. curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
            echo "3. source \$HOME/.cargo/env"
            echo "4. curl -sSL https://raw.githubusercontent.com/soundnesslabs/soundness-layer/main/soundnessup/install | bash"
            echo "5. source ~/.bashrc"
            echo "6. soundnessup install"
            echo "7. soundnessup update"
            return 1
        fi
    else
        echo -e "${GREEN}所有依赖已安装${NC}"
    fi
    
    return 0
}

# 添加密码强度检查
check_password_strength() {
    local password=$1
    local min_length=8
    
    if [ ${#password} -lt $min_length ]; then
        echo -e "${RED}密码长度至少需要 $min_length 个字符${NC}"
        return 1
    fi
    
    if ! echo "$password" | grep -q "[A-Z]"; then
        echo -e "${RED}密码需要包含大写字母${NC}"
        return 1
    fi
    
    if ! echo "$password" | grep -q "[a-z]"; then
        echo -e "${RED}密码需要包含小写字母${NC}"
        return 1
    fi
    
    if ! echo "$password" | grep -q "[0-9]"; then
        echo -e "${RED}密码需要包含数字${NC}"
        return 1
    fi
    
    return 0
}

# 添加错误处理函数
handle_error() {
    local error_msg=$1
    local error_code=${2:-1}
    echo -e "${RED}错误: $error_msg${NC}" >&2
    return $error_code
}

# 添加重试机制
retry_command() {
    local cmd=$1
    local max_attempts=${2:-3}
    local delay=${3:-2}
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$cmd"; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo -e "${BLUE}命令失败，正在重试 ($attempt/$max_attempts)...${NC}"
            sleep $delay
        fi
        
        attempt=$((attempt + 1))
    done
    
    handle_error "命令执行失败，已重试 $max_attempts 次"
    return 1
}

# 生成并保存密钥
generate_keys() {
    log_message "INFO" "开始生成密钥，数量: $1"
    local count=$1
    local words=("apple" "banana" "cherry" "dragon" "eagle" "falcon" "grape" "horse" "island" "jaguar" "koala" "lemon" "mango" "ninja" "orange" "panda" "queen" "rabbit" "snake" "tiger" "umbrella" "violet" "whale" "xenon" "yellow" "zebra")
    local password
    
    # 检查磁盘空间
    if [ "$(df -P "$HOME" | awk 'NR==2 {print $4}')" -lt 1048576 ]; then
        echo -e "${RED}磁盘空间不足，请确保有至少 1GB 可用空间${NC}"
        return 1
    fi

    # 获取并验证密码
    while true; do
        echo -n "请输入密码: "
        read -s password
        echo
        
        if [ -z "$password" ]; then
            echo -e "${RED}密码不能为空${NC}"
            continue
        fi
        
        if ! check_password_strength "$password"; then
            continue
        fi
        
        echo -n "请确认密码: "
        read -s password_confirm
        echo
        
        if [ "$password" != "$password_confirm" ]; then
            echo -e "${RED}两次输入的密码不一致${NC}"
            continue
        fi
        
        break
    done
    
    # 创建临时目录（使用更安全的方式）
    local tmp_dir
    tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/soundness.XXXXXXXXXX") || {
        echo -e "${RED}无法创建临时目录${NC}"
        return 1
    }
    
    # 确保退出时清理临时目录
    trap 'rm -rf "$tmp_dir"' EXIT

    # 使用临时目录
    local exp_script="$tmp_dir/gen_key.exp"
    local success=true

    for ((i=1; i<=count; i++)); do
        echo -e "${GREEN}正在生成第 $i 个密钥...${NC}"
        
        # 生成随机密钥名称
        local random_word=${words[$RANDOM % ${#words[@]}]}
        local random_num=$((RANDOM % 10000))
        local key_name="${random_word}_${random_num}"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # 创建 expect 脚本
        cat > "$exp_script" << EOF
#!/usr/bin/expect -f
set timeout -1
log_user 1
spawn soundness-cli generate-key --name "$key_name"
expect {
    "Enter password for secret key: " {
        send "$password\r"
        exp_continue
    }
    "Confirm password: " {
        send "$password\r"
        exp_continue
    }
    timeout {
        puts "Operation timed out"
        exit 1
    }
    eof
}
EOF
        
        chmod 700 "$exp_script"
        output=$("$exp_script")
        status=$?
        
        if [ $status -ne 0 ]; then
            echo -e "${RED}生成密钥失败: $output${NC}"
            success=false
            break
        fi
        
        # 提取公钥和助记词
        public_key=$(echo "$output" | grep "Public key:" | cut -d' ' -f3)
        mnemonic=$(echo "$output" | grep -A 1 "Mnemonic:" | tail -n 1)
        
        # 更严格的输出验证
        if [ -z "$public_key" ] || [ -z "$mnemonic" ]; then
            echo -e "${RED}无法提取密钥信息，请重试${NC}"
            success=false
            break
        fi
        
        # 保存到文件
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
    
    [ "$success" = true ] || return 1
    log_message "INFO" "密钥生成完成"
}

# 添加并行处理支持
generate_keys_parallel() {
    local count=$1
    local batch_size=5
    local current=0
    
    while [ $current -lt $count ]; do
        local batch_count=$((count - current))
        if [ $batch_count -gt $batch_size ]; then
            batch_count=$batch_size
        fi
        
        for ((i=1; i<=batch_count; i++)); do
            generate_single_key "$((current + i))" "$password" &
        done
        
        wait
        current=$((current + batch_count))
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

# 备份密钥文件
backup_keys() {
    if [ -f "$KEYS_FILE" ]; then
        local backup_dir="$HOME/.soundness_backups"
        mkdir -p "$backup_dir" || {
            echo -e "${RED}无法创建备份目录${NC}"
            return 1
        }
        chmod 700 "$backup_dir"
        
        local backup_file="$backup_dir/keys_$(date +%Y%m%d_%H%M%S).bak"
        if cp "$KEYS_FILE" "$backup_file"; then
            chmod 600 "$backup_file"
            echo -e "${GREEN}已创建备份: $backup_file${NC}"
            
            # 使用更安全的方式清理旧备份
            find "$backup_dir" -name "*.bak" -type f -printf '%T@ %p\n' | \
                sort -n | head -n -10 | cut -d' ' -f2- | \
                xargs -r rm
        else
            echo -e "${RED}备份创建失败${NC}"
            return 1
        fi
    else
        echo -e "${RED}未找到密钥文件${NC}"
        return 1
    fi
}

# 主菜单
show_menu() {
    while true; do
        echo -e "\n${BLUE}=== Soundness Labs 测试网白名单管理 ===${NC}"
        echo "1. 安装依赖"
        echo "2. 注册白名单"
        echo "3. 查看密钥信息"
        echo "4. 备份密钥文件"
        echo "5. 退出"
        echo -n "请选择操作 (1-5): "
        
        read choice
        case $choice in
            1)
                if check_requirements; then
                    echo -e "${GREEN}依赖安装完成！${NC}"
                else
                    echo -e "${RED}依赖安装失败，请查看上述错误信息${NC}"
                fi
                ;;
            2)
                if ! command -v soundness-cli &> /dev/null; then
                    echo -e "${RED}请先安装依赖（选项1）${NC}"
                    continue
                fi
                echo -n "请输入要注册的账号数量: "
                read count
                if [[ "$count" =~ ^[0-9]+$ ]]; then
                    generate_keys "$count"
                else
                    echo -e "${RED}请输入有效的数字${NC}"
                fi
                ;;
            3)
                show_keys
                ;;
            4)
                backup_keys
                ;;
            5)
                echo -e "${GREEN}感谢使用，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择，请重试${NC}"
                ;;
        esac
    done
}

# 清理函数
cleanup() {
    # 清理所有相关临时文件和目录
    rm -rf /tmp/soundness_*.tmp /tmp/gen_key.exp 2>/dev/null || true
    
    # 重置终端状态
    stty echo
    echo -e "${NC}"
}

# 添加信号处理
trap cleanup EXIT
trap 'echo -e "${RED}脚本被中断${NC}"; cleanup; exit 1' INT TERM HUP

# 主程序入口
main() {
    # 检查系统兼容性
    if [ "$(uname)" != "Linux" ]; then
        echo -e "${RED}此脚本仅支持 Linux 系统${NC}"
        exit 1
    fi
    
    # 检查必要命令
    for cmd in curl grep awk chmod mkdir rm ping; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}缺少必要命令: $cmd${NC}"
            exit 1
        fi
    done
    
    # 初始化
    check_file_permissions
    touch "$KEYS_FILE" || {
        echo -e "${RED}无法创建密钥文件${NC}"
        exit 1
    }
    
    # 加载环境变量
    load_env
    
    # 加载配置
    load_config
    
    # 运行菜单
    show_menu
}

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    else
        # 默认配置
        BACKUP_COUNT=10
        RETRY_ATTEMPTS=3
        RETRY_DELAY=2
        MIN_PASSWORD_LENGTH=8
        
        # 保存默认配置
        cat > "$CONFIG_FILE" << EOF
BACKUP_COUNT=$BACKUP_COUNT
RETRY_ATTEMPTS=$RETRY_ATTEMPTS
RETRY_DELAY=$RETRY_DELAY
MIN_PASSWORD_LENGTH=$MIN_PASSWORD_LENGTH
EOF
        chmod 600 "$CONFIG_FILE"
    fi
}

# 运行主程序
main 

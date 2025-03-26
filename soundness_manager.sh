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

# 在脚本开始处添加 tmp_dir 的定义
tmp_dir=$(mktemp -d /tmp/soundness.XXXXXXXXXX)
trap 'rm -rf "$tmp_dir"' EXIT

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
    
    # 安装 expect
    if ! command -v expect &> /dev/null; then
        echo -e "${BLUE}正在安装 expect...${NC}"
        sudo apt-get update && sudo apt-get install -y expect || {
            echo -e "${RED}expect 安装失败${NC}"
            return 1
        }
    fi
    
    # 安装 soundness-labs
    echo -e "${BLUE}正在安装 soundness-labs...${NC}"
    
    # 创建必要的目录
    mkdir -p "$HOME/.soundness/bin"
    
    # 清理可能存在的旧安装
    rm -f "$HOME/.soundness/bin/soundness-labs"
    
    # 安装 Rust（如果需要）
    if ! command -v cargo &> /dev/null; then
        echo -e "${BLUE}安装 Rust...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    
    # 强制重新安装 soundness-cli
    echo -e "${BLUE}安装 soundness-cli...${NC}"
    cargo install --force --git https://github.com/soundnesslabs/soundness-layer.git soundness-cli
    
    # 复制二进制文件
    if [ -f "$HOME/.cargo/bin/soundness-cli" ]; then
        cp "$HOME/.cargo/bin/soundness-cli" "$HOME/.soundness/bin/soundness-labs"
        chmod +x "$HOME/.soundness/bin/soundness-labs"
    else
        echo -e "${RED}soundness-cli 安装失败${NC}"
        return 1
    fi
    
    # 验证安装
    if ! "$HOME/.soundness/bin/soundness-labs" --help &> /dev/null; then
        echo -e "${RED}soundness-labs 无法执行${NC}"
        return 1
    fi
    
    # 显示版本信息
    "$HOME/.soundness/bin/soundness-labs" --version
    
    echo -e "${GREEN}soundness-labs 安装成功${NC}"
    return 0
}

# 检查必要的命令是否安装
check_requirements() {
    echo -e "${BLUE}检查依赖项...${NC}"
    local need_install=false
    
    # 检查 expect
    if ! command -v expect &> /dev/null; then
        echo -e "${BLUE}需要安装 expect${NC}"
        need_install=true
    fi
    
    # 检查 soundness-labs
    if [ ! -x "$HOME/.soundness/bin/soundness-labs" ]; then
        echo -e "${BLUE}需要安装 soundness-labs${NC}"
        need_install=true
    else
        # 验证 soundness-labs 是否可正常执行
        if ! "$HOME/.soundness/bin/soundness-labs" --help &> /dev/null; then
            echo -e "${BLUE}soundness-labs 需要重新安装${NC}"
            need_install=true
        fi
    fi
    
    # 如果需要安装
    if [ "$need_install" = true ]; then
        echo -e "${BLUE}开始安装依赖...${NC}"
        if ! install_dependencies; then
            echo -e "${RED}依赖安装失败${NC}"
            return 1
        fi
    fi
    
    # 最终验证
    if ! command -v expect &> /dev/null || \
       [ ! -x "$HOME/.soundness/bin/soundness-labs" ] || \
       ! "$HOME/.soundness/bin/soundness-labs" --help &> /dev/null; then
        echo -e "${RED}依赖安装验证失败${NC}"
        return 1
    fi
    
    echo -e "${GREEN}所有依赖已正确安装${NC}"
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

# 修改 generate_keys 函数
generate_keys() {
    local password=$1
    local count=$2
    
    # 验证 soundness-labs 是否正确安装
    local soundness_labs_path="$HOME/.soundness/bin/soundness-labs"
    if [ ! -x "$soundness_labs_path" ]; then
        echo -e "${RED}错误：soundness-labs 未正确安装${NC}"
        return 1
    fi
    
    # 创建 expect 脚本
    cat > "$tmp_dir/gen_key.exp" << EOF
#!/usr/bin/expect -f
set password [lindex \$argv 0]
set key_name [lindex \$argv 1]
set timeout 30

# 生成密钥
spawn $soundness_labs_path generate-key --name \$key_name
expect {
    "Enter a password:" {
        send "\$password\r"
        exp_continue
    }
    "Confirm password:" {
        send "\$password\r"
        exp_continue
    }
    "Enter mnemonic passphrase:" {
        send "\$password\r"
        exp_continue
    }
    "Re-enter mnemonic passphrase:" {
        send "\$password\r"
        exp_continue
    }
    "Key pair generated successfully" {
        # 成功生成
        exit 0
    }
    timeout {
        puts "错误：操作超时"
        exit 1
    }
    eof {
        # 检查是否有错误输出
        if {[string match "*error*" \$expect_out(buffer)]} {
            puts "错误：命令执行失败"
            exit 1
        }
    }
}
EOF
    
    chmod +x "$tmp_dir/gen_key.exp"
    
    # 生成密钥
    for ((i=1; i<=$count; i++)); do
        local key_name="key$i"
        echo -e "${BLUE}正在生成第 $i 个密钥 ($key_name)...${NC}"
        
        if ! /usr/bin/expect "$tmp_dir/gen_key.exp" "$password" "$key_name"; then
            echo -e "${RED}生成第 $i 个密钥时出错${NC}"
            return 1
        fi
        
        # 验证密钥是否生成成功
        if "$soundness_labs_path" list-keys | grep -q "$key_name"; then
            echo -e "${GREEN}第 $i 个密钥 ($key_name) 生成成功${NC}"
            
            # 保存密钥信息
            {
                echo "=== 密钥 #$i ($key_name) 生成时间: $(date '+%Y-%m-%d %H:%M:%S') ==="
                "$soundness_labs_path" list-keys | grep -A 2 "$key_name"
                echo "================================================="
            } >> "$KEYS_FILE"
        else
            echo -e "${RED}无法验证第 $i 个密钥是否生成成功${NC}"
            return 1
        fi
        
        # 短暂暂停，避免过快生成
        sleep 1
    done
    
    return 0
}

# 修改 show_keys 函数
show_keys() {
    local soundness_labs_path="$HOME/.soundness/bin/soundness-labs"
    
    if [ -x "$soundness_labs_path" ]; then
        echo -e "${BLUE}当前密钥列表：${NC}"
        if ! "$soundness_labs_path" list-keys; then
            echo -e "${RED}无法获取密钥列表${NC}"
            return 1
        fi
        
        if [ -f "$KEYS_FILE" ]; then
            echo -e "\n${BLUE}历史密钥信息：${NC}"
            cat "$KEYS_FILE"
        fi
    else
        echo -e "${RED}未找到 soundness-labs 命令${NC}"
        return 1
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

# 添加初始化函数
initialize_environment() {
    echo -e "${BLUE}正在初始化环境...${NC}"
    local need_init=false
    
    # 检查必要目录
    if [ ! -d "$HOME/.soundness/bin" ] || [ ! -d "$HOME/.soundness/logs" ]; then
        need_init=true
        echo -e "${BLUE}创建必要目录...${NC}"
        mkdir -p "$HOME/.soundness/bin" "$HOME/.soundness/logs"
    fi
    
    # 检查基本工具
    if ! command -v curl &> /dev/null; then
        need_init=true
        echo -e "${BLUE}安装 curl...${NC}"
        if ! sudo apt-get update && sudo apt-get install -y curl; then
            echo -e "${RED}curl 安装失败${NC}"
            return 1
        fi
    fi
    
    # 检查 expect
    if ! command -v expect &> /dev/null; then
        need_init=true
        echo -e "${BLUE}安装 expect...${NC}"
        if ! sudo apt-get install -y expect; then
            echo -e "${RED}expect 安装失败${NC}"
            return 1
        fi
    fi
    
    # 检查目录权限
    local perms
    perms=$(stat -c "%a" "$HOME/.soundness" 2>/dev/null || echo "000")
    if [ "$perms" != "700" ]; then
        need_init=true
        echo -e "${BLUE}设置目录权限...${NC}"
        chmod 700 "$HOME/.soundness"
        chmod 700 "$HOME/.soundness/bin"
    fi
    
    # 检查 PATH 设置
    if [[ ":$PATH:" != *":$HOME/.soundness/bin:"* ]]; then
        need_init=true
        echo -e "${BLUE}更新 PATH 环境变量...${NC}"
        echo "export PATH=\"\$HOME/.soundness/bin:\$PATH\"" >> "$HOME/.bashrc"
        export PATH="$HOME/.soundness/bin:$PATH"
    fi
    
    if [ "$need_init" = true ]; then
        echo -e "${GREEN}环境初始化完成${NC}"
    else
        echo -e "${GREEN}环境已经初始化${NC}"
    fi
    
    # 最终验证
    if [ ! -d "$HOME/.soundness/bin" ] || [ ! -d "$HOME/.soundness/logs" ] || \
       ! command -v curl &> /dev/null || ! command -v expect &> /dev/null || \
       [ "$(stat -c "%a" "$HOME/.soundness")" != "700" ]; then
        echo -e "${RED}环境初始化验证失败${NC}"
        return 1
    fi
    
    return 0
}

# 修改主菜单
show_menu() {
    while true; do
        echo -e "\n${BLUE}=== Soundness Labs 测试网白名单管理 ===${NC}"
        echo "1. 初始化环境"
        echo "2. 安装依赖"
        echo "3. 注册白名单"
        echo "4. 查看密钥信息"
        echo "5. 备份密钥文件"
        echo "6. 退出"
        echo -n "请选择操作 (1-6): "
        
        read choice
        case $choice in
            1)
                if initialize_environment; then
                    echo -e "${GREEN}环境初始化完成！${NC}"
                else
                    echo -e "${RED}环境初始化失败${NC}"
                fi
                ;;
            2)
                if check_requirements; then
                    echo -e "${GREEN}依赖安装完成！${NC}"
                else
                    echo -e "${RED}依赖安装失败，请查看上述错误信息${NC}"
                fi
                ;;
            3)
                if ! command -v soundness-labs &> /dev/null; then
                    echo -e "${RED}请先初始化环境并安装依赖（选项1和2）${NC}"
                    continue
                fi
                echo "请输入要注册的账号数量: "
                read count
                
                if ! [[ "$count" =~ ^[0-9]+$ ]]; then
                    echo "错误：请输入有效的数字"
                    continue
                fi
                
                echo "请输入密码: "
                read -s password
                echo
                echo "请确认密码: "
                read -s password2
                echo
                
                if [ "$password" != "$password2" ]; then
                    echo "错误：两次输入的密码不匹配"
                    continue
                fi
                
                generate_keys "$password" "$count"
                if [ $? -ne 0 ]; then
                    echo "生成密钥失败"
                    continue
                fi
                
                echo "密钥生成完成"
                ;;
            4)
                show_keys
                ;;
            5)
                backup_keys
                ;;
            6)
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

# 修改一键运行命令
main() {
    # 检查系统兼容性
    if [ "$(uname)" != "Linux" ]; then
        echo -e "${RED}此脚本仅支持 Linux 系统${NC}"
        exit 1
    fi
    
    # 自动初始化环境
    if ! initialize_environment; then
        echo -e "${RED}环境初始化失败，请手动执行初始化（选项1）${NC}"
    fi
    
    # 检查文件权限
    check_file_permissions
    
    # 创建必要的文件
    touch "$KEYS_FILE" || {
        echo -e "${RED}无法创建密钥文件${NC}"
        exit 1
    }
    
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
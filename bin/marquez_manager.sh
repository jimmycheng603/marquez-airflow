#!/bin/bash
set -euo pipefail
# Marquez 进程管理脚本
# 用于启动、停止、查看状态和管理 Marquez 服务

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
# 获取脚本所在目录的父目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARQUEZ_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MARQUEZ_JAR="${MARQUEZ_DIR}/api/build/libs/marquez-api-0.50.0.jar"
MARQUEZ_CONFIG="${MARQUEZ_DIR}/marquez.dev.yml"
MARQUEZ_API_PORT=3000
MARQUEZ_ADMIN_PORT=3001
MARQUEZ_WEB_PORT=8080
MARQUEZ_WEB_DIR="${MARQUEZ_DIR}/web"
PID_DIR="${MARQUEZ_DIR}/pids"
LOG_DIR="${MARQUEZ_DIR}/logs"
MARQUEZ_LOG_DIR="${LOG_DIR}/marquez"

# 创建目录
mkdir -p "${PID_DIR}" "${LOG_DIR}" "${MARQUEZ_LOG_DIR}"

# 检查 JDK 17
check_java() {
    if ! command -v /usr/libexec/java_home &> /dev/null; then
        echo -e "${RED}错误: 无法检测 Java 版本${NC}"
        return 1
    fi
    
    local java_17_home=$(/usr/libexec/java_home -v17 2>/dev/null || echo "")
    if [ -z "$java_17_home" ]; then
        echo -e "${RED}错误: 未找到 JDK 17${NC}"
        echo -e "${YELLOW}请安装 JDK 17: brew install --cask temurin17${NC}"
        return 1
    fi
    
    export JAVA_HOME="$java_17_home"
    export PATH="$JAVA_HOME/bin:$PATH"
    return 0
}

# 检查 JAR 文件是否存在
check_jar() {
    if [ ! -f "${MARQUEZ_JAR}" ]; then
        echo -e "${RED}错误: 找不到 Marquez JAR 文件: ${MARQUEZ_JAR}${NC}"
        echo -e "${YELLOW}请先编译 Marquez: cd ${MARQUEZ_DIR} && ./gradlew shadowJar${NC}"
        return 1
    fi
    return 0
}

# 检查配置文件是否存在
check_config() {
    if [ ! -f "${MARQUEZ_CONFIG}" ]; then
        echo -e "${RED}错误: 找不到配置文件: ${MARQUEZ_CONFIG}${NC}"
        return 1
    fi
    return 0
}

# 检查 Node.js 和 npm
check_node() {
    if ! command -v node &> /dev/null; then
        echo -e "${RED}错误: 未找到 Node.js${NC}"
        echo -e "${YELLOW}请安装 Node.js: brew install node${NC}"
        return 1
    fi
    
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}错误: 未找到 npm${NC}"
        return 1
    fi
    
    local node_version=$(node -v)
    echo -e "${BLUE}Node.js 版本: ${node_version}${NC}"
    return 0
}

# 检查 Web UI 目录和依赖
check_web() {
    if [ ! -d "${MARQUEZ_WEB_DIR}" ]; then
        echo -e "${RED}错误: 找不到 Web UI 目录: ${MARQUEZ_WEB_DIR}${NC}"
        return 1
    fi
    
    if [ ! -f "${MARQUEZ_WEB_DIR}/package.json" ]; then
        echo -e "${RED}错误: 找不到 package.json: ${MARQUEZ_WEB_DIR}/package.json${NC}"
        return 1
    fi
    
    # 检查 node_modules 是否存在，如果不存在则提示安装
    if [ ! -d "${MARQUEZ_WEB_DIR}/node_modules" ]; then
        echo -e "${YELLOW}警告: node_modules 不存在，需要先安装依赖${NC}"
        echo -e "${BLUE}正在安装依赖...${NC}"
        cd "${MARQUEZ_WEB_DIR}"
        npm install || {
            echo -e "${RED}依赖安装失败${NC}"
            return 1
        }
    fi
    
    return 0
}

# 检查进程是否运行
is_process_running() {
    local pid_file="$1"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file" 2>/dev/null)
        if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$pid_file"
            return 1
        fi
    fi
    return 1
}

# 获取进程 PID
get_process_pid() {
    local process_name="$1"
    pgrep -f "$process_name" | head -n 1
}

# 优雅地结束进程
kill_pid_gracefully() {
    local pid="$1"
    if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
        kill "$pid" 2>/dev/null || true
        sleep 2
        if ps -p "$pid" > /dev/null 2>&1; then
            kill -9 "$pid" 2>/dev/null || true
            sleep 1
        fi
    fi
}

# 通过端口杀进程
kill_by_port() {
    local port="$1"
    local port_pids=""
    if port_pids=$(lsof -ti :"${port}" 2>/dev/null); then
        port_pids=$(echo "$port_pids" | tr '\n' ' ')
    else
        port_pids=""
    fi
    if [ -n "${port_pids// /}" ]; then
        echo -e "${BLUE}通过端口 ${port} 清理进程: ${port_pids}${NC}"
        for pid in $port_pids; do
            kill_pid_gracefully "$pid"
        done
    fi
}

# 启动 Marquez API
start_marquez() {
    echo -e "${BLUE}启动 Marquez API...${NC}"
    
    if is_process_running "${PID_DIR}/marquez.pid"; then
        echo -e "${YELLOW}Marquez 已经在运行中 (PID: $(cat ${PID_DIR}/marquez.pid))${NC}"
        return 0
    fi
    
    # 检查前置条件
    if ! check_java; then
        return 1
    fi
    
    if ! check_jar; then
        return 1
    fi
    
    if ! check_config; then
        return 1
    fi
    
    # 检查端口是否被占用
    local api_port_pid=$(lsof -ti :${MARQUEZ_API_PORT} 2>/dev/null | head -1)
    if [ -n "$api_port_pid" ]; then
        echo -e "${YELLOW}警告: 端口 ${MARQUEZ_API_PORT} 已被占用 (PID: $api_port_pid)${NC}"
        if ps -p "$api_port_pid" > /dev/null 2>&1 && pgrep -f "marquez" | grep -q "$api_port_pid"; then
            echo -e "${BLUE}检测到旧的 Marquez 进程，正在停止...${NC}"
            kill_pid_gracefully "$api_port_pid"
            sleep 2
        else
            echo -e "${RED}错误: 端口 ${MARQUEZ_API_PORT} 被其他进程占用${NC}"
            return 1
        fi
    fi
    
    # 启动 Marquez
    cd "${MARQUEZ_DIR}"
    nohup java -jar "${MARQUEZ_JAR}" server "${MARQUEZ_CONFIG}" \
        > "${MARQUEZ_LOG_DIR}/marquez.log" 2>&1 &
    
    local pid=$!
    echo $pid > "${PID_DIR}/marquez.pid"
    
    sleep 3
    if is_process_running "${PID_DIR}/marquez.pid"; then
        echo -e "${GREEN}Marquez API 启动成功 (PID: $pid)${NC}"
        echo -e "${GREEN}API 地址: http://localhost:${MARQUEZ_API_PORT}${NC}"
        echo -e "${GREEN}Admin 地址: http://localhost:${MARQUEZ_ADMIN_PORT}${NC}"
        echo -e "${GREEN}健康检查: http://localhost:${MARQUEZ_API_PORT}/api/v1/health${NC}"
        return 0
    else
        echo -e "${RED}Marquez API 启动失败，请查看日志: ${MARQUEZ_LOG_DIR}/marquez.log${NC}"
        rm -f "${PID_DIR}/marquez.pid"
        return 1
    fi
}

# 停止 Marquez
stop_marquez() {
    echo -e "${BLUE}停止 Marquez API...${NC}"
    
    local pid_file="${PID_DIR}/marquez.pid"
    local stopped=false
    
    if is_process_running "$pid_file"; then
        local pid=$(cat "$pid_file")
        kill_pid_gracefully "$pid"
        rm -f "$pid_file"
        stopped=true
        echo -e "${GREEN}Marquez 已停止 (PID: $pid)${NC}"
    else
        # 尝试通过进程名查找
        local pids=""
        if pids=$(pgrep -f "marquez.*jar" 2>/dev/null); then
            pids=$(echo "$pids" | tr '\n' ' ')
        else
            pids=""
        fi
        if [ -n "${pids// /}" ]; then
            echo -e "${BLUE}通过进程名清理 Marquez: ${pids}${NC}"
            for pid in $pids; do
                kill_pid_gracefully "$pid"
            done
            stopped=true
            echo -e "${GREEN}Marquez 已停止（进程名匹配）${NC}"
        fi
    fi
    
    # 通过端口清理
    kill_by_port "${MARQUEZ_API_PORT}"
    kill_by_port "${MARQUEZ_ADMIN_PORT}"
    
    if [ "$stopped" = false ]; then
        if lsof -ti :"${MARQUEZ_API_PORT}" > /dev/null 2>&1 || lsof -ti :"${MARQUEZ_ADMIN_PORT}" > /dev/null 2>&1; then
            echo -e "${YELLOW}已尝试清理，但端口仍被占用，请手动检查${NC}"
        else
            echo -e "${YELLOW}Marquez 未运行${NC}"
        fi
    fi
}

# 启动 Marquez Web UI
start_web() {
    echo -e "${BLUE}启动 Marquez Web UI...${NC}"
    
    if is_process_running "${PID_DIR}/marquez-web.pid"; then
        echo -e "${YELLOW}Marquez Web UI 已经在运行中 (PID: $(cat ${PID_DIR}/marquez-web.pid))${NC}"
        return 0
    fi
    
    # 检查前置条件
    if ! check_node; then
        return 1
    fi
    
    if ! check_web; then
        return 1
    fi
    
    # 检查端口是否被占用
    local web_port_pid=$(lsof -ti :${MARQUEZ_WEB_PORT} 2>/dev/null | head -1)
    if [ -n "$web_port_pid" ]; then
        echo -e "${YELLOW}警告: 端口 ${MARQUEZ_WEB_PORT} 已被占用 (PID: $web_port_pid)${NC}"
        if ps -p "$web_port_pid" > /dev/null 2>&1 && pgrep -f "webpack-dev-server\|npm.*dev" | grep -q "$web_port_pid"; then
            echo -e "${BLUE}检测到旧的 Web UI 进程，正在停止...${NC}"
            kill_pid_gracefully "$web_port_pid"
            sleep 2
        else
            echo -e "${RED}错误: 端口 ${MARQUEZ_WEB_PORT} 被其他进程占用${NC}"
            return 1
        fi
    fi
    
    # 检查是否已构建 Web UI
    if [ ! -d "${MARQUEZ_WEB_DIR}/dist" ]; then
        echo -e "${YELLOW}警告: Web UI 未构建，正在构建...${NC}"
        cd "${MARQUEZ_WEB_DIR}"
        npm run build || {
            echo -e "${RED}Web UI 构建失败${NC}"
            return 1
        }
    fi
    
    # 启动 Web UI（使用生产模式）
    cd "${MARQUEZ_WEB_DIR}"
    export MARQUEZ_HOST=localhost
    export MARQUEZ_PORT=${MARQUEZ_API_PORT}
    export WEB_PORT=${MARQUEZ_WEB_PORT}
    nohup node setupProxy.js \
        > "${MARQUEZ_LOG_DIR}/web.log" 2>&1 &
    
    local pid=$!
    echo $pid > "${PID_DIR}/marquez-web.pid"
    
    sleep 3
    if is_process_running "${PID_DIR}/marquez-web.pid"; then
        echo -e "${GREEN}Marquez Web UI 启动成功 (PID: $pid)${NC}"
        echo -e "${GREEN}Web UI 地址: http://localhost:${MARQUEZ_WEB_PORT}${NC}"
        echo -e "${GREEN}注意: Web UI 需要 Marquez API 在 ${MARQUEZ_API_PORT} 端口运行${NC}"
        return 0
    else
        echo -e "${RED}Marquez Web UI 启动失败，请查看日志: ${MARQUEZ_LOG_DIR}/web.log${NC}"
        rm -f "${PID_DIR}/marquez-web.pid"
        return 1
    fi
}

# 停止 Marquez Web UI
stop_web() {
    echo -e "${BLUE}停止 Marquez Web UI...${NC}"
    
    local pid_file="${PID_DIR}/marquez-web.pid"
    local stopped=false
    
    if is_process_running "$pid_file"; then
        local pid=$(cat "$pid_file")
        kill_pid_gracefully "$pid"
        rm -f "$pid_file"
        stopped=true
        echo -e "${GREEN}Marquez Web UI 已停止 (PID: $pid)${NC}"
    else
        # 尝试通过进程名查找
        local pids=""
        if pids=$(pgrep -f "setupProxy.js\|webpack-dev-server.*marquez\|npm.*dev.*marquez" 2>/dev/null); then
            pids=$(echo "$pids" | tr '\n' ' ')
        else
            pids=""
        fi
        if [ -n "${pids// /}" ]; then
            echo -e "${BLUE}通过进程名清理 Web UI: ${pids}${NC}"
            for pid in $pids; do
                kill_pid_gracefully "$pid"
            done
            stopped=true
            echo -e "${GREEN}Marquez Web UI 已停止（进程名匹配）${NC}"
        fi
    fi
    
    # 通过端口清理
    kill_by_port "${MARQUEZ_WEB_PORT}"
    
    if [ "$stopped" = false ]; then
        if lsof -ti :"${MARQUEZ_WEB_PORT}" > /dev/null 2>&1; then
            echo -e "${YELLOW}已尝试清理，但端口仍被占用，请手动检查${NC}"
        else
            echo -e "${YELLOW}Marquez Web UI 未运行${NC}"
        fi
    fi
}

# 查看状态
show_status() {
    echo -e "${BLUE}=== Marquez 服务状态 ===${NC}"
    echo ""
    
    if is_process_running "${PID_DIR}/marquez.pid"; then
        local pid=$(cat "${PID_DIR}/marquez.pid")
        local api_port=$(lsof -Pan -p $pid -iTCP -sTCP:LISTEN 2>/dev/null | grep ":${MARQUEZ_API_PORT}" | sed -n 's/.*:\([0-9]*\).*/\1/p' | head -1)
        local admin_port=$(lsof -Pan -p $pid -iTCP -sTCP:LISTEN 2>/dev/null | grep ":${MARQUEZ_ADMIN_PORT}" | sed -n 's/.*:\([0-9]*\).*/\1/p' | head -1)
        
        echo -e "${GREEN}✓ Marquez API${NC}  : 运行中 (PID: $pid)"
        echo -e "  API 端口: ${api_port:-${MARQUEZ_API_PORT}}"
        echo -e "  Admin 端口: ${admin_port:-${MARQUEZ_ADMIN_PORT}}"
        
        # 检查健康状态
        if command -v curl &> /dev/null; then
            local health=$(curl -s "http://localhost:${MARQUEZ_API_PORT}/api/v1/health" 2>/dev/null || echo "")
            if [ -n "$health" ]; then
                echo -e "  健康状态: ${GREEN}正常${NC}"
            else
                echo -e "  健康状态: ${YELLOW}无法连接${NC}"
            fi
        fi
    else
        echo -e "${RED}✗ Marquez API${NC}  : 未运行"
    fi
    
    echo ""
    if is_process_running "${PID_DIR}/marquez-web.pid"; then
        local web_pid=$(cat "${PID_DIR}/marquez-web.pid")
        local web_port=$(lsof -Pan -p $web_pid -iTCP -sTCP:LISTEN 2>/dev/null | grep ":${MARQUEZ_WEB_PORT}" | sed -n 's/.*:\([0-9]*\).*/\1/p' | head -1)
        echo -e "${GREEN}✓ Marquez Web UI${NC}: 运行中 (PID: $web_pid)"
        echo -e "  Web 端口: ${web_port:-${MARQUEZ_WEB_PORT}}"
        echo -e "  访问地址: http://localhost:${MARQUEZ_WEB_PORT}"
    else
        echo -e "${RED}✗ Marquez Web UI${NC}: 未运行"
    fi
    
    echo ""
    echo -e "${BLUE}=== 进程详细信息 ===${NC}"
    ps aux | grep -E "marquez.*jar|setupProxy.js|webpack-dev-server.*marquez|npm.*dev.*marquez" | grep -v grep || echo "无相关进程"
}

# 查看日志
show_logs() {
    local service="${1:-api}"
    local lines="${2:-50}"
    
    case "$service" in
        api|marquez)
            if [ -f "${MARQUEZ_LOG_DIR}/marquez.log" ]; then
                echo -e "${BLUE}=== Marquez API 日志 (最后 $lines 行) ===${NC}"
                tail -n "$lines" "${MARQUEZ_LOG_DIR}/marquez.log"
            else
                echo -e "${YELLOW}日志文件不存在: ${MARQUEZ_LOG_DIR}/marquez.log${NC}"
            fi
            ;;
        web)
            if [ -f "${MARQUEZ_LOG_DIR}/web.log" ]; then
                echo -e "${BLUE}=== Marquez Web UI 日志 (最后 $lines 行) ===${NC}"
                tail -n "$lines" "${MARQUEZ_LOG_DIR}/web.log"
            else
                echo -e "${YELLOW}日志文件不存在: ${MARQUEZ_LOG_DIR}/web.log${NC}"
            fi
            ;;
        *)
            echo -e "${RED}错误: 未知的服务 '$service'${NC}"
            echo "用法: $0 logs {api|web} [行数]"
            return 1
            ;;
    esac
}

# 检查健康状态
check_health() {
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}错误: 需要 curl 命令${NC}"
        return 1
    fi
    
    local health_url="http://localhost:${MARQUEZ_API_PORT}/api/v1/health"
    echo -e "${BLUE}检查 Marquez 健康状态...${NC}"
    
    local response=$(curl -s -w "\n%{http_code}" "$health_url" 2>/dev/null || echo "")
    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | head -1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ Marquez 健康状态正常${NC}"
        echo "响应: $body"
        return 0
    else
        echo -e "${RED}✗ Marquez 健康检查失败 (HTTP $http_code)${NC}"
        return 1
    fi
}

# 主函数
main() {
    case "$1" in
        start)
            case "$2" in
                api|"")
                    start_marquez
                    ;;
                web)
                    start_web
                    ;;
                all)
                    start_marquez
                    sleep 2
                    start_web
                    ;;
                *)
                    echo -e "${RED}错误: 未知的服务 '$2'${NC}"
                    echo "用法: $0 start {api|web|all}"
                    exit 1
                    ;;
            esac
            ;;
        stop)
            case "$2" in
                api|"")
                    stop_marquez
                    ;;
                web)
                    stop_web
                    ;;
                all)
                    stop_web
                    stop_marquez
                    ;;
                *)
                    echo -e "${RED}错误: 未知的服务 '$2'${NC}"
                    echo "用法: $0 stop {api|web|all}"
                    exit 1
                    ;;
            esac
            ;;
        restart)
            case "$2" in
                api|"")
                    stop_marquez
                    sleep 2
                    start_marquez
                    ;;
                web)
                    stop_web
                    sleep 2
                    start_web
                    ;;
                all)
                    stop_web
                    stop_marquez
                    sleep 2
                    start_marquez
                    sleep 2
                    start_web
                    ;;
                *)
                    echo -e "${RED}错误: 未知的服务 '$2'${NC}"
                    echo "用法: $0 restart {api|web|all}"
                    exit 1
                    ;;
            esac
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$2" "$3"
            ;;
        health)
            check_health
            ;;
        *)
            echo -e "${BLUE}Marquez 进程管理脚本${NC}"
            echo ""
            echo "用法: $0 {命令} [服务] [选项]"
            echo ""
            echo "命令:"
            echo "  start {api|web|all}     - 启动服务（默认 api）"
            echo "  stop {api|web|all}      - 停止服务（默认 api）"
            echo "  restart {api|web|all}   - 重启服务（默认 api）"
            echo "  status                  - 查看服务状态"
            echo "  logs {api|web} [行数]   - 查看日志（默认 api，50 行）"
            echo "  health                  - 检查 API 健康状态"
            echo ""
            echo "示例:"
            echo "  $0 start                # 启动 Marquez API"
            echo "  $0 start web             # 启动 Web UI"
            echo "  $0 start all             # 启动 API 和 Web UI"
            echo "  $0 stop                 # 停止 Marquez API"
            echo "  $0 stop web              # 停止 Web UI"
            echo "  $0 stop all              # 停止所有服务"
            echo "  $0 restart              # 重启 Marquez API"
            echo "  $0 restart all           # 重启所有服务"
            echo "  $0 status                # 查看状态"
            echo "  $0 logs                  # 查看 API 日志（50 行）"
            echo "  $0 logs web 100          # 查看 Web UI 日志（100 行）"
            echo "  $0 health                # 检查健康状态"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"


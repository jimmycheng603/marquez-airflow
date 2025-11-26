#!/bin/bash
#
# Marquez 数据删除脚本
# 支持删除 dataset、job 和 run（任务执行记录）
#
# 用法:
#   ./delete_marquez_data.sh --type dataset --namespace <namespace> --name <name> [--api-url <url>]
#   ./delete_marquez_data.sh --type job --namespace <namespace> --name <name> [--api-url <url>]
#   ./delete_marquez_data.sh --type namespace --namespace <namespace> [--api-url <url>]
#   ./delete_marquez_data.sh --type run --db --namespace <namespace> --job <job> --run-id <run-id> [--db-host <host>] [--db-port <port>] [--db-name <db>] [--db-user <user>] [--db-password <password>]
#   ./delete_marquez_data.sh --type all --db --namespace <namespace> [--db-host <host>] [--db-port <port>] [--db-name <db>] [--db-user <user>] [--db-password <password>]
#
# 示例:
#   # 通过 API 删除 dataset
#   ./delete_marquez_data.sh --type dataset --namespace my-namespace --name my-dataset
#
#   # 通过 API 删除 job
#   ./delete_marquez_data.sh --type job --namespace my-namespace --name my-job
#
#   # 通过 API 删除 namespace（会删除该 namespace 下的所有 datasets 和 jobs）
#   ./delete_marquez_data.sh --type namespace --namespace my-namespace
#
#   # 通过数据库删除 run
#   ./delete_marquez_data.sh --type run --db --namespace my-namespace --job my-job --run-id <uuid>
#
#   # 通过数据库删除 namespace 下的所有数据
#   ./delete_marquez_data.sh --type all --db --namespace my-namespace

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
API_URL="${MARQUEZ_API_URL:-http://localhost:3000/api/v1}"
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-marquez}"
DB_USER="${POSTGRES_USER:-marquez}"
DB_PASSWORD="${POSTGRES_PASSWORD:-}"

# 变量
TYPE=""
USE_DB=false
NAMESPACE=""
NAME=""
JOB=""
RUN_ID=""
DRY_RUN=false

# 显示帮助信息
show_help() {
    cat <<EOF
Marquez 数据删除脚本

用法:
  $0 [选项]

选项:
  --type TYPE           删除类型: dataset, job, namespace, run, all
                        - dataset: 删除数据集（通过 API，软删除）
                        - job: 删除作业（通过 API，软删除）
                        - namespace: 删除命名空间（通过 API，软删除，会删除该 namespace 下的所有 datasets 和 jobs）
                        - run: 删除运行记录（通过数据库）
                        - all: 删除 namespace 下的所有数据（通过数据库）

  --namespace NAME      命名空间名称（必需）

  --name NAME          数据集或作业名称（删除 dataset/job 时必需）

  --job JOB            作业名称（删除 run 时必需）

  --run-id UUID        运行 ID（删除 run 时必需）

  --api-url URL        Marquez API URL（默认: http://localhost:3000/api/v1）

  --db                 使用数据库直接删除（用于 run 和 all 类型）

  --db-host HOST       数据库主机（默认: localhost）
  --db-port PORT       数据库端口（默认: 5432）
  --db-name NAME       数据库名称（默认: marquez）
  --db-user USER       数据库用户（默认: marquez）
  --db-password PASS   数据库密码

  --dry-run            仅显示将要执行的操作，不实际删除

  -h, --help           显示此帮助信息

环境变量:
  MARQUEZ_API_URL      Marquez API URL
  POSTGRES_HOST        数据库主机
  POSTGRES_PORT        数据库端口
  POSTGRES_DB          数据库名称
  POSTGRES_USER        数据库用户
  POSTGRES_PASSWORD    数据库密码

示例:
  # 通过 API 删除 dataset（软删除）
  $0 --type dataset --namespace my-namespace --name my-dataset

  # 通过 API 删除 job（软删除）
  $0 --type job --namespace my-namespace --name my-job

  # 通过 API 删除 namespace（软删除，会删除该 namespace 下的所有 datasets 和 jobs）
  $0 --type namespace --namespace my-namespace

  # 通过数据库删除 run
  $0 --type run --db --namespace my-namespace --job my-job --run-id <uuid>

  # 通过数据库删除 namespace 下的所有数据
  $0 --type all --db --namespace my-namespace

  # 预览删除操作（不实际执行）
  $0 --type all --db --namespace my-namespace --dry-run

注意:
  - dataset、job 和 namespace 的删除是"软删除"，如果新的 OpenLineage 事件包含这些实体，它们会被恢复
  - run 的删除是"硬删除"，会从数据库中永久删除
  - 删除 namespace 会同时删除该 namespace 下的所有 datasets 和 jobs
  - 删除 namespace 下的所有数据会删除该 namespace 下的所有 datasets、jobs 和 runs
EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                TYPE="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --name)
                NAME="$2"
                shift 2
                ;;
            --job)
                JOB="$2"
                shift 2
                ;;
            --run-id)
                RUN_ID="$2"
                shift 2
                ;;
            --api-url)
                API_URL="$2"
                shift 2
                ;;
            --db)
                USE_DB=true
                shift
                ;;
            --db-host)
                DB_HOST="$2"
                shift 2
                ;;
            --db-port)
                DB_PORT="$2"
                shift 2
                ;;
            --db-name)
                DB_NAME="$2"
                shift 2
                ;;
            --db-user)
                DB_USER="$2"
                shift 2
                ;;
            --db-password)
                DB_PASSWORD="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}错误: 未知选项 '$1'${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# 验证参数
validate_args() {
    if [[ -z "$TYPE" ]]; then
        echo -e "${RED}错误: 必须指定 --type${NC}"
        exit 1
    fi

    if [[ "$TYPE" != "dataset" && "$TYPE" != "job" && "$TYPE" != "namespace" && "$TYPE" != "run" && "$TYPE" != "all" ]]; then
        echo -e "${RED}错误: --type 必须是 dataset, job, namespace, run 或 all${NC}"
        exit 1
    fi

    if [[ -z "$NAMESPACE" ]]; then
        echo -e "${RED}错误: 必须指定 --namespace${NC}"
        exit 1
    fi

    case "$TYPE" in
        dataset|job)
            if [[ -z "$NAME" ]]; then
                echo -e "${RED}错误: 删除 $TYPE 时必须指定 --name${NC}"
                exit 1
            fi
            if [[ "$USE_DB" == true ]]; then
                echo -e "${YELLOW}警告: dataset 和 job 建议使用 API 删除（软删除），使用 --db 会进行硬删除${NC}"
            fi
            ;;
        namespace)
            if [[ "$USE_DB" == true ]]; then
                echo -e "${YELLOW}警告: namespace 建议使用 API 删除（软删除），使用 --db 会进行硬删除${NC}"
            fi
            ;;
        run)
            if [[ "$USE_DB" != true ]]; then
                echo -e "${RED}错误: 删除 run 必须使用 --db 选项${NC}"
                exit 1
            fi
            if [[ -z "$JOB" ]]; then
                echo -e "${RED}错误: 删除 run 时必须指定 --job${NC}"
                exit 1
            fi
            if [[ -z "$RUN_ID" ]]; then
                echo -e "${RED}错误: 删除 run 时必须指定 --run-id${NC}"
                exit 1
            fi
            ;;
        all)
            if [[ "$USE_DB" != true ]]; then
                echo -e "${RED}错误: 删除所有数据必须使用 --db 选项${NC}"
                exit 1
            fi
            ;;
    esac
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}错误: 命令 '$1' 未找到${NC}"
        exit 1
    fi
}

# 通过 API 删除 dataset
delete_dataset_api() {
    local namespace="$1"
    local name="$2"
    local encoded_namespace=$(echo -n "$namespace" | sed 's/ /%20/g')
    local encoded_name=$(echo -n "$name" | sed 's/ /%20/g')
    local url="${API_URL}/namespaces/${encoded_namespace}/datasets/${encoded_name}"

    echo -e "${BLUE}正在通过 API 删除 dataset: ${namespace}/${name}${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] 将执行: curl -X DELETE ${url}${NC}"
        return 0
    fi

    if command -v curl &> /dev/null; then
        response=$(curl -s -w "\n%{http_code}" -X DELETE "$url" 2>&1)
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')

        if [[ "$http_code" == "200" ]]; then
            echo -e "${GREEN}✓ 成功删除 dataset: ${namespace}/${name}${NC}"
            return 0
        else
            echo -e "${RED}✗ 删除失败 (HTTP $http_code): $body${NC}"
            return 1
        fi
    elif command -v wget &> /dev/null; then
        if wget --method=DELETE --header="Accept: application/json" -O - "$url" 2>&1; then
            echo -e "${GREEN}✓ 成功删除 dataset: ${namespace}/${name}${NC}"
            return 0
        else
            echo -e "${RED}✗ 删除失败${NC}"
            return 1
        fi
    else
        echo -e "${RED}错误: 需要 curl 或 wget 命令${NC}"
        return 1
    fi
}

# 通过 API 删除 job
delete_job_api() {
    local namespace="$1"
    local name="$2"
    local encoded_namespace=$(echo -n "$namespace" | sed 's/ /%20/g')
    local encoded_name=$(echo -n "$name" | sed 's/ /%20/g')
    local url="${API_URL}/namespaces/${encoded_namespace}/jobs/${encoded_name}"

    echo -e "${BLUE}正在通过 API 删除 job: ${namespace}/${name}${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] 将执行: curl -X DELETE ${url}${NC}"
        return 0
    fi

    if command -v curl &> /dev/null; then
        response=$(curl -s -w "\n%{http_code}" -X DELETE "$url" 2>&1)
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')

        if [[ "$http_code" == "200" ]]; then
            echo -e "${GREEN}✓ 成功删除 job: ${namespace}/${name}${NC}"
            return 0
        else
            echo -e "${RED}✗ 删除失败 (HTTP $http_code): $body${NC}"
            return 1
        fi
    elif command -v wget &> /dev/null; then
        if wget --method=DELETE --header="Accept: application/json" -O - "$url" 2>&1; then
            echo -e "${GREEN}✓ 成功删除 job: ${namespace}/${name}${NC}"
            return 0
        else
            echo -e "${RED}✗ 删除失败${NC}"
            return 1
        fi
    else
        echo -e "${RED}错误: 需要 curl 或 wget 命令${NC}"
        return 1
    fi
}

# 通过 API 删除 namespace
delete_namespace_api() {
    local namespace="$1"
    local encoded_namespace=$(echo -n "$namespace" | sed 's/ /%20/g')
    local url="${API_URL}/namespaces/${encoded_namespace}"

    echo -e "${BLUE}正在通过 API 删除 namespace: ${namespace}${NC}"
    echo -e "${YELLOW}注意: 这将同时删除该 namespace 下的所有 datasets 和 jobs${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] 将执行: curl -X DELETE ${url}${NC}"
        return 0
    fi

    if command -v curl &> /dev/null; then
        response=$(curl -s -w "\n%{http_code}" -X DELETE "$url" 2>&1)
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')

        if [[ "$http_code" == "200" ]]; then
            echo -e "${GREEN}✓ 成功删除 namespace: ${namespace}${NC}"
            echo -e "${GREEN}✓ 该 namespace 下的所有 datasets 和 jobs 也已被删除${NC}"
            return 0
        else
            echo -e "${RED}✗ 删除失败 (HTTP $http_code): $body${NC}"
            return 1
        fi
    elif command -v wget &> /dev/null; then
        if wget --method=DELETE --header="Accept: application/json" -O - "$url" 2>&1; then
            echo -e "${GREEN}✓ 成功删除 namespace: ${namespace}${NC}"
            echo -e "${GREEN}✓ 该 namespace 下的所有 datasets 和 jobs 也已被删除${NC}"
            return 0
        else
            echo -e "${RED}✗ 删除失败${NC}"
            return 1
        fi
    else
        echo -e "${RED}错误: 需要 curl 或 wget 命令${NC}"
        return 1
    fi
}

# 通过数据库删除 run
delete_run_db() {
    local namespace="$1"
    local job="$2"
    local run_id="$3"

    echo -e "${BLUE}正在通过数据库删除 run: ${namespace}/${job}/${run_id}${NC}"

    # 构建 PGPASSWORD 环境变量（如果提供了密码）
    local pgpass_env=""
    if [[ -n "$DB_PASSWORD" ]]; then
        export PGPASSWORD="$DB_PASSWORD"
    fi

    # 构建 psql 连接字符串
    local psql_cmd="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"

    # 首先验证 run 是否存在
    local check_sql="SELECT COUNT(*) FROM runs r
                     JOIN job_versions jv ON r.job_version_uuid = jv.uuid
                     JOIN jobs j ON jv.job_uuid = j.uuid
                     JOIN namespaces n ON j.namespace_uuid = n.uuid
                     WHERE n.name = '$namespace' AND j.name = '$job' AND r.uuid::text = '$run_id';"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] 将执行以下 SQL:${NC}"
        echo -e "${YELLOW}DELETE FROM runs WHERE uuid = '$run_id' AND uuid IN (
  SELECT r.uuid FROM runs r
  JOIN job_versions jv ON r.job_version_uuid = jv.uuid
  JOIN jobs j ON jv.job_uuid = j.uuid
  JOIN namespaces n ON j.namespace_uuid = n.uuid
  WHERE n.name = '$namespace' AND j.name = '$job'
);${NC}"
        return 0
    fi

    local count=$($psql_cmd -t -c "$check_sql" 2>&1 | tr -d ' ')

    if [[ "$count" == "0" ]]; then
        echo -e "${YELLOW}警告: 未找到 run: ${namespace}/${job}/${run_id}${NC}"
        return 1
    fi

    # 删除 run（由于外键约束，相关数据会自动级联删除）
    local delete_sql="DELETE FROM runs WHERE uuid = '$run_id' AND uuid IN (
  SELECT r.uuid FROM runs r
  JOIN job_versions jv ON r.job_version_uuid = jv.uuid
  JOIN jobs j ON jv.job_uuid = j.uuid
  JOIN namespaces n ON j.namespace_uuid = n.uuid
  WHERE n.name = '$namespace' AND j.name = '$job'
);"

    if $psql_cmd -c "$delete_sql" 2>&1; then
        echo -e "${GREEN}✓ 成功删除 run: ${namespace}/${job}/${run_id}${NC}"
        unset PGPASSWORD
        return 0
    else
        echo -e "${RED}✗ 删除失败${NC}"
        unset PGPASSWORD
        return 1
    fi
}

# 通过数据库删除 namespace 下的所有数据
delete_all_db() {
    local namespace="$1"

    echo -e "${YELLOW}警告: 这将删除 namespace '${namespace}' 下的所有数据！${NC}"
    echo -e "${YELLOW}包括: datasets, jobs, runs 及其所有关联数据${NC}"
    echo -e "${YELLOW}同时会删除 namespace 本身（从下拉框中移除）${NC}"

    if [[ "$DRY_RUN" != true ]]; then
        read -p "确认删除? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo -e "${BLUE}已取消删除操作${NC}"
            return 1
        fi
    fi

    # 构建 PGPASSWORD 环境变量（如果提供了密码）
    local pgpass_env=""
    if [[ -n "$DB_PASSWORD" ]]; then
        export PGPASSWORD="$DB_PASSWORD"
    fi

    # 构建 psql 连接字符串
    local psql_cmd="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"

    # 首先获取 namespace UUID
    local namespace_uuid=$($psql_cmd -t -c "SELECT uuid FROM namespaces WHERE name = '$namespace';" 2>&1 | tr -d ' ')

    if [[ -z "$namespace_uuid" ]]; then
        echo -e "${YELLOW}警告: 未找到 namespace: ${namespace}${NC}"
        unset PGPASSWORD
        return 1
    fi

    echo -e "${BLUE}找到 namespace UUID: ${namespace_uuid}${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] 将执行以下操作:${NC}"
        echo -e "${YELLOW}1. 删除所有 runs（通过级联删除相关数据）${NC}"
        echo -e "${YELLOW}2. 删除所有 datasets（通过级联删除相关数据）${NC}"
        echo -e "${YELLOW}3. 删除所有 jobs（通过级联删除相关数据）${NC}"
        echo -e "${YELLOW}4. 删除 namespace_ownerships（所有权关系）${NC}"
        echo -e "${YELLOW}5. 删除 dataset_symlinks（数据集符号链接）${NC}"
        echo -e "${YELLOW}6. 删除 namespace（设置 is_hidden=true，从下拉框中移除）${NC}"
        unset PGPASSWORD
        return 0
    fi

    # 统计要删除的数据量
    local runs_count=$($psql_cmd -t -c "SELECT COUNT(*) FROM runs r JOIN job_versions jv ON r.job_version_uuid = jv.uuid JOIN jobs j ON jv.job_uuid = j.uuid WHERE j.namespace_uuid = '$namespace_uuid';" 2>&1 | tr -d ' ')
    local datasets_count=$($psql_cmd -t -c "SELECT COUNT(*) FROM datasets WHERE namespace_uuid = '$namespace_uuid';" 2>&1 | tr -d ' ')
    local jobs_count=$($psql_cmd -t -c "SELECT COUNT(*) FROM jobs WHERE namespace_uuid = '$namespace_uuid';" 2>&1 | tr -d ' ')

    echo -e "${BLUE}统计信息:${NC}"
    echo -e "  - Runs: ${runs_count}"
    echo -e "  - Datasets: ${datasets_count}"
    echo -e "  - Jobs: ${jobs_count}"

    # 删除 runs（级联删除相关数据）
    echo -e "${BLUE}正在删除 runs...${NC}"
    $psql_cmd -c "DELETE FROM runs WHERE job_version_uuid IN (SELECT uuid FROM job_versions WHERE job_uuid IN (SELECT uuid FROM jobs WHERE namespace_uuid = '$namespace_uuid'));" 2>&1

    # 删除 datasets（级联删除相关数据）
    echo -e "${BLUE}正在删除 datasets...${NC}"
    $psql_cmd -c "DELETE FROM datasets WHERE namespace_uuid = '$namespace_uuid';" 2>&1

    # 删除 jobs（级联删除相关数据）
    echo -e "${BLUE}正在删除 jobs...${NC}"
    $psql_cmd -c "DELETE FROM jobs WHERE namespace_uuid = '$namespace_uuid';" 2>&1

    # 删除 namespace 相关的其他数据
    echo -e "${BLUE}正在清理 namespace 相关数据...${NC}"
    # 删除 namespace_ownerships（所有权关系）
    $psql_cmd -c "DELETE FROM namespace_ownerships WHERE namespace_uuid = '$namespace_uuid';" 2>&1
    # 删除 dataset_symlinks（数据集符号链接）
    $psql_cmd -c "DELETE FROM dataset_symlinks WHERE namespace_uuid = '$namespace_uuid';" 2>&1

    # 删除 namespace 本身（软删除，设置 is_hidden=true，从下拉框中移除）
    echo -e "${BLUE}正在删除 namespace...${NC}"
    $psql_cmd -c "UPDATE namespaces SET is_hidden = true WHERE uuid = '$namespace_uuid';" 2>&1

    echo -e "${GREEN}✓ 成功删除 namespace '${namespace}' 下的所有数据${NC}"
    echo -e "${GREEN}✓ 成功删除 namespace '${namespace}'（已从下拉框中移除）${NC}"
    unset PGPASSWORD
    return 0
}

# 通过数据库删除 dataset
delete_dataset_db() {
    local namespace="$1"
    local name="$2"

    echo -e "${BLUE}正在通过数据库删除 dataset: ${namespace}/${name}${NC}"

    # 构建 PGPASSWORD 环境变量（如果提供了密码）
    if [[ -n "$DB_PASSWORD" ]]; then
        export PGPASSWORD="$DB_PASSWORD"
    fi

    # 构建 psql 连接字符串
    local psql_cmd="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] 将执行以下 SQL:${NC}"
        echo -e "${YELLOW}DELETE FROM datasets WHERE uuid IN (
  SELECT d.uuid FROM datasets d
  JOIN namespaces n ON d.namespace_uuid = n.uuid
  WHERE n.name = '$namespace' AND d.name = '$name'
);${NC}"
        unset PGPASSWORD
        return 0
    fi

    # 删除 dataset（级联删除相关数据）
    local delete_sql="DELETE FROM datasets WHERE uuid IN (
  SELECT d.uuid FROM datasets d
  JOIN namespaces n ON d.namespace_uuid = n.uuid
  WHERE n.name = '$namespace' AND d.name = '$name'
);"

    if $psql_cmd -c "$delete_sql" 2>&1; then
        echo -e "${GREEN}✓ 成功删除 dataset: ${namespace}/${name}${NC}"
        unset PGPASSWORD
        return 0
    else
        echo -e "${RED}✗ 删除失败${NC}"
        unset PGPASSWORD
        return 1
    fi
}

# 通过数据库删除 job
delete_job_db() {
    local namespace="$1"
    local name="$2"

    echo -e "${BLUE}正在通过数据库删除 job: ${namespace}/${name}${NC}"

    # 构建 PGPASSWORD 环境变量（如果提供了密码）
    if [[ -n "$DB_PASSWORD" ]]; then
        export PGPASSWORD="$DB_PASSWORD"
    fi

    # 构建 psql 连接字符串
    local psql_cmd="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] 将执行以下 SQL:${NC}"
        echo -e "${YELLOW}DELETE FROM jobs WHERE uuid IN (
  SELECT j.uuid FROM jobs j
  JOIN namespaces n ON j.namespace_uuid = n.uuid
  WHERE n.name = '$namespace' AND j.name = '$name'
);${NC}"
        unset PGPASSWORD
        return 0
    fi

    # 删除 job（级联删除相关数据）
    local delete_sql="DELETE FROM jobs WHERE uuid IN (
  SELECT j.uuid FROM jobs j
  JOIN namespaces n ON j.namespace_uuid = n.uuid
  WHERE n.name = '$namespace' AND j.name = '$name'
);"

    if $psql_cmd -c "$delete_sql" 2>&1; then
        echo -e "${GREEN}✓ 成功删除 job: ${namespace}/${name}${NC}"
        unset PGPASSWORD
        return 0
    else
        echo -e "${RED}✗ 删除失败${NC}"
        unset PGPASSWORD
        return 1
    fi
}

# 主函数
main() {
    parse_args "$@"
    validate_args

    # 检查必要的命令
    if [[ "$USE_DB" == true ]]; then
        check_command psql
    else
        if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
            echo -e "${RED}错误: 需要 curl 或 wget 命令${NC}"
            exit 1
        fi
    fi

    echo -e "${BLUE}=== Marquez 数据删除脚本 ===${NC}"
    echo ""

    case "$TYPE" in
        dataset)
            if [[ "$USE_DB" == true ]]; then
                delete_dataset_db "$NAMESPACE" "$NAME"
            else
                delete_dataset_api "$NAMESPACE" "$NAME"
            fi
            ;;
        job)
            if [[ "$USE_DB" == true ]]; then
                delete_job_db "$NAMESPACE" "$NAME"
            else
                delete_job_api "$NAMESPACE" "$NAME"
            fi
            ;;
        namespace)
            delete_namespace_api "$NAMESPACE"
            ;;
        run)
            delete_run_db "$NAMESPACE" "$JOB" "$RUN_ID"
            ;;
        all)
            delete_all_db "$NAMESPACE"
            ;;
    esac
}

# bash delete_marquez_data.sh --type namespace --namespace test-namespace --db-password 1qaz@WSX
# bash delete_marquez_data.sh --type all --db --namespace test-namespace --db-password 1qaz@WSX
# 执行 主函数
main "$@"


#!/usr/bin/env python3
"""
Marquez 数据血缘测试脚本
创建复杂的6层数据血缘关系，展示优化后的 Web UI 效果：
- 层级1: 数据源采集
- 层级2: 数据提取和元数据收集
- 层级3: 数据清洗和转换
- 层级4: 数据聚合和验证
- 层级5: 指标计算和导出
- 层级6: 最终业务报告
"""

import json
import requests
import uuid
from datetime import datetime, timezone
from typing import List, Dict, Any

# Marquez API 配置
MARQUEZ_API_URL = "http://localhost:3000/api/v1"
NAMESPACE = "default"
PRODUCER = "https://github.com/marquez-project/marquez/tree/main/bin/test_lineage.py"


def generate_run_id() -> str:
    """生成唯一的 run ID"""
    return str(uuid.uuid4())


def create_lineage_event(
    event_type: str,
    job_name: str,
    inputs: List[Dict[str, Any]],
    outputs: List[Dict[str, Any]],
    run_id: str = None
) -> Dict[str, Any]:
    """
    创建 OpenLineage 事件
    
    Args:
        event_type: 事件类型 (START, RUNNING, COMPLETE, ABORT, FAIL)
        job_name: 作业名称
        inputs: 输入数据集列表
        outputs: 输出数据集列表
        run_id: 运行 ID（可选，如果不提供则自动生成）
    """
    if run_id is None:
        run_id = generate_run_id()
    
    event = {
        "eventType": event_type,
        "eventTime": datetime.now(timezone.utc).isoformat(),
        "run": {
            "runId": run_id
        },
        "job": {
            "namespace": NAMESPACE,
            "name": job_name
        },
        "inputs": inputs,
        "outputs": outputs,
        "producer": PRODUCER
    }
    
    return event


def create_dataset(name: str, schema_fields: List[Dict[str, str]] = None) -> Dict[str, Any]:
    """
    创建数据集定义
    
    Args:
        name: 数据集名称
        schema_fields: Schema 字段列表
    """
    dataset = {
        "namespace": NAMESPACE,
        "name": name
    }
    
    if schema_fields:
        dataset["facets"] = {
            "schema": {
                "_producer": PRODUCER,
                "_schemaURL": "https://github.com/OpenLineage/OpenLineage/blob/v1-0-0/spec/OpenLineage.json#/definitions/SchemaDatasetFacet",
                "fields": schema_fields
            }
        }
    
    return dataset


def send_lineage_event(event: Dict[str, Any]) -> bool:
    """
    发送 OpenLineage 事件到 Marquez
    
    Args:
        event: OpenLineage 事件字典
    """
    url = f"{MARQUEZ_API_URL}/lineage"
    headers = {
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.post(url, json=event, headers=headers, timeout=10)
        if response.status_code in [200, 201]:
            print(f"✓ 成功发送事件: {event['job']['name']} ({event['eventType']})")
            return True
        else:
            print(f"✗ 发送失败: {event['job']['name']} - HTTP {response.status_code}")
            print(f"  响应: {response.text}")
            return False
    except Exception as e:
        print(f"✗ 发送错误: {event['job']['name']} - {str(e)}")
        return False


def create_namespace():
    """创建命名空间"""
    url = f"{MARQUEZ_API_URL}/namespaces/{NAMESPACE}"
    data = {
        "ownerName": "test-user",
        "description": "测试命名空间"
    }
    
    try:
        response = requests.put(url, json=data, timeout=10)
        if response.status_code in [200, 201]:
            print(f"✓ 命名空间 '{NAMESPACE}' 已创建或已存在")
            return True
        else:
            print(f"✗ 创建命名空间失败: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ 创建命名空间错误: {str(e)}")
        return False


def main():
    """主函数：创建复杂的6层数据血缘关系"""
    print("=" * 80)
    print("Marquez 复杂数据血缘测试脚本 - 6层深度结构")
    print("=" * 80)
    print()
    
    # 1. 创建命名空间
    print("1. 创建命名空间...")
    if not create_namespace():
        print("   警告: 命名空间创建失败，继续执行...")
    print()
    
    # 2. 定义数据集 Schema（所有名称至少10个字符）
    base_schema = [{"name": "record_id", "type": "VARCHAR"}, {"name": "timestamp", "type": "TIMESTAMP"}, {"name": "data_value", "type": "DOUBLE"}]
    
    # 层级1: 数据源
    schema_source = base_schema + [{"name": "source_system", "type": "VARCHAR"}]
    
    # 层级2: 提取和收集
    schema_raw = base_schema + [{"name": "extraction_metadata", "type": "JSON"}]
    schema_metadata = base_schema + [{"name": "metadata_info", "type": "JSON"}]
    
    # 层级3: 清洗和转换
    schema_cleaned = base_schema + [{"name": "cleaned_flag", "type": "BOOLEAN"}, {"name": "quality_score", "type": "DOUBLE"}]
    schema_validated = base_schema + [{"name": "validation_status", "type": "VARCHAR"}, {"name": "transformation_rules", "type": "JSON"}]
    
    # 层级4: 聚合和验证
    schema_transformed = base_schema + [{"name": "aggregation_key", "type": "VARCHAR"}, {"name": "aggregated_metrics", "type": "JSON"}]
    schema_enriched = base_schema + [{"name": "enrichment_data", "type": "JSON"}, {"name": "validation_results", "type": "JSON"}]
    schema_quality = base_schema + [{"name": "quality_metrics", "type": "JSON"}, {"name": "check_results", "type": "JSON"}]
    
    # 层级5: 指标计算和导出
    schema_aggregated_metrics = base_schema + [{"name": "calculated_metrics", "type": "JSON"}, {"name": "metric_dimensions", "type": "JSON"}]
    schema_validated_metrics = base_schema + [{"name": "validated_metrics", "type": "JSON"}, {"name": "export_format", "type": "VARCHAR"}]
    schema_enriched_metrics = base_schema + [{"name": "enriched_metrics", "type": "JSON"}, {"name": "additional_context", "type": "JSON"}]
    
    # 层级6: 最终报告
    schema_final_report = base_schema + [{"name": "report_sections", "type": "JSON"}, {"name": "business_insights", "type": "JSON"}, {"name": "visualization_data", "type": "JSON"}]
    
    # 3. 创建数据血缘关系（6层深度）
    print("2. 创建6层数据血缘关系...")
    print()
    
    # ========== 层级1: 数据源 ==========
    print("   [层级1] 数据源采集")
    dataset_source = "source_data_ingestion"
    run_source = generate_run_id()
    event_source_start = create_lineage_event(
        event_type="START",
        job_name="job_source_data_ingestion",
        inputs=[],
        outputs=[],
        run_id=run_source
    )
    send_lineage_event(event_source_start)
    
    event_source_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_source_data_ingestion",
        inputs=[],
        outputs=[create_dataset(dataset_source, schema_source)],
        run_id=run_source
    )
    send_lineage_event(event_source_complete)
    print()
    
    # ========== 层级2: 数据提取和元数据收集 ==========
    print("   [层级2] 数据提取和元数据收集")
    
    # Job: 原始数据提取
    dataset_raw = "raw_data_extraction"
    run_raw = generate_run_id()
    event_raw_start = create_lineage_event(
        event_type="START",
        job_name="job_raw_data_extraction",
        inputs=[create_dataset(dataset_source, schema_source)],
        outputs=[],
        run_id=run_raw
    )
    send_lineage_event(event_raw_start)
    
    event_raw_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_raw_data_extraction",
        inputs=[create_dataset(dataset_source, schema_source)],
        outputs=[create_dataset(dataset_raw, schema_raw)],
        run_id=run_raw
    )
    send_lineage_event(event_raw_complete)
    print()
    
    # Job: 元数据收集
    dataset_metadata = "metadata_collection"
    run_metadata = generate_run_id()
    event_metadata_start = create_lineage_event(
        event_type="START",
        job_name="job_metadata_collection",
        inputs=[create_dataset(dataset_source, schema_source)],
        outputs=[],
        run_id=run_metadata
    )
    send_lineage_event(event_metadata_start)
    
    event_metadata_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_metadata_collection",
        inputs=[create_dataset(dataset_source, schema_source)],
        outputs=[create_dataset(dataset_metadata, schema_metadata)],
        run_id=run_metadata
    )
    send_lineage_event(event_metadata_complete)
    print()
    
    # ========== 层级3: 数据清洗和转换 ==========
    print("   [层级3] 数据清洗和转换")
    
    # Job: 数据清洗处理
    dataset_cleaned = "cleaned_data_processing"
    run_cleaned = generate_run_id()
    event_cleaned_start = create_lineage_event(
        event_type="START",
        job_name="job_cleaned_data_processing",
        inputs=[
            create_dataset(dataset_raw, schema_raw),
            create_dataset(dataset_metadata, schema_metadata)
        ],
        outputs=[],
        run_id=run_cleaned
    )
    send_lineage_event(event_cleaned_start)
    
    event_cleaned_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_cleaned_data_processing",
        inputs=[
            create_dataset(dataset_raw, schema_raw),
            create_dataset(dataset_metadata, schema_metadata)
        ],
        outputs=[create_dataset(dataset_cleaned, schema_cleaned)],
        run_id=run_cleaned
    )
    send_lineage_event(event_cleaned_complete)
    print()
    
    # Job: 数据验证转换
    dataset_validated = "validated_data_transformation"
    run_validated = generate_run_id()
    event_validated_start = create_lineage_event(
        event_type="START",
        job_name="job_validated_data_transformation",
        inputs=[create_dataset(dataset_raw, schema_raw)],
        outputs=[],
        run_id=run_validated
    )
    send_lineage_event(event_validated_start)
    
    event_validated_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_validated_data_transformation",
        inputs=[create_dataset(dataset_raw, schema_raw)],
        outputs=[create_dataset(dataset_validated, schema_validated)],
        run_id=run_validated
    )
    send_lineage_event(event_validated_complete)
    print()
    
    # ========== 层级4: 数据聚合和验证 ==========
    print("   [层级4] 数据聚合和验证")
    
    # Job: 转换数据聚合
    dataset_transformed = "transformed_data_aggregation"
    run_transformed = generate_run_id()
    event_transformed_start = create_lineage_event(
        event_type="START",
        job_name="job_transformed_data_aggregation",
        inputs=[create_dataset(dataset_cleaned, schema_cleaned)],
        outputs=[],
        run_id=run_transformed
    )
    send_lineage_event(event_transformed_start)
    
    event_transformed_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_transformed_data_aggregation",
        inputs=[create_dataset(dataset_cleaned, schema_cleaned)],
        outputs=[create_dataset(dataset_transformed, schema_transformed)],
        run_id=run_transformed
    )
    send_lineage_event(event_transformed_complete)
    print()
    
    # Job: 质量检查数据
    dataset_quality = "quality_checked_data"
    run_quality = generate_run_id()
    event_quality_start = create_lineage_event(
        event_type="START",
        job_name="job_quality_checked_data",
        inputs=[create_dataset(dataset_validated, schema_validated)],
        outputs=[],
        run_id=run_quality
    )
    send_lineage_event(event_quality_start)
    
    event_quality_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_quality_checked_data",
        inputs=[create_dataset(dataset_validated, schema_validated)],
        outputs=[create_dataset(dataset_quality, schema_quality)],
        run_id=run_quality
    )
    send_lineage_event(event_quality_complete)
    print()
    
    # Job: 丰富数据验证
    dataset_enriched = "enriched_data_validation"
    run_enriched = generate_run_id()
    event_enriched_start = create_lineage_event(
        event_type="START",
        job_name="job_enriched_data_validation",
        inputs=[
            create_dataset(dataset_cleaned, schema_cleaned),
            create_dataset(dataset_quality, schema_quality)
        ],
        outputs=[],
        run_id=run_enriched
    )
    send_lineage_event(event_enriched_start)
    
    event_enriched_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_enriched_data_validation",
        inputs=[
            create_dataset(dataset_cleaned, schema_cleaned),
            create_dataset(dataset_quality, schema_quality)
        ],
        outputs=[create_dataset(dataset_enriched, schema_enriched)],
        run_id=run_enriched
    )
    send_lineage_event(event_enriched_complete)
    print()
    
    # ========== 层级5: 指标计算和导出 ==========
    print("   [层级5] 指标计算和导出")
    
    # Job: 聚合指标计算
    dataset_aggregated_metrics = "aggregated_metrics_calculation"
    run_aggregated_metrics = generate_run_id()
    event_aggregated_metrics_start = create_lineage_event(
        event_type="START",
        job_name="job_aggregated_metrics_calculation",
        inputs=[create_dataset(dataset_transformed, schema_transformed)],
        outputs=[],
        run_id=run_aggregated_metrics
    )
    send_lineage_event(event_aggregated_metrics_start)
    
    event_aggregated_metrics_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_aggregated_metrics_calculation",
        inputs=[create_dataset(dataset_transformed, schema_transformed)],
        outputs=[create_dataset(dataset_aggregated_metrics, schema_aggregated_metrics)],
        run_id=run_aggregated_metrics
    )
    send_lineage_event(event_aggregated_metrics_complete)
    print()
    
    # Job: 验证指标导出
    dataset_validated_metrics = "validated_metrics_export"
    run_validated_metrics = generate_run_id()
    event_validated_metrics_start = create_lineage_event(
        event_type="START",
        job_name="job_validated_metrics_export",
        inputs=[create_dataset(dataset_transformed, schema_transformed)],
        outputs=[],
        run_id=run_validated_metrics
    )
    send_lineage_event(event_validated_metrics_start)
    
    event_validated_metrics_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_validated_metrics_export",
        inputs=[create_dataset(dataset_transformed, schema_transformed)],
        outputs=[create_dataset(dataset_validated_metrics, schema_validated_metrics)],
        run_id=run_validated_metrics
    )
    send_lineage_event(event_validated_metrics_complete)
    print()
    
    # Job: 丰富指标导出
    dataset_enriched_metrics = "enriched_metrics_export"
    run_enriched_metrics = generate_run_id()
    event_enriched_metrics_start = create_lineage_event(
        event_type="START",
        job_name="job_enriched_metrics_export",
        inputs=[create_dataset(dataset_enriched, schema_enriched)],
        outputs=[],
        run_id=run_enriched_metrics
    )
    send_lineage_event(event_enriched_metrics_start)
    
    event_enriched_metrics_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_enriched_metrics_export",
        inputs=[create_dataset(dataset_enriched, schema_enriched)],
        outputs=[create_dataset(dataset_enriched_metrics, schema_enriched_metrics)],
        run_id=run_enriched_metrics
    )
    send_lineage_event(event_enriched_metrics_complete)
    print()
    
    # ========== 层级6: 最终业务报告 ==========
    print("   [层级6] 最终业务报告生成")
    
    dataset_final_report = "final_business_intelligence_report"
    run_final_report = generate_run_id()
    event_final_report_start = create_lineage_event(
        event_type="START",
        job_name="job_final_business_intelligence_report",
        inputs=[
            create_dataset(dataset_aggregated_metrics, schema_aggregated_metrics),
            create_dataset(dataset_validated_metrics, schema_validated_metrics),
            create_dataset(dataset_enriched_metrics, schema_enriched_metrics)
        ],
        outputs=[],
        run_id=run_final_report
    )
    send_lineage_event(event_final_report_start)
    
    event_final_report_complete = create_lineage_event(
        event_type="COMPLETE",
        job_name="job_final_business_intelligence_report",
        inputs=[
            create_dataset(dataset_aggregated_metrics, schema_aggregated_metrics),
            create_dataset(dataset_validated_metrics, schema_validated_metrics),
            create_dataset(dataset_enriched_metrics, schema_enriched_metrics)
        ],
        outputs=[create_dataset(dataset_final_report, schema_final_report)],
        run_id=run_final_report
    )
    send_lineage_event(event_final_report_complete)
    print()
    
    print("=" * 80)
    print("复杂数据血缘关系创建完成！")
    print("=" * 80)
    print()
    print("6层血缘关系图：")
    print("  source_data_ingestion (L1)")
    print("    ├──> raw_data_extraction (L2)")
    print("    │      ├──> cleaned_data_processing (L3)")
    print("    │      │      ├──> transformed_data_aggregation (L4)")
    print("    │      │      │      ├──> aggregated_metrics_calculation (L5)")
    print("    │      │      │      │      └──> final_business_intelligence_report (L6)")
    print("    │      │      │      └──> validated_metrics_export (L5)")
    print("    │      │      │             └──> final_business_intelligence_report (L6)")
    print("    │      │      └──> enriched_data_validation (L4)")
    print("    │      │             └──> enriched_metrics_export (L5)")
    print("    │      │                    └──> final_business_intelligence_report (L6)")
    print("    │      └──> validated_data_transformation (L3)")
    print("    │             └──> quality_checked_data (L4)")
    print("    │                    └──> enriched_data_validation (L4) [合并点]")
    print("    └──> metadata_collection (L2)")
    print("           └──> cleaned_data_processing (L3) [合并点]")
    print()
    print(f"查看最终报告血缘关系:")
    print(f"  {MARQUEZ_API_URL.replace('/api/v1', '')}/lineage?nodeId=dataset:{NAMESPACE}:{dataset_final_report}")
    print()
    print(f"Web UI: http://localhost:8080")
    print()
    print("提示：在 Web UI 中使用 Show Jobs/Show Datasets 开关可以灵活查看不同层级的数据流！")


if __name__ == "__main__":
    main()


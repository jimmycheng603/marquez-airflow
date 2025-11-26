import { Edge, Node as ElkNode } from '../../../libs/graph'
import { LineageGraph } from '../../types/api'

import { JobOrDataset, LineageDataset, LineageJob, LineageNode } from '../../types/lineage'
import { Nullable } from '../../types/util/Nullable'
import { TableLevelNodeData } from './nodes'
import { theme } from '../../helpers/theme'

/**
 * 计算文本不换行时的宽度
 * @param text 文本内容
 * @param fontSize 字体大小（px），默认 8
 * @returns 文本宽度（px）
 */
const calculateTextWidth = (
  text: string,
  fontSize: number = 8
): number => {
  if (!text) return 0
  // 对于等宽字体（mono），每个字符宽度约为字体大小的 60%
  // 使用保守估算：每字符 5px（对于 8px 字体）
  return text.length * (fontSize * 0.625)
}

/**
 * 计算文本换行后的高度（用于字段列表等其他需要换行的文本）
 * @param text 文本内容
 * @param availableWidth 可用宽度（px）
 * @param fontSize 字体大小（px），默认 8
 * @param lineHeight 行高倍数，默认 1.2
 * @returns 文本高度（px）
 */
const calculateTextHeight = (
  text: string,
  availableWidth: number,
  fontSize: number = 8,
  lineHeight: number = 1.2
): number => {
  if (!text) return fontSize * lineHeight

  // 估算平均字符宽度（对于等宽字体约为字体大小的 60%，对于非等宽字体更小）
  // 使用保守估算：每行大约可以显示 10-12 个字符（对于 8px 字体，80px 宽度）
  const charsPerLine = Math.floor(availableWidth / (fontSize * 0.7))
  const lines = Math.max(1, Math.ceil(text.length / charsPerLine))

  // 返回总高度：行数 * 每行高度
  return lines * fontSize * lineHeight
}

/**
 * Recursively trace the `inEdges` and `outEdges` of the current node to find all connected downstream column nodes
 * @param lineageGraph
 * @param currentGraphNode
 */
export const findDownstreamNodes = (
  lineageGraph: LineageGraph,
  currentGraphNode: Nullable<string>
): LineageNode[] => {
  if (!currentGraphNode) return []
  const currentNode = lineageGraph.graph.find((node) => node.id === currentGraphNode)
  if (!currentNode) return []
  const connectedNodes: LineageNode[] = []
  const visitedNodes: string[] = []
  const queue: LineageNode[] = [currentNode]

  while (queue.length) {
    const currentNode = queue.shift()
    if (!currentNode) continue
    if (visitedNodes.includes(currentNode.id)) continue
    visitedNodes.push(currentNode.id)
    connectedNodes.push(currentNode)
    queue.push(
      ...currentNode.outEdges
        .map((edge) => lineageGraph.graph.find((n) => n.id === edge.destination))
        .filter((item): item is LineageNode => !!item)
    )
  }
  return connectedNodes
}
/**
 * Recursively trace the `inEdges` and `outEdges` of the current node to find all connected upstream column nodes
 * @param lineageGraph
 * @param currentGraphNode
 */
export const findUpstreamNodes = (
  lineageGraph: LineageGraph,
  currentGraphNode: Nullable<string>
): LineageNode[] => {
  if (!currentGraphNode) return []
  const currentNode = lineageGraph.graph.find((node) => node.id === currentGraphNode)
  if (!currentNode) return []
  const connectedNodes: LineageNode[] = []
  const visitedNodes: string[] = []
  const queue: LineageNode[] = [currentNode]

  while (queue.length) {
    const currentNode = queue.shift()
    if (!currentNode) continue
    if (visitedNodes.includes(currentNode.id)) continue
    visitedNodes.push(currentNode.id)
    connectedNodes.push(currentNode)
    queue.push(
      ...currentNode.inEdges
        .map((edge) => lineageGraph.graph.find((n) => n.id === edge.origin))
        .filter((item): item is LineageNode => !!item)
    )
  }
  return connectedNodes
}

export const createElkNodes = (
  lineageGraph: LineageGraph,
  currentGraphNode: Nullable<string>,
  isCompact: boolean,
  isFull: boolean,
  collapsedNodes: Nullable<string>,
  showJobs: boolean = true,
  showDatasets: boolean = true
) => {
  const downstreamNodes = findDownstreamNodes(lineageGraph, currentGraphNode)
  const upstreamNodes = findUpstreamNodes(lineageGraph, currentGraphNode)

  const nodes: ElkNode<JobOrDataset, TableLevelNodeData>[] = []
  const edges: Edge[] = []

  const collapsedNodesAsArray = collapsedNodes?.split(',')

  const filteredGraph = lineageGraph.graph.filter((node) => {
    if (isFull) return true
    return (
      downstreamNodes.includes(node) || upstreamNodes.includes(node) || node.id === currentGraphNode
    )
  })

  // 收集通过dataset连接的job对（当showDatasets为false时使用）
  const jobToJobThroughDataset = new Map<string, Set<string>>()

  for (const node of filteredGraph) {
    // 如果showJobs为false，只显示dag（没有parentJob的job），隐藏task（有parentJob的job）
    if (!showJobs && node.type === 'JOB') {
      const job = node.data as LineageJob
      // 如果有parentJobName或parentJobUuid，说明是task，需要隐藏
      if (job.parentJobName || job.parentJobUuid) {
        continue
      }
    }

    // 如果showDatasets为false，跳过dataset节点，但记录通过dataset连接的job对
    if (!showDatasets && node.type === 'DATASET') {
      // 找到所有连接到这个dataset的job（输入）
      const inputJobs = filteredGraph
        .filter((n) => {
          if (n.type !== 'JOB') return false
          if (!showJobs) {
            const job = n.data as LineageJob
            if (job.parentJobName || job.parentJobUuid) return false
          }
          return n.outEdges.some((e) => e.destination === node.id)
        })
        .map((n) => n.id)

      // 找到所有这个dataset连接的job（输出）
      const outputJobs = filteredGraph
        .filter((n) => {
          if (n.type !== 'JOB') return false
          if (!showJobs) {
            const job = n.data as LineageJob
            if (job.parentJobName || job.parentJobUuid) return false
          }
          return node.outEdges.some((e) => e.destination === n.id)
        })
        .map((n) => n.id)

      // 创建从输入job到输出job的直接连接
      for (const inputJob of inputJobs) {
        if (!jobToJobThroughDataset.has(inputJob)) {
          jobToJobThroughDataset.set(inputJob, new Set())
        }
        for (const outputJob of outputJobs) {
          jobToJobThroughDataset.get(inputJob)!.add(outputJob)
        }
      }
      continue
    }

    edges.push(
      ...node.outEdges
        .filter((edge) => {
          const targetNode = filteredGraph.find((n) => n.id === edge.destination)
          if (!targetNode) return false

          // 如果showDatasets为false，过滤掉连接到dataset节点的边
          if (!showDatasets && targetNode.type === 'DATASET') {
            return false
          }

          // 如果showJobs为false，过滤掉连接到task节点的边（dag节点保留）
          if (!showJobs && targetNode.type === 'JOB') {
            const targetJob = targetNode.data as LineageJob
            // 如果目标节点是task（有parentJob），则过滤掉这条边
            if (targetJob.parentJobName || targetJob.parentJobUuid) {
              return false
            }
          }
          return true
        })
        .map((edge) => {
          return {
            id: `${edge.origin}:${edge.destination}`,
            sourceNodeId: edge.origin,
            targetNodeId: edge.destination,
            color:
              downstreamNodes.includes(node) || upstreamNodes.includes(node)
                ? theme.palette.primary.main
                : theme.palette.grey[400],
          }
        })
    )

    if (node.type === 'JOB') {
      const job = node.data as LineageJob
      const minWidth = 112 // 最小宽度
      // 默认换行模式：固定宽度，根据文本计算高度
      const nodeWidth = minWidth
      const textHeight = calculateTextHeight(job.name, 80, 8, 1.2) // Job 可用宽度 = 112 - 32 = 80px
      const baseHeight = 10 // "JOB" 标签行
      const minHeight = 24
      const nodeHeight = Math.max(minHeight, baseHeight + textHeight + 2) // +2 为上下边距

      nodes.push({
        id: node.id,
        kind: node.type,
        width: nodeWidth,
        height: nodeHeight,
        data: {
          job: job,
        },
      })
    } else if (node.type === 'DATASET') {
      const data = node.data as LineageDataset
      const minWidth = 112 // 最小宽度
      // 默认换行模式：固定宽度，根据文本计算高度
      const nodeWidth = minWidth
      let nodeHeight: number

      if (isCompact || collapsedNodesAsArray?.includes(node.id)) {
        // Compact 模式：只计算文本高度
        const textHeight = calculateTextHeight(data.name, 62, 8, 1.2) // Dataset 可用宽度 = 112 - 50 = 62px
        const baseHeight = 10 // "DATASET" 标签行
        const minHeight = 24
        nodeHeight = Math.max(minHeight, baseHeight + textHeight + 2)
      } else {
        // 展开模式：文本高度 + 字段列表
        const textHeight = calculateTextHeight(data.name, 62, 8, 1.2)
        const baseHeight = 10 // "DATASET" 标签行
        const fieldsHeight = data.fields.length * 10
        const calculatedHeight = baseHeight + textHeight + fieldsHeight + 4 // +4 为上下边距
        const minHeight = 34 + fieldsHeight
        nodeHeight = Math.max(minHeight, calculatedHeight)
      }

      nodes.push({
        id: node.id,
        kind: node.type,
        width: nodeWidth,
        height: nodeHeight,
        data: {
          dataset: data,
        },
      })
    }
  }

  // 如果showDatasets为false，添加通过dataset连接的job到job的直接边
  if (!showDatasets) {
    for (const [sourceJobId, targetJobIds] of jobToJobThroughDataset.entries()) {
      // 检查source job是否在nodes中
      const sourceNode = nodes.find((n) => n.id === sourceJobId)
      if (!sourceNode) continue

      for (const targetJobId of targetJobIds) {
        // 检查target job是否在nodes中
        const targetNode = nodes.find((n) => n.id === targetJobId)
        if (!targetNode) continue

        // 检查边是否已存在
        const edgeExists = edges.some(
          (e) => e.sourceNodeId === sourceJobId && e.targetNodeId === targetJobId
        )
        if (!edgeExists) {
          edges.push({
            id: `${sourceJobId}:${targetJobId}`,
            sourceNodeId: sourceJobId,
            targetNodeId: targetJobId,
            color:
              downstreamNodes.some((n) => n.id === sourceJobId) ||
                upstreamNodes.some((n) => n.id === sourceJobId)
                ? theme.palette.primary.main
                : theme.palette.grey[400],
          })
        }
      }
    }
  }

  return { nodes, edges }
}

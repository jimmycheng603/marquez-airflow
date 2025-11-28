// Copyright 2018-2023 contributors to the Marquez project
// SPDX-License-Identifier: Apache-2.0

import * as Redux from 'redux'
import {
  Button,
  Chip,
  Container,
  MenuItem,
  Select,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  createTheme,
} from '@mui/material'
import { Dataset } from '../../types/api'
import { HEADER_HEIGHT } from '../../helpers/theme'
import { IState } from '../../store/reducers'
import { MqScreenLoad } from '../../components/core/screen-load/MqScreenLoad'
import { Nullable } from '../../types/util/Nullable'
import { Refresh } from '@mui/icons-material'
import { bindActionCreators } from 'redux'
import { connect } from 'react-redux'
import {
  datasetFacetsQualityAssertions,
  datasetFacetsStatus,
  encodeNode,
} from '../../helpers/nodes'
import { fetchDatasets, resetDatasets } from '../../store/actionCreators'
import { formatUpdatedAt } from '../../helpers'
import { useTheme } from '@emotion/react'
import Assertions from '../../components/datasets/Assertions'
import Box from '@mui/material/Box'
import CircularProgress from '@mui/material/CircularProgress/CircularProgress'
import IconButton from '@mui/material/IconButton'
import MQTooltip from '../../components/core/tooltip/MQTooltip'
import MqEmpty from '../../components/core/empty/MqEmpty'
import MqPaging from '../../components/paging/MqPaging'
import MqStatus from '../../components/core/status/MqStatus'
import MqText from '../../components/core/text/MqText'
import NamespaceSelect from '../../components/namespace-select/NamespaceSelect'
import React from 'react'

interface StateProps {
  datasets: Dataset[]
  isDatasetsLoading: boolean
  isDatasetsInit: boolean
  selectedNamespace: Nullable<string>
  totalCount: number
}

interface DatasetsState {
  page: number
  searchQuery: string
  pageSize: number | 'all'
}

interface DispatchProps {
  fetchDatasets: typeof fetchDatasets
  resetDatasets: typeof resetDatasets
}

type DatasetsProps = StateProps & DispatchProps

const DEFAULT_PAGE_SIZE = 20
const DATASET_HEADER_HEIGHT = 64

const Datasets: React.FC<DatasetsProps> = ({
  datasets,
  totalCount,
  isDatasetsLoading,
  isDatasetsInit,
  selectedNamespace,
  fetchDatasets,
  resetDatasets,
}) => {
  const defaultState = {
    page: 0,
    searchQuery: '',
    pageSize: DEFAULT_PAGE_SIZE as number | 'all',
  }
  const [state, setState] = React.useState<DatasetsState>(defaultState)

  const theme = createTheme(useTheme())

  React.useEffect(() => {
    if (selectedNamespace) {
      // When showing all, use totalCount if available, otherwise use a large number
      const limit = state.pageSize === 'all' ? (totalCount > 0 ? totalCount : 10000) : state.pageSize
      const offset = state.pageSize === 'all' ? 0 : state.page * state.pageSize
      fetchDatasets(selectedNamespace, limit, offset)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedNamespace, state.page, state.pageSize])

  // When totalCount updates and pageSize is 'all', refresh to get all data if needed
  React.useEffect(() => {
    if (
      selectedNamespace &&
      state.pageSize === 'all' &&
      totalCount > 0 &&
      datasets.length > 0 &&
      datasets.length < totalCount
    ) {
      // Only fetch if we don't have all the data yet
      fetchDatasets(selectedNamespace, totalCount, 0)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [totalCount])

  React.useEffect(() => {
    return () => {
      // on unmount
      resetDatasets()
    }
  }, [])

  const handleClickPage = (direction: 'prev' | 'next') => {
    if (state.pageSize === 'all') return // No pagination when showing all
    
    const directionPage = direction === 'next' ? state.page + 1 : state.page - 1
    const limit = state.pageSize
    const offset = directionPage * limit

    fetchDatasets(selectedNamespace || '', limit, offset)
    // reset page scroll
    window.scrollTo(0, 0)
    setState({ ...state, page: directionPage })
  }

  const handlePageSizeChange = (event: any) => {
    const newPageSize = event.target.value === 'all' ? 'all' : Number(event.target.value)
    setState({ ...state, pageSize: newPageSize, page: 0 })
    // useEffect will handle the fetch when pageSize changes
  }

  // Filter datasets by name (case-insensitive fuzzy search)
  const filteredDatasets = React.useMemo(() => {
    if (!state.searchQuery.trim()) {
      return datasets.filter((dataset) => !dataset.deleted)
    }
    const query = state.searchQuery.toLowerCase().trim()
    return datasets.filter(
      (dataset) => !dataset.deleted && dataset.name.toLowerCase().includes(query)
    )
  }, [datasets, state.searchQuery])

  const handleSearchChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setState({ ...state, searchQuery: event.target.value, page: 0 })
  }

  const i18next = require('i18next')
  return (
    <Container maxWidth={'lg'} disableGutters>
      <Box p={2}>
        <Box display={'flex'} justifyContent={'space-between'} alignItems={'center'} mb={2}>
          <Box display={'flex'}>
            <MqText heading>{i18next.t('datasets_route.heading')}</MqText>
            {!isDatasetsLoading && (
              <Chip
                size={'small'}
                variant={'outlined'}
                color={'primary'}
                sx={{ marginLeft: 1 }}
                label={
                  state.searchQuery.trim()
                    ? `${filteredDatasets.length} / ${totalCount}`
                    : `${totalCount} total`
                }
              ></Chip>
            )}
          </Box>
          <Box display={'flex'} alignItems={'center'}>
            {isDatasetsLoading && <CircularProgress size={16} />}
            <NamespaceSelect />
            <MQTooltip title={'Refresh'}>
              <IconButton
                sx={{ ml: 2 }}
                color={'primary'}
                size={'small'}
                onClick={() => {
                  if (selectedNamespace) {
                    const limit = state.pageSize === 'all' ? totalCount || 10000 : state.pageSize
                    const offset = state.pageSize === 'all' ? 0 : state.page * state.pageSize
                    fetchDatasets(selectedNamespace, limit, offset)
                  }
                }}
              >
                <Refresh fontSize={'small'} />
              </IconButton>
            </MQTooltip>
          </Box>
        </Box>
        <Box mb={2}>
          <TextField
            fullWidth
            size='small'
            placeholder='Search by name...'
            value={state.searchQuery}
            onChange={handleSearchChange}
            sx={{
              '& .MuiOutlinedInput-root': {
                backgroundColor: theme.palette.background.paper,
              },
            }}
          />
        </Box>
      </Box>
      <MqScreenLoad
        loading={isDatasetsLoading && !isDatasetsInit}
        customHeight={`calc(100vh - ${HEADER_HEIGHT}px - ${DATASET_HEADER_HEIGHT}px)`}
      >
        <>
          {filteredDatasets.length === 0 ? (
            <Box p={2}>
              <MqEmpty title={i18next.t('datasets_route.empty_title')}>
                <>
                  <MqText subdued>{i18next.t('datasets_route.empty_body')}</MqText>
                  <Button
                    color={'primary'}
                    size={'small'}
                    onClick={() => {
                      if (selectedNamespace) {
                        const limit = state.pageSize === 'all' ? totalCount || 10000 : state.pageSize
                        const offset = state.pageSize === 'all' ? 0 : state.page * state.pageSize
                        fetchDatasets(selectedNamespace, limit, offset)
                      }
                    }}
                  >
                    Refresh
                  </Button>
                </>
              </MqEmpty>
            </Box>
          ) : (
            <>
              <Table size='small'>
                <TableHead>
                  <TableRow>
                    <TableCell key={i18next.t('datasets_route.name_col')} align='left'>
                      <MqText subheading>{i18next.t('datasets_route.name_col')}</MqText>
                    </TableCell>
                    <TableCell key={i18next.t('datasets_route.namespace_col')} align='left'>
                      <MqText subheading>{i18next.t('datasets_route.namespace_col')}</MqText>
                    </TableCell>
                    <TableCell key={i18next.t('datasets_route.source_col')} align='left'>
                      <MqText subheading>{i18next.t('datasets_route.source_col')}</MqText>
                    </TableCell>
                    <TableCell key={i18next.t('datasets_route.updated_col')} align='left'>
                      <MqText subheading>{i18next.t('datasets_route.updated_col')}</MqText>
                    </TableCell>
                    <TableCell key={i18next.t('datasets_route.quality')} align='left'>
                      <MqText subheading>{i18next.t('datasets_route.quality')}</MqText>
                    </TableCell>
                    <TableCell key={i18next.t('datasets.column_lineage_tab')} align='left'>
                      <MqText inline subheading>
                        COLUMN LINEAGE
                      </MqText>
                    </TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filteredDatasets.map((dataset) => {
                      const assertions = datasetFacetsQualityAssertions(dataset.facets)
                      return (
                        <TableRow key={dataset.name}>
                          <TableCell align='left' sx={{ whiteSpace: 'normal', wordBreak: 'break-word' }}>
                            <MqText
                              link
                              linkTo={`/lineage/${encodeNode(
                                'DATASET',
                                dataset.namespace,
                                dataset.name
                              )}`}
                            >
                              {dataset.name}
                            </MqText>
                          </TableCell>
                          <TableCell align='left' sx={{ whiteSpace: 'normal', wordBreak: 'break-word' }}>
                            <MqText>{dataset.namespace}</MqText>
                          </TableCell>
                          <TableCell align='left'>
                            <MqText>{dataset.sourceName}</MqText>
                          </TableCell>
                          <TableCell align='left'>
                            <MqText>{formatUpdatedAt(dataset.updatedAt)}</MqText>
                          </TableCell>
                          <TableCell align='left'>
                            {datasetFacetsStatus(dataset.facets) ? (
                              <>
                                <MQTooltip title={<Assertions assertions={assertions} />}>
                                  <Box>
                                    <MqStatus
                                      label={
                                        assertions.find((a) => !a.success) ? 'UNHEALTHY' : 'HEALTHY'
                                      }
                                      color={datasetFacetsStatus(dataset.facets)}
                                    />
                                  </Box>
                                </MQTooltip>
                              </>
                            ) : (
                              <MqStatus label={'N/A'} color={theme.palette.secondary.main} />
                            )}
                          </TableCell>
                          <TableCell>
                            {dataset.columnLineage ? (
                              <MqText
                                link
                                linkTo={`column-level/${encodeURIComponent(
                                  encodeURIComponent(dataset.id.namespace)
                                )}/${encodeURIComponent(dataset.id.name)}`}
                              >
                                VIEW
                              </MqText>
                            ) : (
                              <MqText subdued>N/A</MqText>
                            )}
                          </TableCell>
                        </TableRow>
                      )
                    })}
                </TableBody>
              </Table>
              {!state.searchQuery.trim() && (
                <Box display={'flex'} justifyContent={'space-between'} alignItems={'center'} p={2}>
                  <Box display={'flex'} alignItems={'center'}>
                    <MqText subdued sx={{ mr: 1 }}>
                      Show:
                    </MqText>
                    <Select
                      value={state.pageSize}
                      onChange={handlePageSizeChange}
                      size='small'
                      sx={{
                        minWidth: 100,
                        backgroundColor: theme.palette.background.paper,
                        '& .MuiOutlinedInput-notchedOutline': {
                          borderColor: theme.palette.secondary.main,
                        },
                      }}
                    >
                      <MenuItem value={20}>20</MenuItem>
                      <MenuItem value={50}>50</MenuItem>
                      <MenuItem value={100}>100</MenuItem>
                      <MenuItem value={200}>200</MenuItem>
                      <MenuItem value='all'>All</MenuItem>
                    </Select>
                  </Box>
                  {state.pageSize !== 'all' && (
                    <MqPaging
                      pageSize={state.pageSize}
                      currentPage={state.page}
                      totalCount={totalCount}
                      incrementPage={() => handleClickPage('next')}
                      decrementPage={() => handleClickPage('prev')}
                    />
                  )}
                </Box>
              )}
            </>
          )}
        </>
      </MqScreenLoad>
    </Container>
  )
}

const mapStateToProps = (state: IState) => ({
  datasets: state.datasets.result,
  totalCount: state.datasets.totalCount,
  isDatasetsLoading: state.datasets.isLoading,
  isDatasetsInit: state.datasets.init,
  selectedNamespace: state.namespaces.selectedNamespace,
})

const mapDispatchToProps = (dispatch: Redux.Dispatch) =>
  bindActionCreators(
    {
      fetchDatasets: fetchDatasets,
      resetDatasets: resetDatasets,
    },
    dispatch
  )

export default connect(mapStateToProps, mapDispatchToProps)(Datasets)

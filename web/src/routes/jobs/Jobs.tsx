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
import { HEADER_HEIGHT } from '../../helpers/theme'
import { IState } from '../../store/reducers'
import { Job } from '../../types/api'
import { MqScreenLoad } from '../../components/core/screen-load/MqScreenLoad'
import { Nullable } from '../../types/util/Nullable'
import { Refresh } from '@mui/icons-material'
import { bindActionCreators } from 'redux'
import { connect } from 'react-redux'
import { encodeNode, runStateColor } from '../../helpers/nodes'
import { fetchJobs, resetJobs } from '../../store/actionCreators'
import { formatUpdatedAt } from '../../helpers'
import { stopWatchDuration } from '../../helpers/time'
import { useTheme } from '@emotion/react'
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
  jobs: Job[]
  isJobsInit: boolean
  isJobsLoading: boolean
  selectedNamespace: Nullable<string>
  totalCount: number
}

interface JobsState {
  page: number
  searchQuery: string
  pageSize: number | 'all'
}

interface DispatchProps {
  fetchJobs: typeof fetchJobs
  resetJobs: typeof resetJobs
}

type JobsProps = StateProps & DispatchProps

const DEFAULT_PAGE_SIZE = 20
const JOB_HEADER_HEIGHT = 64

const Jobs: React.FC<JobsProps> = ({
  jobs,
  totalCount,
  isJobsLoading,
  isJobsInit,
  selectedNamespace,
  fetchJobs,
  resetJobs,
}) => {
  const defaultState = {
    page: 0,
    searchQuery: '',
    pageSize: DEFAULT_PAGE_SIZE as number | 'all',
  }
  const [state, setState] = React.useState<JobsState>(defaultState)
  const theme = createTheme(useTheme())

  React.useEffect(() => {
    if (selectedNamespace) {
      // When showing all, use totalCount if available, otherwise use a large number
      const limit = state.pageSize === 'all' ? (totalCount > 0 ? totalCount : 10000) : state.pageSize
      const offset = state.pageSize === 'all' ? 0 : state.page * state.pageSize
      fetchJobs(selectedNamespace, limit, offset)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedNamespace, state.page, state.pageSize])

  // When totalCount updates and pageSize is 'all', refresh to get all data if needed
  React.useEffect(() => {
    if (
      selectedNamespace &&
      state.pageSize === 'all' &&
      totalCount > 0 &&
      jobs.length > 0 &&
      jobs.length < totalCount
    ) {
      // Only fetch if we don't have all the data yet
      fetchJobs(selectedNamespace, totalCount, 0)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [totalCount])

  React.useEffect(() => {
    return () => {
      // on unmount
      resetJobs()
    }
  }, [])

  const handleClickPage = (direction: 'prev' | 'next') => {
    if (state.pageSize === 'all') return // No pagination when showing all
    
    const directionPage = direction === 'next' ? state.page + 1 : state.page - 1
    const limit = state.pageSize
    const offset = directionPage * limit

    fetchJobs(selectedNamespace || '', limit, offset)
    // reset page scroll
    window.scrollTo(0, 0)
    setState({ ...state, page: directionPage })
  }

  const handlePageSizeChange = (event: any) => {
    const newPageSize = event.target.value === 'all' ? 'all' : Number(event.target.value)
    setState({ ...state, pageSize: newPageSize, page: 0 })
    // useEffect will handle the fetch when pageSize changes
  }

  // Filter jobs by name (case-insensitive fuzzy search)
  const filteredJobs = React.useMemo(() => {
    if (!state.searchQuery.trim()) {
      return jobs
    }
    const query = state.searchQuery.toLowerCase().trim()
    return jobs.filter((job) => job.name.toLowerCase().includes(query))
  }, [jobs, state.searchQuery])

  const handleSearchChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setState({ ...state, searchQuery: event.target.value, page: 0 })
  }

  const i18next = require('i18next')
  return (
    <Container maxWidth={'lg'} disableGutters>
      <Box p={2}>
        <Box display={'flex'} justifyContent={'space-between'} alignItems={'center'} mb={2}>
          <Box display={'flex'}>
            <MqText heading>{i18next.t('jobs_route.heading')}</MqText>
            {!isJobsLoading && (
              <Chip
                size={'small'}
                variant={'outlined'}
                color={'primary'}
                sx={{ marginLeft: 1 }}
                label={
                  state.searchQuery.trim()
                    ? `${filteredJobs.length} / ${totalCount}`
                    : `${totalCount} total`
                }
              ></Chip>
            )}
          </Box>
          <Box display={'flex'} alignItems={'center'}>
            {isJobsLoading && <CircularProgress size={16} />}
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
                    fetchJobs(selectedNamespace, limit, offset)
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
        loading={isJobsLoading && !isJobsInit}
        customHeight={`calc(100vh - ${HEADER_HEIGHT}px - ${JOB_HEADER_HEIGHT}px)`}
      >
        <>
          {filteredJobs.length === 0 ? (
            <Box p={2}>
              <MqEmpty title={i18next.t('jobs_route.empty_title')}>
                <>
                  <MqText subdued>{i18next.t('jobs_route.empty_body')}</MqText>
                  <Button
                    color={'primary'}
                    size={'small'}
                    onClick={() => {
                      if (selectedNamespace) {
                        const limit = state.pageSize === 'all' ? totalCount || 10000 : state.pageSize
                        const offset = state.pageSize === 'all' ? 0 : state.page * state.pageSize
                        fetchJobs(selectedNamespace, limit, offset)
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
                    <TableCell key={i18next.t('jobs_route.name_col')} align='left'>
                      <MqText subheading>{i18next.t('datasets_route.name_col')}</MqText>
                    </TableCell>
                    <TableCell key={i18next.t('jobs_route.namespace_col')} align='left'>
                      <MqText subheading>{i18next.t('datasets_route.namespace_col')}</MqText>
                    </TableCell>
                    <TableCell key={i18next.t('jobs_route.updated_col')} align='left'>
                      <MqText subheading>{i18next.t('datasets_route.updated_col')}</MqText>
                    </TableCell>
                    <TableCell key={i18next.t('jobs_route.latest_run_col')} align='left'>
                      <MqText subheading>{i18next.t('jobs_route.latest_run_col')}</MqText>
                    </TableCell>
                    <TableCell key={i18next.t('jobs_route.latest_run_state_col')} align='left'>
                      <MqText subheading>{i18next.t('jobs_route.latest_run_state_col')}</MqText>
                    </TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filteredJobs.map((job) => {
                    return (
                      <TableRow key={job.name}>
                        <TableCell align='left' sx={{ whiteSpace: 'normal', wordBreak: 'break-word' }}>
                          <MqText
                            link
                            linkTo={`/lineage/${encodeNode('JOB', job.namespace, job.name)}`}
                          >
                            {job.name}
                          </MqText>
                        </TableCell>
                        <TableCell align='left' sx={{ whiteSpace: 'normal', wordBreak: 'break-word' }}>
                          <MqText>{job.namespace}</MqText>
                        </TableCell>
                        <TableCell align='left'>
                          <MqText>{formatUpdatedAt(job.updatedAt)}</MqText>
                        </TableCell>
                        <TableCell align='left'>
                          <MqText>
                            {job.latestRun && job.latestRun.durationMs
                              ? stopWatchDuration(job.latestRun.durationMs)
                              : 'N/A'}
                          </MqText>
                        </TableCell>
                        <TableCell key={i18next.t('jobs_route.latest_run_col')} align='left'>
                          <MqStatus
                            color={job.latestRun && runStateColor(job.latestRun.state || 'NEW')}
                            label={
                              job.latestRun && job.latestRun.state ? job.latestRun.state : 'N/A'
                            }
                          />
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
  jobs: state.jobs.result,
  isJobsInit: state.jobs.init,
  isJobsLoading: state.jobs.isLoading,
  selectedNamespace: state.namespaces.selectedNamespace,
  totalCount: state.jobs.totalCount,
})

const mapDispatchToProps = (dispatch: Redux.Dispatch) =>
  bindActionCreators(
    {
      fetchJobs: fetchJobs,
      resetJobs: resetJobs,
    },
    dispatch
  )

export default connect(mapStateToProps, mapDispatchToProps)(Jobs)

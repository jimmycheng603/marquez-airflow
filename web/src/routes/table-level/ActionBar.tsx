import { ArrowBackIosRounded, Refresh } from '@mui/icons-material'
import { Divider, FormControlLabel, Switch, TextField } from '@mui/material'
import { HEADER_HEIGHT, theme } from '../../helpers/theme'
import { fetchLineage } from '../../store/actionCreators'
import { truncateText } from '../../helpers/text'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import Box from '@mui/material/Box'
import IconButton from '@mui/material/IconButton'
import MQTooltip from '../../components/core/tooltip/MQTooltip'
import MqText from '../../components/core/text/MqText'
import React from 'react'

interface ActionBarProps {
  nodeType: 'DATASET' | 'JOB'
  fetchLineage: typeof fetchLineage
  depth: number
  setDepth: (depth: number) => void
  isCompact: boolean
  setIsCompact: (isCompact: boolean) => void
  isFull: boolean
  setIsFull: (isFull: boolean) => void
  showJobs: boolean
  setShowJobs: (showJobs: boolean) => void
  showDatasets: boolean
  setShowDatasets: (showDatasets: boolean) => void
}

export const ActionBar = ({
  nodeType,
  fetchLineage,
  depth,
  setDepth,
  isCompact,
  setIsCompact,
  isFull,
  setIsFull,
  showJobs,
  setShowJobs,
  showDatasets,
  setShowDatasets,
}: ActionBarProps) => {
  const { namespace, name } = useParams()
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  return (
    <Box
      sx={{
        borderBottomWidth: 2,
        borderTopWidth: 0,
        borderLeftWidth: 0,
        borderRightWidth: 0,
        borderStyle: 'dashed',
      }}
      display={'flex'}
      minHeight={HEADER_HEIGHT - 1}
      justifyContent={'space-between'}
      alignItems={'flex-start'}
      px={2}
      py={1}
      borderColor={theme.palette.secondary.main}
    >
      <Box display={'flex'} alignItems={'center'}>
        <MQTooltip title={`Back to ${nodeType === 'JOB' ? 'jobs' : 'datasets'}`}>
          <IconButton
            size={'small'}
            sx={{ mr: 2 }}
            onClick={() => navigate(nodeType === 'JOB' ? '/' : '/datasets')}
          >
            <ArrowBackIosRounded fontSize={'small'} />
          </IconButton>
        </MQTooltip>
        <MqText heading>{nodeType === 'JOB' ? 'Jobs' : 'Datasets'}</MqText>
        <Divider orientation='vertical' flexItem sx={{ mx: 2 }} />
        <Box>
          <MqText subdued>Mode</MqText>
          <MqText font={'mono'}>Table Level</MqText>
        </Box>
        <Divider orientation='vertical' flexItem sx={{ mx: 2 }} />
        <Box>
          <MqText subdued>Namespace</MqText>
          <MqText font={'mono'}>
            {namespace ? truncateText(namespace, 40) : 'Unknown namespace name'}
          </MqText>
        </Box>
        <Divider orientation='vertical' flexItem sx={{ mx: 2 }} />
        <Box>
          <MqText subdued>Name</MqText>
          <MqText font={'mono'}>{name || (nodeType === 'JOB' ? 'Unknown job name' : 'Unknown dataset name')}</MqText>
        </Box>
      </Box>
      <Box display={'flex'} alignItems={'center'}>
        <MQTooltip title={'Refresh'}>
          <IconButton
            sx={{ mr: 2 }}
            color={'primary'}
            size={'small'}
            onClick={() => {
              if (namespace && name) {
                fetchLineage(nodeType, namespace, name, depth)
              }
            }}
          >
            <Refresh fontSize={'small'} />
          </IconButton>
        </MQTooltip>
        <TextField
          id='column-level-depth'
          type='number'
          inputProps={{ min: 0 }}
          label='Depth'
          variant='outlined'
          size='small'
          sx={{ width: '80px', mr: 2 }}
          value={depth}
          onChange={(e) => {
            setDepth(isNaN(parseInt(e.target.value)) ? 0 : parseInt(e.target.value))
            searchParams.set('depth', e.target.value)
            setSearchParams(searchParams)
          }}
        />
        <Box display={'flex'} flexDirection={'column'} sx={{ gap: 0 }}>
          <Box display={'flex'} sx={{ gap: 2 }}>
            <FormControlLabel
              control={
                <Switch
                  size={'small'}
                  value={isFull}
                  defaultChecked={searchParams.get('isFull') === 'true'}
                  checked={isFull}
                  onChange={(_, checked) => {
                    setIsFull(checked)
                    searchParams.set('isFull', checked.toString())
                    setSearchParams(searchParams)
                  }}
                />
              }
              label={<MqText font={'mono'}>Full Graph</MqText>}
              sx={{ margin: 0 }}
            />
            <FormControlLabel
              control={
                <Switch
                  size={'small'}
                  value={showDatasets}
                  defaultChecked={searchParams.get('showDatasets') === 'true'}
                  checked={showDatasets}
                  onChange={(_, checked) => {
                    setShowDatasets(checked)
                    searchParams.set('showDatasets', checked.toString())
                    setSearchParams(searchParams)
                  }}
                />
              }
              label={<MqText font={'mono'}>Show Datasets</MqText>}
              sx={{ margin: 0 }}
            />
          </Box>
          <Box display={'flex'} sx={{ gap: 2 }}>
            <FormControlLabel
              control={
                <Switch
                  size={'small'}
                  value={isCompact}
                  defaultChecked={searchParams.get('isCompact') === 'true'}
                  checked={isCompact}
                  onChange={(_, checked) => {
                    setIsCompact(checked)
                    searchParams.set('isCompact', checked.toString())
                    setSearchParams(searchParams)
                  }}
                />
              }
              label={<MqText font={'mono'}>Compact Nodes</MqText>}
              sx={{ margin: 0 }}
            />
            <FormControlLabel
              control={
                <Switch
                  size={'small'}
                  value={showJobs}
                  defaultChecked={searchParams.get('showJobs') === 'true'}
                  checked={showJobs}
                  onChange={(_, checked) => {
                    setShowJobs(checked)
                    searchParams.set('showJobs', checked.toString())
                    setSearchParams(searchParams)
                  }}
                />
              }
              label={<MqText font={'mono'}>Show Jobs</MqText>}
              sx={{ margin: 0 }}
            />
          </Box>
        </Box>
      </Box>
    </Box>
  )
}

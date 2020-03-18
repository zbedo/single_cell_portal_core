import React, { useState, useEffect } from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faDownload } from '@fortawesome/free-solid-svg-icons'
import Modal from 'react-bootstrap/lib/Modal'
import Tooltip from 'react-bootstrap/lib/Tooltip'
import OverlayTrigger from 'react-bootstrap/lib/OverlayTrigger'
import Clipboard from 'react-clipboard.js'

import { useContextStudySearch } from './search/StudySearchProvider'
import { useContextUser } from './UserProvider'
import { fetchAuthCode } from 'lib/scp-api'
import {
  getNumFacetsAndFilters, getNumberOfTerms
} from '../lib/scp-api-metrics'

/**
 * Fetch auth code, build download command, return configuration object
 *
 * @returns {Object} Object for auth code, time interval, and download command
 */
async function generateDownloadConfig(matchingAccessions) {
  const accessions = matchingAccessions.join(',')
  const searchQuery = `&file_types=metadata,expression&accessions=${accessions}`

  const { authCode, timeInterval } = await fetchAuthCode()

  const queryString = `?auth_code=${authCode}${searchQuery}`

  // Gets a curl configuration ("cfg.txt") containing signed
  // URLs and output names for all files in the download object.
  const baseUrl = `${window.origin}/single_cell/api/v1/`
  const url = `${baseUrl}/search/bulk_download${queryString}`

  // "-k" === "--insecure"
  const curlSecureFlag = (window.location.host === 'localhost') ? 'k' : ''

  // This is what the user will run in their terminal to download the data.
  // To consider: check the node environment (either at compile or runtime)
  // instead of the hostname
  const downloadCommand = (
    `curl "${url}" -${curlSecureFlag}o cfg.txt; ` +
    `curl -K cfg.txt; rm cfg.txt`
  )

  return {
    authCode,
    timeInterval,
    downloadCommand
  }
}

/**
 * Get preview of download sizes
 *
 * @param {*} downloadSize
 */

/**
 * Container for curl command to download files
 */
function DownloadCommandContainer(props) {
  const [downloadConfig, setDownloadConfig] = useState({})

  /**
   * Fetch new download command, update state accordingly
   */
  async function updateDownloadConfig(matchingStudies) {
    const fetchData = async () => {
      const dlConfig = await generateDownloadConfig(matchingStudies)
      setDownloadConfig(dlConfig)
    }
    fetchData()
  }

  useEffect(() => {
    updateDownloadConfig(props.matchingAccessions)
  }, [])

  /**
   * TODO (SCP-2167): Add polish to show "Copied!" upon clicking "Copy"
   * button, then hide.  As in Bulk Download modal in study View / Explore.
   */
  function onClipboardCopySuccess(event) {
    console.log('TODO')
  }

  return (
    <div>
      <div className='input-group'>
        <input
          id={`command-${downloadConfig.authCode}`}
          className='form-control curl-download-command'
          value={downloadConfig.downloadCommand || ''}
          readOnly
        />
        <span className='input-group-btn'>
          <Clipboard
            data-clipboard-target={`#command-${downloadConfig.authCode}`}
            onSuccess={onClipboardCopySuccess}
            className='btn btn-default btn-copy'
            data-toggle='tooltip'
            button-title='Copy to clipboard'
          >
            <i className='far fa-copy'></i>
          </Clipboard>
          <button
            id={`refresh-button-${downloadConfig.authCode}`}
            className='download-refresh-button btn btn-default btn-refresh glyphicon glyphicon-refresh' // eslint-disable-line max-len
            data-toggle='tooltip'
            onClick={() => {updateDownloadConfig(props.matchingAccessions)}}
            title='Refresh download command'>
          </button>
        </span>
      </div>
      <div id="download-command-caption">
        Valid for one use within {' '}
        <span className='countdown' id={`countdown-${downloadConfig.authCode}`}>
          {Math.floor(downloadConfig.timeInterval / 60)}
        </span>{' '}
        minutes.  If your command has expired, click refresh button at right
        in this box.
      </div>
    </div>
  )
}

/**
 * Format number in bytes, with human-friendly units
 *
 * Derived from https://gist.github.com/lanqy/5193417#gistcomment-2663632
 */
function bytesToSize(bytes) {
  const sizes = ['bytes', 'KB', 'MB', 'GB', 'TB']
  if (bytes === 0) return 'n/a'

  // eweitz: Most implementations use log(1024), but such units are
  // binary and have values like MiB (mebibyte)
  const i = parseInt(Math.floor(Math.log(bytes) / Math.log(1000)), 10)

  if (i === 0) return `${bytes} ${sizes[i]}`
  return `${(bytes / (1000 ** i)).toFixed(1)} ${sizes[i]}`
}

/**
 * Get introductory text for download command, including download size
 *
 * @param {Object} downloadSize Size in bytes, by file type
 */
function getLeadText(downloadSize) {
  // Sum sizes by file type to total size for download
  const totalSize =
    Object.values(downloadSize).reduce((prevSize, sizeObj) => {
      return sizeObj.total_bytes + prevSize
    }, 0)
  const prettyBytes = bytesToSize(totalSize)

  // Get file type summary
  // E.g. "metadata and expression" or
  // (possibly later) "metadata, cluster, and expression"
  const ft = Object.keys(downloadSize)
  let fileTypes = ft.join(' and ')
  if (ft.length > 2) {
    const allButLast = ft.slice(0, -1)
    const last = ft.slice(-1)[0]
    fileTypes = `${allButLast.join(', ')}, and ${last}`
  }

  return (`
    To download ${prettyBytes} in ${fileTypes} files
    matching your search, copy this command and paste it into your terminal:
  `)
}

/** Determine if search has any parameters, i.e. terms or filters */
function hasSearchParams(params) {
  const numTerms = getNumberOfTerms(params.terms)
  const [numFacets, numFilters] = getNumFacetsAndFilters(params.facets)
  return (numTerms + numFacets + numFilters) > 0
}

/**
 * Component for "Download" button and Bulk Download modal.
 *
 * UI spec: https://projects.invisionapp.com/d/main#/console/19272801/402387755/preview
 */
export default function DownloadButton(props) {
  const searchContext = useContextStudySearch()
  const userContext = useContextUser()

  const [show, setShow] = useState(false)

  const matchingAccessions = searchContext.results.matchingAccessions || []
  const downloadSize = searchContext.downloadSize

  /**
   * Reports whether Download button should be active,
   * i.e. user is signed in, has search results,
   * and search has parameters (i.e. user would not download all studies)
   */
  const active = (
    userContext.accessToken !== '' &&
    matchingAccessions.length > 0 &&
    hasSearchParams(searchContext.params)
  )

  let hint = 'To download, first do a search'
  if (active) hint = 'Download files for your search results'

  const handleClose = () => setShow(false)

  return (
    <>
      <OverlayTrigger
        placement="top"
        overlay={<Tooltip id="download-tooltip">{hint}</Tooltip>}
      >
        <button
          id='download-button'
          className={`btn btn-primary ${active ? 'active' : 'disabled'}`}
        >
          <span onClick={() => {if (active) setShow(!show)}}>
            <FontAwesomeIcon className="icon-left" icon={faDownload}/>
          Download
          </span>
        </button>
      </OverlayTrigger>
      <Modal
        id='bulk-download-modal'
        show={show}
        onHide={handleClose}
        animation={false}
        bsSize='large'
      >
        <Modal.Header closeButton>
          <h2 className='text-center'>Bulk Download</h2>
        </Modal.Header>

        <Modal.Body>
          <p className='lead'>
            {getLeadText(downloadSize)}
          </p>
          <div className='lead command-container' id='command-container-all'>
            <DownloadCommandContainer
              matchingAccessions={matchingAccessions}
            />
          </div>
        </Modal.Body>

      </Modal>
    </>
  )
}

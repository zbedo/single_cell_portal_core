import React, { useState, useEffect } from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faDownload } from '@fortawesome/free-solid-svg-icons'
import Modal from 'react-bootstrap/lib/Modal'
// We'll need this when refining onClipboardCopySuccess
// import Tooltip from 'react-bootstrap/lib/Tooltip';
import Clipboard from 'react-clipboard.js'

import { useContextStudySearch } from './search/StudySearchProvider'
import { useContextUser } from './UserProvider'
import { fetchAuthCode } from 'lib/scp-api'

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
    downloadCommand,
  }
}

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
 * Component for "Download" button and Bulk Download modal.
 *
 * UI spec: https://projects.invisionapp.com/d/main#/console/19272801/402387755/preview
 */
export default function DownloadButton(props) {
  const searchContext = useContextStudySearch()
  const userContext = useContextUser()

  const [show, setShow] = useState(false)

  const matchingAccessions = searchContext.results.matchingAccessions || []

  /**
   * Reports whether Download button be active,
   * i.e. user is signed in and has search results
   */
  const active = userContext.accessToken !== '' && matchingAccessions.length > 0

  function showModalAndFetchDownloadCommand() {
    if (active) setShow(!show)
  }

  const handleClose = () => setShow(false)

  return (
    <>
      <span id='download-button' className={active ? 'active' : ''}>
        <span onClick={showModalAndFetchDownloadCommand}>
          <FontAwesomeIcon className="icon-left" icon={faDownload}/>
          Download
        </span>
      </span>
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
          To download files matching your search,{' '}
          copy this command and paste it into your terminal:
          </p>
          <div className='lead command-container' id='command-container-all'>
            <DownloadCommandContainer matchingAccessions={matchingAccessions} />
          </div>
        </Modal.Body>

      </Modal>
    </>
  )
}

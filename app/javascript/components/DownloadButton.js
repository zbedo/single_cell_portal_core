import React, { useState, useEffect } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faDownload } from '@fortawesome/free-solid-svg-icons';
import Modal from 'react-bootstrap/lib/Modal';
import { fetchAuthCode } from './../lib/scp-api';

async function fetchDownloadConfig() {
  const searchQuery = '&file_types=metadata,expression&accessions=SCP1,SCP2';

  const {authCode, timeInterval} = await fetchAuthCode();

  // Gets a curl configuration ("cfg.txt") containing signed
  // URLs and output names for all files in the download object.
  const url = (
    window.origin +
    '/api/v1/bulk_download?auth_code=' +
    authCode +
    searchQuery
  );
  const curlSecureFlag = (window.location.host === 'localhost') ? 'k' : ''; // "-k" === "--insecure"
  
  // This is what the user will run in their terminal to download the data.
  // TODO: Consider checking the node environment (either at compile or runtime) instead of the hostname
  const downloadCommand = (
    'curl "' + url + '" -' + curlSecureFlag + 'o cfg.txt; ' +
    'curl -K cfg.txt; rm cfg.txt'
  );

  return {
    authCode: authCode,
    timeInterval: timeInterval,
    downloadCommand: downloadCommand
  };
}

function DownloadCommandContainer() {

  const [downloadConfig, setDownloadConfig] = useState({});

  useEffect(() => {
    const fetchData = async () => {
      const dlConfig = await fetchDownloadConfig();
      setDownloadConfig(dlConfig);
    };
    fetchData();
  }, []);

  return (
    <div>
      <div class="input-group">
        <input
          id={'command-' + downloadConfig.authCode}
          class="form-control curl-download-command"
          value={downloadConfig.downloadCommand}
          readOnly
        />
        <span class="input-group-btn"> +
          <button 
            id={'copy-button-' + downloadConfig.authCode}
            class="btn btn-default btn-copy" 
            data-clipboard-target={'#command-' + downloadConfig.authCode}
            data-toggle="tooltip"
            title="Copy to clipboard">
            <i class="far fa-copy"></i>
          </button>
          <button 
            id={'refresh-button-' + downloadConfig.authCode}
            class="btn btn-default btn-refresh glyphicon glyphicon-refresh"
            data-toggle="tooltip"
            title="Refresh download command">
          </button>
        </span>
        </div>
      <div style={{fontSize: '12px'}}>
        Valid for one use within {' '}
        <span class="countdown" id={'countdown-' + downloadConfig.authCode}>
          {Math.floor(downloadConfig.timeInterval / 60)} {/* seconds -> minutes */}
        </span>{' '}
        minutes.  If your command has expired, click refresh button at right in this box.
      </div>
    </div>
  );
}


/**
 * Component for "Download" button and Bulk Download modal.
 *
 * UI spec: https://projects.invisionapp.com/d/main#/console/19272801/402387755/preview
 */
export default function DownloadButton(props) {

  const [show, setShow] = useState(false);
  const [showDownloadCommand, setShowDownloadCommand] = useState(false);

  function showModalAndFetchDownloadCommand() {
    setShow(!show);
  }

  const handleClose = () => setShow(false);
  const handleShow = () => setShow(true);

  window.SCP.initBulkDownloadClipboard();

  return (
      <>
      <span id='download-button' className={`${show ? 'active' : ''}`}>
        <span onClick={showModalAndFetchDownloadCommand}>
          <FontAwesomeIcon className="icon-left" icon={faDownload}/>
          Download
        </span>
      </span>
      <Modal
        id='bulk-download-modal'
        show={show}
        onHide={handleClose}
        animation='false'
        bsSize='large'
      >
        <Modal.Header closeButton>
          <Modal.Title><h2 class='text-center'>Bulk Download</h2></Modal.Title>
        </Modal.Header>
  
        <Modal.Body>
          <p className='lead'>
          To download files matching your search, copy this command and paste it into your terminal:
          </p>
          <p className='lead command-container' id='command-container-all'>
            <DownloadCommandContainer />
          </p>
        </Modal.Body>

      </Modal>
      </>
    );
}

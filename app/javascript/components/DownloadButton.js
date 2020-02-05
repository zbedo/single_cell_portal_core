import React, { useState } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faDownload } from '@fortawesome/free-solid-svg-icons';
import Modal from 'react-bootstrap/lib/Modal';
import Button from 'react-bootstrap/lib/Button';

// TODO: Remove this once API endpoint is integrated
import {bulkDownloadResponseMock} from './FacetsMockData';

function fetchDownloadConfig() {
  // TODO: Move this documentation to a more summary location, but still within the code.
  //
  // Example search query:
  //
  // terms=copy%20number&facets=species:NCBITaxon_9606+disease:MONDO_0018177,MONDO_0005089
  //
  // Human-readable interpretation:
  //
  // Search for SCP studies that have:
  //    terms=copy%20number                  A title or description containing the terms "copy" OR "number"
  //    &facets=                              AND cells that have been annotated using the SCP metadata convention to be 
  //      species:NCBITaxon_9606                from human
  //      +                                     AND
  //      disease:MONDO_0018177,MONDO_0005089   having glioblastoma OR sarcoma
  //

  const searchQuery = '?terms=copy%20number&facets=species:NCBItaxon9606+disease:MONDO_0018177,MONDO_0005089';
  const totat = bulkDownloadResponseMock.totat; // TOTAT: Time-based One-Time Access Token.  Authorization for anonymous users.

  const timeInterval = bulkDownloadResponseMock.time_interval;

  // Gets a curl configuration ("cfg.txt") containing signed
  // URLs and output names for all files in the download object.
  const url = (
    window.origin +
    '/api/v1/bulk_download' +
    '/' + searchQuery +
    '/' + totat
  );
  const flag = (window.location.host === 'localhost') ? 'k' : ''; // "-k" === "--insecure"
  
  // This is what the user will run in their terminal to download the data.
  const downloadCommand = (
    'curl "' + url + '" -' + flag + 'o cfg.txt; ' +
    'curl -K cfg.txt'
  );

  return [totat, timeInterval, downloadCommand];
}

function DownloadCommandContainer() {
  
  const [totat, timeInterval, downloadCommand] = fetchDownloadConfig();

  const expiresMinutes = timeInterval / 60;

  const commandID = 'command-' + totat;

  return (
    <div>
      <div class="input-group">
        <input
          id={commandID}
          class="form-control curl-download-command"
          value={downloadCommand}
          readonly
        />
        <span class="input-group-btn"> +
          <button 
            id={'copy-button-' + totat}
            class="btn btn-default btn-copy" 
            data-clipboard-target={'#' + commandID}
            data-toggle="tooltip"
            title="Copy to clipboard">
            <i class="far fa-copy"></i>
          </button>
          <button 
            id={'refresh-button-' + totat}
            class="btn btn-default btn-refresh glyphicon glyphicon-refresh"
            data-toggle="tooltip"
            // style="top: -0.5px;"
            title="Refresh download command">
          </button>
        </span>
        </div>
      <div style={{fontSize: '12px'}}>
        Valid for one use within {' '}
        <span class="countdown" id={'countdown-' + totat}>
          {expiresMinutes}
        </span>{' '}
        minutes.  Paste into Mac/Linux/Unix terminal and execute to download.
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

  return (
      <>
      <span
        id='download-button'
        className={`${show ? 'active' : ''}`}>
        <span
          onClick={showModalAndFetchDownloadCommand}>
          <FontAwesomeIcon className="icon-left" icon={faDownload}/>
          Download
        </span>
      </span>
      <Modal id='bulk-download-modal' show={show} onHide={handleClose} animation='false'>
        <Modal.Header closeButton>
          <Modal.Title>Bulk Download</Modal.Title>
        </Modal.Header>
  
        <Modal.Body>
          <p className='lead command-container' id='command-container-all'>
            {/* <Button
              bsStyle='primary'
              id='get-download-command_all'
              onClick={createDownloadCommand}
            >
              <FontAwesomeIcon className="icon-left" icon={faDownload}/>
              Get download command for study files matching your search
            </Button> */}
            <DownloadCommandContainer />
          </p>
        </Modal.Body>

      </Modal>
      </>
    );
}
